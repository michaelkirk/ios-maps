import HeadwayFFI
import MapLibre
import SwiftUI

// Progress callback implementation for download
final class ExtractProgressImpl: ExtractProgress {
  private let onProgress: (Double) -> Void

  init(onProgress: @escaping (Double) -> Void) {
    self.onProgress = onProgress
  }

  func onProgress(progress: Double) {
    onProgress(progress)
  }
}

struct OfflineMapsView: View {
  @EnvironmentObject var preferences: Preferences
  @State private var showingAddSheet = false
  @Environment(\.dismiss) var dismiss

  var regionManager: OfflineRegionManager {
    OfflineRegionManager(preferences: preferences)
  }

  var body: some View {
    List {
      if preferences.offlineRegions.isEmpty {
        VStack(alignment: .center, spacing: 12) {
          Image(systemName: "map")
            .font(.system(size: 48))
            .foregroundColor(.secondary)
          Text("No Offline Maps")
            .font(.headline)
          Text("Download map areas for offline use")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
      } else {
        ForEach(preferences.offlineRegions) { region in
          OfflineRegionRow(region: region)
        }
        .onDelete(perform: deleteRegions)
      }
    }
    .navigationTitle("Offline Maps")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: { showingAddSheet = true }) {
          Image(systemName: "plus")
        }
      }
    }
    .sheet(isPresented: $showingAddSheet) {
      AddOfflineRegionView()
    }
  }

  private func deleteRegions(at offsets: IndexSet) {
    for index in offsets {
      let region = preferences.offlineRegions[index]
      Task {
        do {
          try await regionManager.deleteOfflineRegion(region)
          await preferences.removeOfflineRegion(region)
        } catch {
          print("Failed to delete region: \(error)")
        }
      }
    }
    preferences.offlineRegions.remove(atOffsets: offsets)
  }
}

struct OfflineRegionRow: View {
  let region: OfflineRegion
  @State private var showingEditSheet = false

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(region.name)
          .font(.headline)

        Text("Bounds: \(formatBounds(region.bounds))")
          .font(.caption)
          .foregroundColor(.secondary)

        HStack {
          Text(formatDate(region.createdAt))
            .font(.caption)
            .foregroundColor(.secondary)

          if let size = region.sizeInBytes {
            Text("•")
              .foregroundColor(.secondary)
            Text(formatBytes(size))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
      .padding(.vertical, 4)

      Spacer()

      Button(action: { showingEditSheet = true }) {
        Image(systemName: "pencil.circle.fill")
          .font(.system(size: 32))
      }
    }
    .sheet(isPresented: $showingEditSheet) {
      AddOfflineRegionView(region: region)
    }
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  private func formatBytes(_ bytes: UInt64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
  }

  private func formatBounds(_ bounds: BBox) -> String {
    let ne = formatCoordinate(lat: bounds.top, lon: bounds.right)
    let sw = formatCoordinate(lat: bounds.bottom, lon: bounds.left)
    return "\(ne),\(sw)"
  }

  private func formatCoordinate(lat: Double, lon: Double) -> String {
    let latDir = lat >= 0 ? "N" : "S"
    let lonDir = lon >= 0 ? "E" : "W"
    let latAbs = abs(lat)
    let lonAbs = abs(lon)
    return String(format: "%.1f°%@ %.1f°%@", latAbs, latDir, lonAbs, lonDir)
  }
}

enum ExtractionState {
  case preparationUnstarted
  case preparationInProgress(progress: Double)
  case preparationFailed(error: Swift.Error)
  case readyToExtract(plan: ExtractionPlan)
  case extractionInProgress(plan: ExtractionPlan, progress: Double)
  case extractionComplete(plan: ExtractionPlan)
  case extractionFailed(plan: ExtractionPlan, error: Swift.Error)
}

extension ExtractionState {
  var hasExtractionStarted: Bool {
    switch self {
    case .extractionInProgress, .extractionComplete:
      true
    default:
      false
    }
  }
}

struct AddOfflineRegionView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var preferences: Preferences

  let region: OfflineRegion?
  @State private var regionName: String
  private let initialMapBounds: MLNCoordinateBounds
  private var regionManager: OfflineRegionManager {
    OfflineRegionManager(preferences: preferences)
  }
  @State private var currentMapBounds: MLNCoordinateBounds?
  @State private var pendingCalculationBounds: MLNCoordinateBounds?
  @State private var extractionState: ExtractionState = .preparationUnstarted
  @State private var hasLoaded = false
  @State private var wasMapAdjusted = false

  var mapBounds: MLNCoordinateBounds {
    currentMapBounds ?? initialMapBounds
  }

  var styleURL: URL {
    // Always use the online style URL so we can see what we're about to download.
    AppConfig().onlineTileserverStyleUrl
  }

  var isEditMode: Bool {
    region != nil
  }

  init(region: OfflineRegion? = nil) {
    self.region = region
    if let region {
      self._regionName = State(initialValue: region.name)
      self.initialMapBounds = region.bounds.mlnCoordinateBounds()
    } else {
      self._regionName = State(initialValue: "Offline Region")
      self.initialMapBounds = Env.current.getMapView()!.visibleCoordinateBounds
    }
  }

  var body: some View {
    NavigationStack {
      ZStack(alignment: .top) {
        DownloadMapPreview(
          initialBounds: initialMapBounds, styleURL: styleURL, currentBounds: $currentMapBounds
        ).edgesIgnoringSafeArea(.all)

        VStack(spacing: 16) {
          if !extractionState.hasExtractionStarted {
            VStack(alignment: .leading, spacing: 8) {
              Text(isEditMode ? "Edit Offline Map" : "Download Offline Map")
                .font(.headline)

              TextField("Map name", text: $regionName)
                .textFieldStyle(.roundedBorder)

              Text("Move the map to select the area to download")
                .font(.subheadline)
                .foregroundColor(.secondary)

              VStack(alignment: .leading, spacing: 4) {
                Text("Current Bounds:")
                  .font(.caption)
                Text(
                  "NE: \(String(format: "%.4f", mapBounds.ne.latitude)), \(String(format: "%.4f", mapBounds.ne.longitude))"
                )
                .font(.caption2)
                Text(
                  "SW: \(String(format: "%.4f", mapBounds.sw.latitude)), \(String(format: "%.4f", mapBounds.sw.longitude))"
                )
                .font(.caption2)
              }
              .foregroundColor(.secondary)

              switch extractionState {
              case .preparationUnstarted:
                Text("Preparing...")
                ProgressView()
                  .scaleEffect(0.8)
              case .preparationInProgress(let progress):
                VStack(spacing: 4) {
                  HStack {
                    ProgressView(value: progress)
                      .frame(maxWidth: .infinity)
                    Text("\(Int(progress * 100))%")
                      .font(.caption2)
                      .foregroundColor(.secondary)
                  }
                }
              case .preparationFailed(let error):
                Text("Error estimating map size: \(error.localizedDescription)")
                  .font(.caption)
                  .foregroundColor(.red)
              case .readyToExtract(let extractPlan):
                Text("Estimated size: \(formatBytes(extractPlan.tileDataLength()))")
                  .font(.caption)
                  .foregroundColor(.secondary)
              case .extractionFailed(_, let error):
                Text("Error downloading map: \(error.localizedDescription)")
                  .font(.caption)
                  .foregroundColor(.red)
              case .extractionInProgress, .extractionComplete:
                EmptyView()
              }
            }
            HStack {
              Button("Cancel", role: .cancel) {
                dismiss()
              }.foregroundStyle(.secondary)
              Spacer()
              Button(action: startDownload) {
                if case .preparationInProgress = extractionState {
                  HStack {
                    ProgressView()
                      .progressViewStyle(.circular)
                      .scaleEffect(0.8)
                    Text("Calculating size...")
                  }
                } else if case .extractionFailed = extractionState {
                  Text("Retry")
                } else {
                  Text(isEditMode ? "Save" : "Download")
                }
              }.disabled(
                {
                  switch extractionState {
                  case .readyToExtract, .extractionFailed:
                    return regionName.isEmpty
                  default:
                    return true
                  }
                }())
            }
          } else {
            // Download in progress
            VStack(spacing: 12) {
              Text("Downloading \(regionName)")
                .font(.headline)

              if case .extractionInProgress(_, let progress) = extractionState {
                VStack(spacing: 8) {
                  ProgressView(value: progress)
                    .progressViewStyle(.linear)
                  Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              } else {
                ProgressView()
                  .progressViewStyle(.circular)
              }

              Text("This may take a few minutes")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }.padding()
          .background(Color(UIColor.systemBackground))
          .cornerRadius(12)
          .padding()
      }
      .onChange(of: currentMapBounds) { _ in
        guard hasLoaded else {
          return
        }
        guard let currentMapBounds else {
          assertionFailure("currentMapBounds was unexpectedly changed to nil")
          return
        }
        self.wasMapAdjusted = true
        Task { @MainActor in
          // If a calculation is in progress, queue this request (replacing any existing pending request)
          if case .preparationInProgress = extractionState {
            pendingCalculationBounds = currentMapBounds
          } else {
            await prepareExtract(bounds: currentMapBounds)
          }
        }
      }.task {
        await prepareExtract(bounds: initialMapBounds)
        hasLoaded = true
      }
    }
  }

  @MainActor
  private func prepareExtract(bounds: MLNCoordinateBounds) async {
    self.extractionState = .preparationInProgress(progress: 0)

    // Create progress callback
    let progressCallback = ExtractProgressImpl { progress in
      Task { @MainActor in
        self.extractionState = .preparationInProgress(progress: progress)
      }
    }

    await Task {
      let bufferedBounds = buffered(bounds: bounds)

      let hwBounds = HeadwayFFI.Bounds.nesw(
        maxLat: bufferedBounds.ne.latitude,
        maxLon: bufferedBounds.ne.longitude,
        minLat: bufferedBounds.sw.latitude,
        minLon: bufferedBounds.sw.longitude
      )
      do {
        let plan = try await Env.current.headwayServer.preparePmtilesExtract(
          bounds: hwBounds,
          progressCallback: progressCallback
        )
        await Task { @MainActor in
          self.extractionState = .readyToExtract(plan: plan)
          await self.checkForPendingPreparation()
        }.value
      } catch {
        await Task { @MainActor in
          self.extractionState = .preparationFailed(error: error)
          await self.checkForPendingPreparation()
        }.value
      }
    }.value
  }

  @MainActor
  private func checkForPendingPreparation() async {
    guard let pendingBounds = pendingCalculationBounds.take() else {
      return
    }
    await prepareExtract(bounds: pendingBounds)
  }

  @MainActor
  private func startDownload() {
    guard !regionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }

    let extractionPlan: ExtractionPlan
    switch extractionState {
    case .readyToExtract(let plan):
      extractionPlan = plan
    case .extractionFailed(let plan, _):
      extractionPlan = plan
    default:
      return
    }

    Task {
      do {
        await MainActor.run {
          self.extractionState = .extractionInProgress(plan: extractionPlan, progress: 0.0)
        }

        let downloadCallback = ExtractProgressImpl { progress in
          Task { @MainActor in
            self.extractionState = .extractionInProgress(plan: extractionPlan, progress: progress)
          }
        }

        var newRegion: OfflineRegion
        switch (region, wasMapAdjusted) {
        case (.some(let oldRegion), false):
          print("renaming existing extract")
          newRegion = oldRegion
          newRegion.name = regionName
          await preferences.removeOfflineRegion(oldRegion)
        case (.some(let oldRegion), true):
          print("updating existing extract")
          newRegion = try await regionManager.createOfflineRegion(
            name: regionName,
            bounds: BBox(mlnCoordinateBounds: buffered(bounds: mapBounds)),
            styleURL: styleURL,
            extractionPlan: extractionPlan,
            progressCallback: downloadCallback
          )
          try await regionManager.deleteOfflineRegion(oldRegion)
          await preferences.removeOfflineRegion(oldRegion)
        case (.none, _):
          print("creating new extract")
          newRegion = try await regionManager.createOfflineRegion(
            name: regionName,
            bounds: BBox(mlnCoordinateBounds: buffered(bounds: mapBounds)),
            styleURL: styleURL,
            extractionPlan: extractionPlan,
            progressCallback: downloadCallback
          )
        }
        await preferences.addOfflineRegion(newRegion)

        Task { @MainActor in
          // Trigger map refresh to show new tiles and update download prompt
          Env.current.refreshMap(mapBounds)
          dismiss()
        }
      } catch {
        await MainActor.run {
          self.extractionState = .extractionFailed(plan: extractionPlan, error: error)
        }
      }
    }
  }
}

struct DownloadMapPreview: UIViewRepresentable {
  let initialBounds: MLNCoordinateBounds
  let styleURL: URL
  @Binding var currentBounds: MLNCoordinateBounds?

  func makeUIView(context: Context) -> MLNMapView {
    let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
    mapView.delegate = context.coordinator
    mapView.isUserInteractionEnabled = true
    mapView.logoView.isHidden = true
    mapView.attributionButton.isHidden = true
    currentBounds = initialBounds
    DispatchQueue.main.async {
      mapView.setVisibleCoordinateBounds(initialBounds, animated: false)
    }
    return mapView
  }

  func updateUIView(_ uiView: MLNMapView, context: Context) {
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(currentBounds: $currentBounds)
  }

  class Coordinator: NSObject, MLNMapViewDelegate {
    @Binding var currentBounds: MLNCoordinateBounds?

    init(currentBounds: Binding<MLNCoordinateBounds?>) {
      _currentBounds = currentBounds
    }

    func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
      currentBounds = mapView.visibleCoordinateBounds
    }
  }
}

func buffered(bounds: MLNCoordinateBounds) -> MLNCoordinateBounds {
  return bounds.extend(bufferMeters: 10_000)
}

private func formatBytes(_ bytes: UInt64) -> String {
  let formatter = ByteCountFormatter()
  formatter.countStyle = .file
  return formatter.string(fromByteCount: Int64(bytes))
}

#Preview {
  NavigationView {
    OfflineMapsView()
      .environmentObject(Preferences.forTesting())
  }
}
