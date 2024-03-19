//
//  MapView.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import Foundation
import MapLibre
import OSLog
import SwiftUI

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

private let logger = Logger(
  subsystem: Bundle.main.bundleIdentifier!,
  category: String(describing: #file)
)

let DefaultZoomLevel: CGFloat = 13

enum MapFocus: Equatable {
  case place(Place)
  case trip(Trip)
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
    case .searchResults(let places):
      "MapFocus.searchResults([\(places.count) Places])"
    case .userLocation:
      "MapFocus.userLocation"
    }
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

extension MapView: UIViewRepresentable {

  func makeCoordinator() -> Coordinator {
    let locateMeButton = LocateMeButton(
      state: $userLocationState, pendingMapFocus: $pendingMapFocus)
    let locateMeButtonController = UIHostingController(rootView: locateMeButton)
    return Coordinator(
      self, locateMeButtonController: locateMeButtonController)
  }

  typealias UIViewType = MLNMapView
  func makeUIView(context: Context) -> MLNMapView {
    let styleURL = AppConfig().tileserverStyleUrl

    // create the mapview
    let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
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

      mapView.attributionButton.isHidden = true
    }

    let originalLocationManagerDelegate = mapView.locationManager.delegate
    mapView.locationManager.delegate = context.coordinator
    context.coordinator.originalLocationManagerDelegate = originalLocationManagerDelegate

    do {
      let buttonUIView = context.coordinator.locateMeButtonController.view!
      buttonUIView.translatesAutoresizingMaskIntoConstraints = false
      buttonUIView.backgroundColor = .clear
      mapView.addSubview(buttonUIView)

      let controlMargin: CGFloat = 8
      // Apply constraints or set the frame
      NSLayoutConstraint.activate([
        buttonUIView.trailingAnchor.constraint(
          equalTo: mapView.safeAreaLayoutGuide.trailingAnchor, constant: -controlMargin),
        buttonUIView.topAnchor.constraint(
          equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 2 * controlMargin),
      ])

      // We want the compass to appear below our controls,
      // so we override constraint from maplibre which pins to the container.
      // To Debug:
      //     mapView.compassView.compassVisibility = .visible
      mapView.compassViewMargins = CGPoint(x: controlMargin, y: controlMargin)
    }

    // FIXME: pull from storage, else start somewhere interesting.
    mapView.setCenter(
      CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3),
      zoomLevel: 10,
      animated: false)

    mapView.delegate = context.coordinator
    return mapView
  }

  func updateUIView(_ mapView: MLNMapView, context: Context) {
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

    if let selectedTrip = self.tripPlan.selectedTrip {
      context.coordinator.ensureMarkers(in: mapView, places: [selectedTrip.to])
      context.coordinator.ensureRoutes(
        in: mapView, trips: self.tripPlan.trips, selectedTrip: selectedTrip)
    } else if let selectedPlace = selectedPlace {
      context.coordinator.ensureMarkers(in: mapView, places: [selectedPlace])
      context.coordinator.ensureRoutes(in: mapView, trips: [], selectedTrip: nil)
    } else if let places = self.searchResults {
      context.coordinator.ensureMarkers(in: mapView, places: places)
      context.coordinator.ensureRoutes(in: mapView, trips: [], selectedTrip: nil)
      // TODO zoom to search results bbox (add to focus enum)
    } else {
      context.coordinator.ensureMarkers(in: mapView, places: [])
      context.coordinator.ensureRoutes(in: mapView, trips: [], selectedTrip: nil)
    }

    switch userLocationState {
    case .initial:
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

    var locateMeButtonController: UIHostingController<LocateMeButton>
    // pin markers, like those used in search or at the end of a trip
    var markers: [Place: MLNAnnotation] = [:]
    // circle markers, like those used at the start of a trip
    var startMarkers: [Place: MLNAnnotation] = [:]
    var selectedTrips: [Trip: (MLNShapeSource, MLNLineStyleLayer)] = [:]
    var unselectedTrips: [Trip: (MLNShapeSource, MLNLineStyleLayer)] = [:]

    init(
      _ mapView: MapView, locateMeButtonController: UIHostingController<LocateMeButton>
    ) {
      self.mapView = mapView
      self.locateMeButtonController = locateMeButtonController
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

    func ensureMarkers(in mapView: MLNMapView, places: [Place]) {
      for place in places {
        if self.markers[place] == nil {
          let marker = Self.addMarker(to: mapView, at: place.location)
          self.markers[place] = marker
        }
      }

      let stale = Set(self.markers.keys).subtracting(places)
      for place in stale {
        guard let marker = self.markers.removeValue(forKey: place) else {
          logger.error("unexpectedly missing stale marker")
          continue
        }
        // PERF: more efficient to do this all at once with `removeAnnotations`?
        mapView.removeAnnotation(marker)
      }
    }

    func ensureStartMarkers(in mapView: MLNMapView, places: [Place]) {
      for place in places {
        if self.startMarkers[place] == nil {
          let marker = Self.addStartMarker(to: mapView, at: place.location)
          self.startMarkers[place] = marker
        }
      }

      let stale = Set(self.startMarkers.keys).subtracting(places)
      for place in stale {
        guard let marker = self.startMarkers.removeValue(forKey: place) else {
          logger.error("unexpectedly missing stale marker")
          continue
        }
        // PERF: more efficient to do this all at once with `removeAnnotations`?
        mapView.removeAnnotation(marker)
      }
    }

    func ensureRoutes(in mapView: MLNMapView, trips: [Trip], selectedTrip: Trip?) {
      guard let style = mapView.style else {
        logger.error("style was unexpectedly nil")
        return
      }

      let stale = Set(self.selectedTrips.keys).union(self.unselectedTrips.keys).subtracting(trips)
      for trip in stale {
        guard
          let (tripSource, tripStyleLayer) = self.selectedTrips.removeValue(forKey: trip)
            ?? self.unselectedTrips.removeValue(forKey: trip)
        else {
          logger.error("unexpectedly missing stale tripOverlays")
          continue
        }

        // NOTE: style can be nil in SwiftUI previews. I think maybe
        // because the style.json hasn't been fetched yet (it's async)
        // Maybe this should be a promise based thing?
        logger.debug("removing source/layer: \(tripSource.identifier)")
        style.removeLayer(tripStyleLayer)
        try! style.removeSource(tripSource, error: ())
      }

      for trip in (trips.filter { $0 != selectedTrip }) {
        if let (tripSource, tripStyleLayer) = self.selectedTrips.removeValue(forKey: trip) {
          // NOTE: style can be nil in SwiftUI previews. I think maybe
          // because the style.json hasn't been fetched yet (it's async)
          // Maybe this should be a promise based thing?
          logger.debug("removing source/layer: \(tripSource.identifier)")
          style.removeLayer(tripStyleLayer)
          try! style.removeSource(tripSource, error: ())
        }
        if self.unselectedTrips[trip] == nil {
          self.unselectedTrips[trip] = Self.addRoute(to: mapView, trip: trip, isSelected: false)
        }
      }

      // add selected layer last so its on top
      if let selectedTrip = selectedTrip {
        if let (tripSource, tripStyleLayer) = self.unselectedTrips.removeValue(forKey: selectedTrip)
        {
          // NOTE: style can be nil in SwiftUI previews. I think maybe
          // because the style.json hasn't been fetched yet (it's async)
          // Maybe this should be a promise based thing?
          logger.debug("removing source/layer: \(tripSource.identifier)")
          style.removeLayer(tripStyleLayer)
          try! style.removeSource(tripSource, error: ())
        }
        if self.selectedTrips[selectedTrip] == nil {
          self.selectedTrips[selectedTrip] = Self.addRoute(
            to: mapView, trip: selectedTrip, isSelected: true)
          self.ensureStartMarkers(in: mapView, places: [selectedTrip.from])
        }
      } else {
        self.ensureStartMarkers(in: mapView, places: [])
      }
    }

    static func addMarker(to mapView: MLNMapView, at lngLat: LngLat) -> MLNAnnotation {
      let marker = MLNPointAnnotation()
      marker.coordinate = CLLocationCoordinate2D(latitude: lngLat.lat, longitude: lngLat.lng)
      mapView.addAnnotation(marker)
      return marker
    }

    static func addStartMarker(to mapView: MLNMapView, at lngLat: LngLat) -> MLNAnnotation {
      // this is identical to addMarker... not sure how to indicate a marker's style should
      // be changed without removing and re-adding it.
      let marker = MLNPointAnnotation()
      marker.coordinate = CLLocationCoordinate2D(latitude: lngLat.lat, longitude: lngLat.lng)
      mapView.addAnnotation(marker)
      return marker
    }

    static func addRoute(to mapView: MLNMapView, trip: Trip, isSelected: Bool) -> (
      MLNShapeSource, MLNLineStyleLayer
    ) {
      let polylines = trip.legs.map { leg in
        polyline(coordinates: leg.geometry)
      }
      let identifier = "trip-route-\(trip.id)-\(isSelected ? "selected" : "unselected")"
      let source = MLNShapeSource(identifier: identifier, shapes: polylines, options: nil)
      let styleLayer = lineStyleLayer(source: source, id: trip.id, isSelected: isSelected)

      logger.debug("adding source/layer: \(identifier)")
      guard let style = mapView.style else {
        logger.error("mapView.style was unexpectedly nil")
        return (source, styleLayer)
      }

      style.addSource(source)

      // Insert behind the annotation layer to keep the "end" markers above the routes.
      //     identifier = com.mapbox.annotations.points; sourceIdentifier = com.mapbox.annotations; sourceLayerIdentifier = com.mapbox.annotations.points
      let annotationLayer = style.layers.first {
        $0.identifier == "com.mapbox.annotations.points"
      }
      // TODO: this unwrap is unsightly, but unlikely to break unless MapLibre changes something fundamental in an update, which should be obvious
      style.insertLayer(styleLayer, below: annotationLayer!)

      return (source, styleLayer)
    }
  }
}

extension MapView.Coordinator: MLNMapViewDelegate {
  func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
    // PERF: this is dumb, but NSObject doesn't place nice with Swift HashMaps so
    // we do a linear search
    guard
      let (place, _) = self.markers.first(where: { (key: Place, value: MLNAnnotation) in
        value.isEqual(annotation)
      })
    else {
      assertionFailure("no place for marker \(annotation)")
      return
    }

    self.mapView.selectedPlace = place
  }

  func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation)
    -> MLNAnnotationView?
  {
    guard let navigateFrom = self.mapView.tripPlan.selectedTrip?.from else {
      return nil
    }

    func equalCoords(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
      a.latitude == b.latitude && a.longitude == b.longitude
    }

    // Coords check seems brittle - what if there are multiple markers at this location?
    // is floating point robustness a concern?
    guard equalCoords(navigateFrom.location.asCoordinate, annotation.coordinate) else {
      return nil
    }

    let view = MLNAnnotationView()
    view.addSubview(StartMarkerView())

    return view
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

// Extend default delegate implementation
extension MapView.Coordinator: MLNLocationManagerDelegate {
  func locationManager(_ manager: any MLNLocationManager, didUpdate locations: [CLLocation]) {
    dispatchPrecondition(condition: .onQueue(.main))
    self.originalLocationManagerDelegate?.locationManager(manager, didUpdate: locations)

    guard let mostRecentLocation = locations.last else {
      logger.error("mostRecentLocation was unexpectedly nil in locationManger(_:didUpdate)")
      return
    }
    self.mapView.mostRecentUserLocation = mostRecentLocation
  }

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
      self.locateMeButtonController.rootView.state = .denied
    }
  }
}

func polyline(coordinates: [CLLocationCoordinate2D]) -> MLNPolylineFeature {
  MLNPolylineFeature(coordinates: coordinates, count: UInt(coordinates.count))
}

func lineStyleLayer(source: MLNSource, id: UUID, isSelected: Bool) -> MLNLineStyleLayer {
  let styleLayer = MLNLineStyleLayer(identifier: "trip-route-\(id)", source: source)
  styleLayer.lineColor = NSExpression(
    forConstantValue: isSelected ? UIColor(Color.hw_activeRoute) : UIColor(Color.hw_inactiveRoute))
  styleLayer.lineWidth = NSExpression(forConstantValue: NSNumber(value: 4))
  return styleLayer
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
