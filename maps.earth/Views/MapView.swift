//
//  MapView.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import Foundation
import MapLibre
import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigation
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
  @Binding var userLocationState: UserLocationState
  @Binding var mostRecentUserLocation: CLLocation?
  @Binding var pendingMapFocus: MapFocus?
  @ObservedObject var tripPlan: TripPlan
}

func add3DBuildingsLayer(mapView: MLNMapView) {
  guard let style = mapView.style else {
    assertionFailure("mapView.style was unexpectedly nil")
    return
  }

  assert(style.layers.first { $0.identifier == "subtle_3d_buildings" } == nil)

  guard let source = (style.sources.first { $0.identifier == "openmaptiles" }) else {
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

  guard let symbolLayer = (style.layers.first { $0 is MLNSymbolStyleLayer }) else {
    assertionFailure("symbolLayer was unexpectedly nil")
    return
  }
  style.insertLayer(buildingsLayer, below: symbolLayer)
}

extension MapView: UIViewRepresentable {
  func makeCoordinator() -> Coordinator {
    let topControls = TopControls(
      userLocationState: $userLocationState, pendingMapFocus: $pendingMapFocus)
    let topControlsController = UIHostingController(rootView: topControls)
    return Coordinator(
      self, topControlsController: topControlsController)
  }

  typealias UIViewType = NavigationMapView
  func makeUIView(context: Context) -> NavigationMapView {
    let styleURL = AppConfig().tileserverStyleUrl

    // create the mapview
    let mapView = NavigationMapView(frame: .zero, styleURL: styleURL)
    context.coordinator.mlnNavigationMapView = mapView
    assert(mapView.navigationMapDelegate == nil)
    mapView.navigationMapDelegate = context.coordinator
    mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    mapView.logoView.isHidden = true
    Env.current.getMapFocus = { LngLat(coord: mapView.centerCoordinate) }
    do {
      var padding = UIEdgeInsets.zero
      // This is a conservative estimate for notched devices.
      // TODO: calculate this dynamically (the trick is we wont know it until the view has been laid out)
      padding.top += 60

      // TODO: calculate this dynamically based on wether a sheet is presented and bottom safe area insets
      padding.bottom += UIScreen.main.bounds.height / 2
      mapView.setContentInset(padding, animated: false, completionHandler: nil)

      // The built-in attribution control is positioned relative to the contentInset, which means it'll appear in the middle of the screen.
      // Instead attribution is handled in a custom control.
      mapView.attributionButton.isHidden = true
    }

    let originalLocationManagerDelegate = mapView.locationManager.delegate
    mapView.locationManager.delegate = context.coordinator
    context.coordinator.originalLocationManagerDelegate = originalLocationManagerDelegate

    do {
      let controlsUIView = context.coordinator.topControlsController.view!
      controlsUIView.translatesAutoresizingMaskIntoConstraints = false
      controlsUIView.backgroundColor = .clear
      mapView.addSubview(controlsUIView)

      let controlMargin: CGFloat = 8
      NSLayoutConstraint.activate([
        controlsUIView.trailingAnchor.constraint(
          equalTo: mapView.safeAreaLayoutGuide.trailingAnchor, constant: -controlMargin),
        controlsUIView.topAnchor.constraint(
          equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 2 * controlMargin),
      ])

      // We want the compass to appear below our controls,
      // To Debug:
      //     mapView.compassView.compassVisibility = .visible
      // This math is a bit fickle and might not be semantically correct, but looks about right emperically.
      let bottomOfTopControl = TopControls.controlHeight * 2 - mapView.contentInset.top + 16

      mapView.compassViewMargins = CGPoint(x: controlMargin, y: bottomOfTopControl + controlMargin)
    }

    // FIXME: pull from storage, else start somewhere interesting.
    mapView.setCenter(
      CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3),
      zoomLevel: 10,
      animated: false)

    mapView.delegate = context.coordinator
    return mapView
  }

  func updateUIView(_ mapView: NavigationMapView, context: Context) {
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
            if self.userLocationState == .following {
              self.userLocationState = .showing
            }
            mapView.setCenter(place.location.asCoordinate, zoomLevel: 14, animated: true)
          case .trip(let trip):
            self.pendingMapFocus = nil
            if self.userLocationState == .following {
              self.userLocationState = .showing
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
            if self.userLocationState == .following {
              self.userLocationState = .showing
            }

            context.coordinator.zoom(
              mapView: mapView, bounds: bounds.mlnBounds, bufferMeters: 0, animated: true)
          case .userLocation:
            guard let location = self.mostRecentUserLocation else {
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
      // TODO zoom to search results bbox (add to focus enum)
    } else {
      mapContents = .empty
    }
    context.coordinator.reconcile(newContents: mapContents, mapView: mapView)

    switch userLocationState {
    case .initial:
      DispatchQueue.main.async {
        // This will prompt for location permission on first load.
        // If the user accepts, their blue dot will be shown and we'll have their location ready for routing.
        // If the user denies, no problem. This state will be updated such that the "locate me" control will be disabled.
        userLocationState = .showing
      }
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
    weak var mlnNavigationMapView: NavigationMapView?

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
    func zoom(mapView: MLNMapView, center: LngLat, animated isAnimated: Bool) {
      let bounds = MLNCoordinateBounds(sw: center.asCoordinate, ne: center.asCoordinate)
      self.zoom(mapView: mapView, bounds: bounds, bufferMeters: 1000, animated: isAnimated)
    }

    // Zooms, with bottom padding so that bottom sheet doesn't cover the bounds
    func zoom(
      mapView: MLNMapView, bounds: MLNCoordinateBounds, bufferMeters: Float64,
      animated isAnimated: Bool
    ) {
      func extend(bounds: MLNCoordinateBounds, bufferMeters: Float64) -> MLNCoordinateBounds {
        let earthRadius = 6378137.0  // Earth's radius in meters
        let deltaLatitude = bufferMeters / earthRadius

        let deltaMinLongitude = bufferMeters / (earthRadius * cos(.pi * bounds.sw.latitude / 180))
        let minLatitude = bounds.sw.latitude - deltaLatitude * (180 / .pi)
        let minLongitude = bounds.sw.longitude - deltaMinLongitude * (180 / .pi)

        let deltaMaxLongitude = bufferMeters / (earthRadius * cos(.pi * bounds.ne.latitude / 180))
        let maxLongitude = bounds.ne.longitude + deltaMaxLongitude * (180 / .pi)
        let maxLatitude = bounds.ne.latitude + deltaLatitude * (180 / .pi)

        let sw = CLLocationCoordinate2D(latitude: minLatitude, longitude: minLongitude)
        let ne = CLLocationCoordinate2D(latitude: maxLatitude, longitude: maxLongitude)
        return MLNCoordinateBounds(sw: sw, ne: ne)
      }

      let bufferedBounds = extend(bounds: bounds, bufferMeters: bufferMeters)

      let inset: CGFloat = 30
      let extraBottomInset: CGFloat = 20
      let padding = UIEdgeInsets(
        top: inset, left: inset, bottom: inset + extraBottomInset, right: inset)

      mapView.setVisibleCoordinateBounds(
        bufferedBounds, edgePadding: padding, animated: true, completionHandler: nil)
    }

    func reconcile(newContents: MapContents, mapView: MLNMapView) {
      dispatchPrecondition(condition: .onQueue(.main))
      let diff = mapContents.diff(newContents: newContents)
      for remove in diff.removes {
        remove.remove(from: mapView)
      }
      for add in diff.adds {
        add.add(to: mapView)
      }
      self.mapContents = newContents
    }

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
  }
}

extension MapView.Coordinator: MLNMapViewDelegate {
  // e.g. after style is applied
  func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
    add3DBuildingsLayer(mapView: mapView)
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
          if self.mapView.userLocationState == .following {
            self.mapView.userLocationState = .showing
          }
        case .follow, .followWithHeading, .followWithCourse:
          if self.mapView.userLocationState != .following {
            self.mapView.userLocationState = .following
          }
        @unknown default:
          assertionFailure("unexpected MLNUserTrackingModeL \(String(describing: mode))")
        }
      }
    }
  }
}

extension MapView.Coordinator: NavigationMapViewDelegate {
  func navigationMapView(
    _ mapView: NavigationMapView, didReceiveUnhandledTap sender: UITapGestureRecognizer
  ) {
    guard let view = sender.view else {
      assertionFailure("gesture was not in view")
      return
    }
    guard let mapView = view as? MLNMapView else {
      assertionFailure("view hosting gesture was not an MLNMapView")
      return
    }

    let touchPoint = sender.location(in: mapView)
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

// Extend default delegate implementation
extension MapView.Coordinator: MLNLocationManagerDelegate {

  // Explicit objc bindings avoid an error while compiling preview
  // Otherwise there's a conflict between method names
  @objc(locationManager:didUpdateLocations:)
  func locationManager(_ manager: any MLNLocationManager, didUpdate locations: [CLLocation]) {
    dispatchPrecondition(condition: .onQueue(.main))
    self.originalLocationManagerDelegate?.locationManager(manager, didUpdate: locations)

    guard let mostRecentLocation = locations.last else {
      logger.error("mostRecentLocation was unexpectedly nil in locationManger(_:didUpdate)")
      return
    }
    self.mapView.mostRecentUserLocation = mostRecentLocation
  }

  // Explicit objc bindings avoid an error while compiling preview
  // Otherwise there's a conflict between method names
  @objc(locationManager:didUpdateHeading:)
  func locationManager(_ manager: any MLNLocationManager, didUpdate newHeading: CLHeading) {
    dispatchPrecondition(condition: .onQueue(.main))
    self.originalLocationManagerDelegate?.locationManager(manager, didUpdate: newHeading)
  }

  func locationManagerShouldDisplayHeadingCalibration(_ manager: any MLNLocationManager) -> Bool {
    dispatchPrecondition(condition: .onQueue(.main))
    return self.originalLocationManagerDelegate?.locationManagerShouldDisplayHeadingCalibration(
      manager) ?? false
  }

  func locationManager(_ manager: any MLNLocationManager, didFailWithError error: any Error) {
    dispatchPrecondition(condition: .onQueue(.main))
    self.originalLocationManagerDelegate?.locationManager(manager, didFailWithError: error)
  }

  func locationManagerDidChangeAuthorization(_ manager: any MLNLocationManager) {
    dispatchPrecondition(condition: .onQueue(.main))
    self.originalLocationManagerDelegate?.locationManagerDidChangeAuthorization(manager)

    if manager.authorizationStatus == .denied {
      self.topControlsController.rootView.userLocationState = .denied
    }
  }
}

extension MapView.Coordinator: RouteControllerDelegate {
  @objc public func routeController(
    _ routeController: RouteController, didUpdate locations: [CLLocation]
  ) {
    let camera = MLNMapCamera(
      lookingAtCenter: locations.first!.coordinate,
      acrossDistance: 500,
      pitch: 0,
      heading: 0
    )

    mlnNavigationMapView?.setCamera(camera, animated: true)
  }

  @objc func didPassVisualInstructionPoint(notification: NSNotification) {
    guard
      let currentVisualInstruction = currentStepProgress(from: notification)?
        .currentVisualInstruction
    else { return }

    //    print(
    //      String(
    //        format: "didPassVisualInstructionPoint primary text: %@ and secondary text: %@",
    //        String(describing: currentVisualInstruction.primaryInstruction.text),
    //        String(describing: currentVisualInstruction.secondaryInstruction?.text)))
  }

  @objc func didPassSpokenInstructionPoint(notification: NSNotification) {
    guard
      let currentSpokenInstruction = currentStepProgress(from: notification)?
        .currentSpokenInstruction
    else { return }

    //    print("didPassSpokenInstructionPoint text: \(currentSpokenInstruction.text)")
  }

  private func currentStepProgress(from notification: NSNotification) -> RouteStepProgress? {
    let routeProgress =
      notification.userInfo?[RouteControllerNotificationUserInfoKey.routeProgressKey]
      as? RouteProgress
    return routeProgress?.currentLegProgress.currentStepProgress
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

#Preview("MapView") {
  let tripPlan = ObservedObject(initialValue: FixtureData.transitTripPlan)
  let searchQueue = Binding.constant(SearchQueue(mostRecentResults: FixtureData.places.all))
  let currentLocation = FixtureData.places[.zeitgeist].location
  return MapView(
    searchResults: searchQueue.mostRecentResults, selectedPlace: tripPlan.projectedValue.navigateTo,
    userLocationState: .constant(.initial),
    mostRecentUserLocation: .constant(
      CLLocation(latitude: currentLocation.lat, longitude: currentLocation.lng)),
    pendingMapFocus: .constant(nil),
    tripPlan: tripPlan.wrappedValue
  )
  .edgesIgnoringSafeArea(.all)
}
