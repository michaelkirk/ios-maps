//
//  MapView.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import Foundation
import MapLibre
import MapboxDirections
import SwiftUI

private let logger = FileLogger()

enum UserLocationState {
  case initial
  case showing
  case following
  case denied
}

extension UserLocationState: CustomStringConvertible {
  var description: String {
    switch self {
    case .initial:
      ".initial"
    case .showing:
      ".showing"
    case .following:
      ".following"
    case .denied:
      ".denied"
    }
  }
}

enum PendingRecenter {
  case pending
  case resolved(CLLocation)
}

let DefaultZoomLevel: CGFloat = 13

enum MapFocus: Equatable {
  case place(Place)
  case trip(Trip)
  case pendingSearchResults(SearchQueue.Query)
  case searchResults([Place])
  case userLocation
}

extension MapFocus: CustomStringConvertible {
  var description: String {
    switch self {
    case .place(let place):
      "MapFocus.place(\(place.name))"
    case .trip(let trip):
      "MapFocus.trip(\(trip.from.name) -> \(trip.to.name))"
    case .pendingSearchResults(let query):
      "MapFocus.pendingSearchResults(\(query))"
    case .searchResults(let places):
      "MapFocus.searchResults([\(places.count) Places])"
    case .userLocation:
      "MapFocus.userLocation"
    }
  }
}

enum MarkerLocation: Hashable, Equatable {
  case place(Place)
  case tripPlace(TripPlace)

  static func == (lhs: MarkerLocation, rhs: MarkerLocation) -> Bool {
    switch (lhs, rhs) {
    case (.place(let lhs), .place(let rhs)): lhs == rhs
    case (.tripPlace(let lhs), .tripPlace(let rhs)): lhs == rhs
    default: false
    }
  }

  var location: LngLat {
    switch self {
    case .place(let place): place.location
    case .tripPlace(let tripPlace): tripPlace.location
    }
  }

  var lng: Float64 {
    self.location.lng
  }

  var lat: Float64 {
    self.location.lat
  }

  var name: String? {
    switch self {
    case .place(let place): place.name
    case .tripPlace(let tripPlace): tripPlace.name
    }
  }
}

protocol IntoMarkerLocation {
  var intoMarkerLocation: MarkerLocation { get }
}

extension Place: IntoMarkerLocation {
  var intoMarkerLocation: MarkerLocation {
    .place(self)
  }
}
extension TripPlace: IntoMarkerLocation {
  var intoMarkerLocation: MarkerLocation {
    .tripPlace(self)
  }
}

struct MapView {
  @Binding var searchResults: [Place]?
  @Binding var selectedPlace: Place?
  @Binding var pendingMapFocus: MapFocus?
  @ObservedObject var tripPlan: TripPlan
  @EnvironmentObject var userLocationManager: UserLocationManager
}

func add3DBuildingsLayer(style: MLNStyle) {
  assert(style.layers.first { $0.identifier == "subtle_3d_buildings" } == nil)

  guard let source = style.openMapTilesSource else {
    assertionFailure("openmaptiles source was unexpectedly missing")
    return
  }

  let buildingsLayer = MLNFillExtrusionStyleLayer(identifier: "subtle_3d_buildings", source: source)
  buildingsLayer.sourceLayerIdentifier = "building"

  // Set the fill extrusion color, height, and base.
  buildingsLayer.fillExtrusionColor = NSExpression(forConstantValue: UIColor.lightGray)
  buildingsLayer.fillExtrusionHeight = NSExpression(forKeyPath: "render_height")
  buildingsLayer.fillExtrusionBase = NSExpression(forKeyPath: "render_min_height")
  buildingsLayer.fillExtrusionOpacity = NSExpression(forConstantValue: 0.6)

  guard let firstSymbolLayer = style.firstSymbolLayer else {
    assertionFailure("symbolLayer was unexpectedly nil")
    return
  }
  style.insertLayer(buildingsLayer, below: firstSymbolLayer)
}

extension MapView: UIViewRepresentable {
  func makeCoordinator() -> Coordinator {
    let topControls = TopControls(pendingMapFocus: $pendingMapFocus)
    let topControlsController = UIHostingController(rootView: topControls)
    return Coordinator(self, topControlsController: topControlsController)
  }

  typealias UIViewType = MLNMapView
  func makeUIView(context: Context) -> Self.UIViewType {
    let styleURL = AppConfig().tileserverStyleUrl

    // create the mapview
    let mlnMapView = MLNMapView(frame: .zero, styleURL: styleURL)
    context.coordinator.mlnMapView = mlnMapView

    mlnMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    mlnMapView.logoView.isHidden = true

    let tapGesture = UITapGestureRecognizer(
      target: context.coordinator, action: #selector(context.coordinator.mapView(didTap:)))
    mlnMapView.gestureRecognizers?.forEach(tapGesture.require(toFail:))
    mlnMapView.addGestureRecognizer(tapGesture)

    let longPressGesture = UILongPressGestureRecognizer(
      target: context.coordinator, action: #selector(context.coordinator.mapView(didLongPress:)))
    mlnMapView.gestureRecognizers?.forEach(longPressGesture.require(toFail:))
    mlnMapView.addGestureRecognizer(longPressGesture)

    Env.current.getMapFocus = { LngLat(coord: mlnMapView.centerCoordinate) }
    Env.current.getMapCamera = { (mlnMapView.camera.copy() as! MLNMapCamera) }
    do {
      var padding = UIEdgeInsets.zero
      // This is a conservative estimate for notched devices.
      // TODO: calculate this dynamically (the trick is we wont know it until the view has been laid out)
      padding.top += 60

      // TODO: calculate this dynamically based on wether a sheet is presented and bottom safe area insets
      padding.bottom += UIScreen.main.bounds.height / 2
      mlnMapView.setContentInset(padding, animated: false, completionHandler: nil)

      // The built-in attribution control is positioned relative to the contentInset, which means it'll appear in the middle of the screen.
      // Instead attribution is handled in a custom control.
      mlnMapView.attributionButton.isHidden = true
    }

    let originalLocationManagerDelegate = mlnMapView.locationManager.delegate
    mlnMapView.locationManager.delegate = context.coordinator
    context.coordinator.originalLocationManagerDelegate = originalLocationManagerDelegate

    do {
      let controlsUIView = context.coordinator.topControlsController.view!
      controlsUIView.translatesAutoresizingMaskIntoConstraints = false
      controlsUIView.backgroundColor = .clear
      mlnMapView.addSubview(controlsUIView)

      let controlMargin: CGFloat = 8
      NSLayoutConstraint.activate([
        controlsUIView.trailingAnchor.constraint(
          equalTo: mlnMapView.safeAreaLayoutGuide.trailingAnchor, constant: -controlMargin),
        controlsUIView.topAnchor.constraint(
          equalTo: mlnMapView.safeAreaLayoutGuide.topAnchor, constant: 2 * controlMargin),
      ])

      // We want the compass to appear below our controls,
      // To Debug:
      //     mapView.compassView.compassVisibility = .visible
      // This math is a bit fickle and might not be semantically correct, but looks about right emperically.
      let bottomOfTopControl = TopControls.controlHeight * 2 - mlnMapView.contentInset.top + 16

      mlnMapView.compassViewMargins = CGPoint(
        x: controlMargin, y: bottomOfTopControl + controlMargin)
    }

    // FIXME: pull from storage, else start somewhere interesting.
    mlnMapView.setCenter(
      CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3),
      zoomLevel: 10,
      animated: false)

    mlnMapView.delegate = context.coordinator
    return mlnMapView
  }

  func updateUIView(_ mapView: Self.UIViewType, context: Context) {
    logger.debug("in MapView.updateUIView")
    if self.pendingMapFocus != nil {
      Task {
        await MainActor.run {
          guard let pendingMapFocus = self.pendingMapFocus else {
            // since expired
            return
          }
          switch pendingMapFocus {
          case .place(let place):
            self.pendingMapFocus = nil
            if self.userLocationManager.state == .following {
              self.userLocationManager.state = .showing
            }
            if let bbox = place.bbox {
              let bounds = Bounds(bbox: bbox).mlnBounds
              context.coordinator.zoom(
                mapView: mapView, bounds: bounds, bufferMeters: 200,
                animated: true)
            } else {
              context.coordinator.zoom(
                mapView: mapView, center: place.location, bufferMeters: 100, animated: true)
            }
          case .trip(let trip):
            self.pendingMapFocus = nil
            if self.userLocationManager.state == .following {
              self.userLocationManager.state = .showing
            }
            let bounds = trip.raw.bounds
            context.coordinator.zoom(
              mapView: mapView, bounds: bounds.mlnBounds, bufferMeters: 0, animated: true)
          case .pendingSearchResults(_):
            // do nothing. still waiting.
            break
          case .searchResults(let places):
            guard let bounds = Bounds(lngLats: places.map { $0.location }) else {
              return
            }
            self.pendingMapFocus = nil
            if self.userLocationManager.state == .following {
              self.userLocationManager.state = .showing
            }

            context.coordinator.zoom(
              mapView: mapView, bounds: bounds.mlnBounds, bufferMeters: 0, animated: true)
          case .userLocation:
            guard let location = self.userLocationManager.mostRecentUserLocation else {
              // still waiting for user location
              return
            }
            self.pendingMapFocus = nil
            mapView.setCenter(location.coordinate, zoomLevel: 14, animated: true)
          }
        }
      }
    }

    let mapContents: MapContents
    if case .success(let trips) = self.tripPlan.trips, let selectedTrip = self.tripPlan.selectedTrip
    {
      let selected = MapTrip(trip: selectedTrip, isSelected: true)
      let unselected = trips.filter { $0 != selectedTrip }.map {
        MapTrip(trip: $0, isSelected: false)
      }
      mapContents = .trips(selected: selected, unselected: unselected)
    } else if let places = self.searchResults {
      let selected = selectedPlace.map {
        PlaceMarker(place: $0.intoMarkerLocation, style: .pin)
      }
      let unselected = places.filter { $0 != selectedPlace }.map {
        PlaceMarker(place: $0.intoMarkerLocation, style: .pin)
      }
      mapContents = .pins(selected: selected, unselected: unselected)
    } else if let selectedPlace {
      mapContents = .pins(
        selected: PlaceMarker(place: selectedPlace.intoMarkerLocation, style: .pin), unselected: [])
    } else {
      mapContents = .empty
    }
    context.coordinator.reconcile(newContents: mapContents, mapView: mapView)

    switch userLocationManager.state {
    case .initial:
      // This should be transitory - UserLocationManager prompts for location upon launch.
      break
    case .showing:
      if !mapView.showsUserLocation {
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
      }
      if mapView.userTrackingMode != .none {
        logger.debug(
          "setting tracking mode from \(String(describing: mapView.userTrackingMode)) -> .none")
        mapView.setUserTrackingMode(
          .none, animated: true,
          completionHandler: {
            let newTrackingMode = mapView.userTrackingMode
            logger.debug("set new tracking mode \(debugString(newTrackingMode))")
          })
      }
    case .following:
      if !mapView.showsUserLocation {
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
      }
      if mapView.userTrackingMode != .follow {
        logger.debug(
          "setting tracking mode from \(String(describing: mapView.userTrackingMode)) -> .follow")
        mapView.setUserTrackingMode(
          .follow, animated: true,
          completionHandler: {
            let newTrackingMode = mapView.userTrackingMode
            logger.debug("set new tracking mode \(debugString(newTrackingMode))")
          })
      }
    case .denied:
      break
    }
  }

  class Coordinator: NSObject {
    weak var originalLocationManagerDelegate: MLNLocationManagerDelegate?

    let mapView: MapView
    weak var mlnMapView: MLNMapView?

    var mapContents: MapContents = .empty

    var topControlsController: UIHostingController<TopControls>
    var selectedTrips: [Trip: (MLNShapeSource, MLNLineStyleLayer)] = [:]
    var unselectedTrips: [Trip: (MLNShapeSource, MLNLineStyleLayer)] = [:]

    init(
      _ mapView: MapView, topControlsController: UIHostingController<TopControls>
    ) {
      self.mapView = mapView
      self.topControlsController = topControlsController
    }

    // Zooms, with bottom padding so that bottom sheet doesn't cover the point.
    func zoom(mapView: MLNMapView, center: LngLat, bufferMeters: Float64, animated isAnimated: Bool)
    {
      let bounds = MLNCoordinateBounds(sw: center.asCoordinate, ne: center.asCoordinate)
      self.zoom(mapView: mapView, bounds: bounds, bufferMeters: bufferMeters, animated: isAnimated)
    }

    // Zooms, with bottom padding so that bottom sheet doesn't cover the bounds
    func zoom(
      mapView: MLNMapView, bounds: MLNCoordinateBounds, bufferMeters: Float64,
      animated isAnimated: Bool
    ) {
      let bufferedBounds = bounds.extend(bufferMeters: bufferMeters)

      let inset: CGFloat = 30
      let extraBottomInset: CGFloat = 20
      let padding = UIEdgeInsets(
        top: inset, left: inset, bottom: inset + extraBottomInset, right: inset)

      mapView.setVisibleCoordinateBounds(
        bufferedBounds, edgePadding: padding, animated: true, completionHandler: nil)
    }

    func reconcile(newContents: MapContents, mapView: MLNMapView) {
      AssertMainThread()
      let diff = mapContents.diff(newContents: newContents)
      for remove in diff.removes {
        remove.remove(from: mapView)
      }
      for add in diff.adds {
        add.add(to: mapView)
      }
      self.mapContents = newContents
    }

    @MainActor
    func mapView(_ mapView: MLNMapView, didTapTripLegId tripLegId: TripLegId) {
      AssertMainThread()
      guard case Result.success(let trips) = self.mapView.tripPlan.trips else {
        assertionFailure("no trips found")
        return
      }
      guard let selectedTrip = trips.first(where: { $0.id == tripLegId.tripId }) else {
        assertionFailure("no trip found for tapped id: \(tripLegId)")
        return
      }
      self.mapView.tripPlan.selectedTrip = selectedTrip
    }

    @MainActor
    func mapView(_ mapView: MLNMapView, didTapPOI place: MLNPointFeature) {
      let initialSelectedPlace = self.mapView.selectedPlace
      Task {
        do {
          let newPlace = try await GeocodeClient().details(
            placeID: .lngLat(LngLat(coord: place.coordinate)))
          await MainActor.run {
            guard initialSelectedPlace == self.mapView.selectedPlace else {
              print("ignoring tapped place since user has since selected another place.")
              return
            }
            self.mapView.selectedPlace = newPlace
          }
        } catch {
          assertionFailure("geocoding failed: \(error)")
        }
      }
    }

    @objc
    @MainActor
    func mapView(didTap sender: UITapGestureRecognizer) {
      guard let view = sender.view else {
        assertionFailure("gesture was not in view")
        return
      }
      guard let mapView = view as? MLNMapView else {
        assertionFailure("view hosting gesture was not an MLNMapView")
        return
      }

      let touchPoint = sender.location(in: mapView)

      if self.mapView.tripPlan.isEmpty {
        // to get layerIds: print(">>>> mapView layers: \(mapView.style!.layers)")
        let poiLayers = Set(["poi_z14", "poi_z15", "poi_z16"])
        if let tappedPOI = mapView.visibleFeatures(at: touchPoint, styleLayerIdentifiers: poiLayers)
          .first
        {
          guard let point = tappedPOI as? MLNPointFeature else {
            assertionFailure("unexpected poi: \(tappedPOI)")
            return
          }
          self.mapView(mapView, didTapPOI: point)
        }
      } else {
        // `visibleFeatures(at: point)` requires a very precise tap.
        //
        // Anecdotally, I find myself tapping multiple times before I successfully select the route.
        // so we add some slop and use a Rect selector rather than the point selector
        let slop: CGFloat = 10
        let touchRect = CGRect(
          x: touchPoint.x - slop, y: touchPoint.y - slop, width: slop * 2, height: slop * 2)

        // styleLayerIdentifiers:
        let features = mapView.visibleFeatures(in: touchRect)

        for feature in features {
          guard let featureId = feature.identifier as? String else {
            continue
          }
          guard let tripLegId = try? TripLegId(string: featureId) else {
            // We might want to handle other feature taps - e.g. tapping a trashcan or bus depot
            continue
          }
          // If there are multiple features, we return whichever is first, not necessarily which is closest.
          // If this proves problematc, we can sort the results by distance from touchPoint.
          self.mapView(mapView, didTapTripLegId: tripLegId)
        }
      }
    }

    @objc
    @MainActor
    func mapView(didLongPress gesture: UILongPressGestureRecognizer) {
      guard let mapView: MLNMapView = gesture.view as? MLNMapView else {
        assertionFailure("mapView was unexpectedly nil")
        return
      }
      guard gesture.state == .began else {
        return
      }
      guard self.mapView.tripPlan.isEmpty else {
        print("Ignoring long press gesture while trip plan is not empty.")
        return
      }

      let initialSelectedPlace = self.mapView.selectedPlace

      let point = gesture.location(in: mapView)
      let lngLat = LngLat(coord: mapView.convert(point, toCoordinateFrom: mapView))

      Task {
        let place =
          try await GeocodeClient().details(placeID: .lngLat(lngLat))
          ?? Place(location: lngLat.asCLLocation)

        await MainActor.run {
          guard initialSelectedPlace == self.mapView.selectedPlace else {
            print("ignoring longpressed place since user has since selected another place.")
            return
          }
          self.mapView.selectedPlace = place
        }
      }
    }
  }
}

extension MapView.Coordinator: MLNMapViewDelegate {
  func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
    add3DBuildingsLayer(style: style)
  }

  func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
    switch self.mapContents {
    case .trips, .empty:
      break
    case .pins(selected: _, let unselected):
      if let mapPlace = unselected.first(where: { $0.annotation.isEqual(annotation) }) {
        switch mapPlace.place {
        case .place(let place):
          self.mapView.selectedPlace = place
        case .tripPlace(let tripPlace):
          assertionFailure(
            "selecting 'TripPlace': \(tripPlace) not currently supported (or expected)")
        }
      }
    }
  }

  func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation)
    -> MLNAnnotationView?
  {
    guard let pointAnnotation = annotation as? MLNPointAnnotation,
      let marker = PlaceMarker.markerLookup[pointAnnotation]
    else {
      return nil
    }
    switch marker.style {
    case .pin:
      return nil
    case .start:
      let view = MLNAnnotationView()
      view.addSubview(StartMarkerView())
      return view
    case .selectedTripTransfer:
      let view = MLNAnnotationView()
      view.addSubview(TransferMarkerView(isSelected: true))
      return view
    case .unselectedTripTransfer:
      let view = MLNAnnotationView()
      view.addSubview(TransferMarkerView(isSelected: false))
      return view
    }
  }

  func mapView(_ mapView: MLNMapView, didChange mode: MLNUserTrackingMode, animated: Bool) {
    Task {
      await MainActor.run {
        logger.debug("MLNUserTrackingMode didChange: \(debugString(mode))")
        switch mode {
        case .none:
          if self.mapView.userLocationManager.state == .following {
            self.mapView.userLocationManager.state = .showing
          }
        case .follow, .followWithHeading, .followWithCourse:
          if self.mapView.userLocationManager.state != .following {
            self.mapView.userLocationManager.state = .following
          }
        @unknown default:
          assertionFailure("unexpected MLNUserTrackingModeL \(String(describing: mode))")
        }
      }
    }
  }
}

// Extend default delegate implementation
extension MapView.Coordinator: MLNLocationManagerDelegate {

  // Explicit objc bindings avoid an error while compiling preview
  // Otherwise there's a conflict between method names
  @objc(locationManager:didUpdateLocations:)
  func locationManager(_ manager: any MLNLocationManager, didUpdate locations: [CLLocation]) {
    AssertMainThread()
    self.originalLocationManagerDelegate?.locationManager(manager, didUpdate: locations)

    guard let mostRecentLocation = locations.last else {
      logger.error("mostRecentLocation was unexpectedly nil in locationManger(_:didUpdate)")
      return
    }
    self.mapView.userLocationManager.mostRecentUserLocation = mostRecentLocation
  }

  // Explicit objc bindings avoid an error while compiling preview
  // Otherwise there's a conflict between method names
  @objc(locationManager:didUpdateHeading:)
  func locationManager(_ manager: any MLNLocationManager, didUpdate newHeading: CLHeading) {
    AssertMainThread()
    self.originalLocationManagerDelegate?.locationManager(manager, didUpdate: newHeading)
  }

  func locationManagerShouldDisplayHeadingCalibration(_ manager: any MLNLocationManager) -> Bool {
    AssertMainThread()
    return self.originalLocationManagerDelegate?.locationManagerShouldDisplayHeadingCalibration(
      manager) ?? false
  }

  func locationManager(_ manager: any MLNLocationManager, didFailWithError error: any Error) {
    AssertMainThread()
    self.originalLocationManagerDelegate?.locationManager(manager, didFailWithError: error)
  }

  func locationManagerDidChangeAuthorization(_ manager: any MLNLocationManager) {
    AssertMainThread()
    self.originalLocationManagerDelegate?.locationManagerDidChangeAuthorization(manager)

    logger.info(
      "locationManagerDidChangeAuthorization. manager.authorizationStatus \(format(authorizationStatus: manager.authorizationStatus))"
    )
    if manager.authorizationStatus == .denied {
      self.mapView.userLocationManager.state = .denied
    }
  }
}

func debugString(_ trackingMode: MLNUserTrackingMode) -> String {
  switch trackingMode {
  case .none:
    "None"
  case .follow:
    "Follow"
  case .followWithHeading:
    "FollowWithHeading"
  case .followWithCourse:
    "FollowWithCourse"
  @unknown default:
    "unknown - rawValue:\(trackingMode.rawValue)"
  }
}

extension Bounds {
  var mlnBounds: MLNCoordinateBounds {
    MLNCoordinateBounds(sw: self.min.asCoordinate, ne: self.max.asCoordinate)
  }
}

extension MLNStyle {
  var openMapTilesSource: MLNSource? {
    guard let source = (self.sources.first { $0.identifier == "openmaptiles" }) else {
      assertionFailure("openmaptiles source was unexpectedly missing")
      return nil
    }
    return source
  }

  var firstSymbolLayer: MLNSymbolStyleLayer? {
    self.layers.compactMap { $0 as? MLNSymbolStyleLayer }.first
  }
}

private func format(authorizationStatus status: CLAuthorizationStatus) -> String {
  switch status {
  case .notDetermined:
    "notDetermined"
  case .restricted:
    "restricted"
  case .denied:
    "denied"
  case .authorizedAlways:
    "authorizedAlways"
  case .authorizedWhenInUse:
    "authorizedWhenInUse"
  @unknown default:
    "unknown: \(status)"
  }
}

#Preview("MapView") {
  let tripPlan = ObservedObject(initialValue: FixtureData.transitTripPlan)
  let searchQueue = Binding.constant(SearchQueue(mostRecentResults: FixtureData.places.all))
  return MapView(
    searchResults: searchQueue.mostRecentResults, selectedPlace: tripPlan.projectedValue.navigateTo,
    pendingMapFocus: .constant(nil),
    tripPlan: tripPlan.wrappedValue
  )
  .edgesIgnoringSafeArea(.all)
}
