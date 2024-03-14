//
//  MapView.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import Foundation
import MapLibre
import SwiftUI

enum UserLocationState {
  case initial
  case showing
  //  case following
  case denied
}

enum PendingRecenter {
  case pending
  case resolved(CLLocation)
}

struct MapView {
  @Binding var places: [Place]?
  @Binding var selectedPlace: Place?
  @Binding var mapView: MLNMapView?
  @Binding var userLocationState: UserLocationState
  @Binding var mostRecentUserLocation: CLLocation?
  @State var pendingRecenter: PendingRecenter? = nil
  @ObservedObject var tripPlan: TripPlan
}

extension MapView: UIViewRepresentable {

  func makeCoordinator() -> Coordinator {
    let locateMeButton = LocateMeButton(
      state: $userLocationState, pendingRecenter: $pendingRecenter)
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
          equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: controlMargin),
      ])

      // We want the compass to appear below our controls,
      // so we override constraint from maplibre which pins to the container.
      // To Debug:
      //        mapView.compassView.compassVisibility = .visible
      mapView.compassViewMargins = CGPoint(
        x: controlMargin, y: LocateMeButton.height + 2 * controlMargin)
    }

    // FIXME: pull from storage, else start somewhere interesting.
    mapView.setCenter(
      CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3),
      zoomLevel: 10,
      animated: false)

    mapView.delegate = context.coordinator
    Task {
      await MainActor.run {
        print("setting mapView")
        self.mapView = mapView
      }
    }

    return mapView
  }

  func updateUIView(_ mapView: MLNMapView, context: Context) {
    print("in MapView.updateUIView")
    switch userLocationState {
    case .initial:
      break
    case .showing:
      if !mapView.showsUserLocation {
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
      }
    case .denied:
      break
    }

    switch pendingRecenter {
    case nil:
      break
    case .pending:
      // If we already have a location, don't wait for an update. It's likely
      // very near by and substantially lags the UI (anecdotally: under a second, so not super long, but enough
      // to notice)
      if let mostRecentLocation = self.mostRecentUserLocation {
        Task {
          await MainActor.run {
            self.pendingRecenter = nil
            mapView.setCenter(mostRecentLocation.coordinate, zoomLevel: 14, animated: true)
          }
        }
      }
    case .resolved(let pendingRecenter):
      Task {
        await MainActor.run {
          self.pendingRecenter = nil
          mapView.setCenter(pendingRecenter.coordinate, zoomLevel: 14, animated: true)
        }
      }
    }

    if let selectedTrip = self.tripPlan.selectedTrip {
      // TODO: draw unselected routes
      context.coordinator.ensureRoutes(
        in: mapView, trips: self.tripPlan.trips, selectedTrip: selectedTrip)

      // remove markers so that we can be sure to put it back on top - there's gotta be a less dumb way, but this is expedient
      context.coordinator.ensureMarkers(in: mapView, places: [])
      context.coordinator.ensureMarkers(in: mapView, places: [selectedTrip.to])
      context.coordinator.ensureStartMarkers(in: mapView, places: [selectedTrip.from])
    } else {
      context.coordinator.ensureRoutes(in: mapView, trips: [], selectedTrip: nil)
      // TODO: this is overzealous. We only want to do this when the selection changes
      // not whenever the view gets updated. Perhaps other things could cause the view to update,
      // and we don't necessarily want to move the users map around.
      if let selectedPlace = selectedPlace {
        context.coordinator.ensureMarkers(in: mapView, places: [selectedPlace])
        context.coordinator.zoom(mapView: mapView, center: selectedPlace.location, animated: true)
      } else if let places = self.places {
        context.coordinator.ensureMarkers(in: mapView, places: places)
        // TODO zoom to search results bbox
      } else {
        context.coordinator.ensureMarkers(in: mapView, places: [])
      }
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
      self.zoom(mapView: mapView, bounds: bounds, bufferMeters: 1500, animated: isAnimated)
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

      print("safeAreaInsets: \(mapView.safeAreaInsets)")
      let bottomPadding = UIScreen.main.bounds.height / 2 - mapView.safeAreaInsets.top
      let padding = UIEdgeInsets(top: 0, left: 0, bottom: bottomPadding, right: 0)
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
          print("unexpectedly missing stale marker")
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
          print("unexpectedly missing stale marker")
          continue
        }
        // PERF: more efficient to do this all at once with `removeAnnotations`?
        mapView.removeAnnotation(marker)
      }
    }

    func ensureRoutes(in mapView: MLNMapView, trips: [Trip], selectedTrip: Trip?) {
      let stale = Set(self.selectedTrips.keys).union(self.unselectedTrips.keys).subtracting(trips)
      for trip in stale {
        guard
          let (tripSource, tripStyleLayer) = self.selectedTrips.removeValue(forKey: trip)
            ?? self.unselectedTrips.removeValue(forKey: trip)
        else {
          print("unexpectedly missing stale tripOverlays")
          continue
        }

        // NOTE: style can be nil in SwiftUI previews. I think maybe
        // because the style.json hasn't been fetched yet (it's async)
        // Maybe this should be a promise based thing?
        print("removing source/layer: \(tripSource.identifier)")
        mapView.style!.removeLayer(tripStyleLayer)
        try! mapView.style!.removeSource(tripSource, error: ())
      }

      for trip in (trips.filter { $0 != selectedTrip }) {
        if let (tripSource, tripStyleLayer) = self.selectedTrips.removeValue(forKey: trip) {
          // NOTE: style can be nil in SwiftUI previews. I think maybe
          // because the style.json hasn't been fetched yet (it's async)
          // Maybe this should be a promise based thing?
          print("removing source/layer: \(tripSource.identifier)")
          mapView.style!.removeLayer(tripStyleLayer)
          try! mapView.style!.removeSource(tripSource, error: ())
        }
        if self.unselectedTrips[trip] == nil {
          self.unselectedTrips[trip] = Self.addRoute(to: mapView, trip: trip, isSelected: false)
        }
      }

      // add selected layer last so its on top
      if let trip = selectedTrip {
        if let (tripSource, tripStyleLayer) = self.unselectedTrips.removeValue(forKey: trip) {
          // NOTE: style can be nil in SwiftUI previews. I think maybe
          // because the style.json hasn't been fetched yet (it's async)
          // Maybe this should be a promise based thing?
          print("removing source/layer: \(tripSource.identifier)")
          mapView.style!.removeLayer(tripStyleLayer)
          try! mapView.style!.removeSource(tripSource, error: ())
        }
        if self.selectedTrips[trip] == nil {
          self.selectedTrips[trip] = Self.addRoute(to: mapView, trip: trip, isSelected: true)
        }
      }

      if let selectedTrip = selectedTrip {
        let bounds = bounds(selectedTrip.raw.bounds)
        // Maybe this should be a ratio, not fixed meters. e.g. for very far trips (like cross country)
        // this isnt' enough. It might also partially represent a bug in the bounds calculation code
        self.zoom(mapView: mapView, bounds: bounds, bufferMeters: 500, animated: true)
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

      print("adding source/layer: \(identifier)")

      mapView.style!.addSource(source)

      // Insert behind the annotation layer to keep the "end" markers above the routes.
      //     identifier = com.mapbox.annotations.points; sourceIdentifier = com.mapbox.annotations; sourceLayerIdentifier = com.mapbox.annotations.points
      let annotationLayer = mapView.style!.layers.first {
        $0.identifier == "com.mapbox.annotations.points"
      }
      // TODO: this unwrap is unsightly, but unlikely to break unless MapLibre changes something fundamental in an update, which should be obvious
      mapView.style!.insertLayer(styleLayer, below: annotationLayer!)

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
}

// Extend default delegate implementation
extension MapView.Coordinator: MLNLocationManagerDelegate {
  func locationManager(_ manager: any MLNLocationManager, didUpdate locations: [CLLocation]) {
    dispatchPrecondition(condition: .onQueue(.main))
    self.originalLocationManagerDelegate?.locationManager(manager, didUpdate: locations)

    guard let mostRecentLocation = locations.last else {
      print("mostRecentLocation was unexpectedly nil in locationManger(_:didUpdate)")
      return
    }
    self.mapView.mostRecentUserLocation = mostRecentLocation

    if let pendingRecenter = self.mapView.pendingRecenter {
      switch pendingRecenter {
      case .pending:
        self.mapView.pendingRecenter = .resolved(mostRecentLocation)
      case .resolved(_):
        self.mapView.pendingRecenter = .resolved(mostRecentLocation)
      }
    }
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

func bounds(_ bounds: Bounds) -> MLNCoordinateBounds {
  MLNCoordinateBounds(sw: bounds.min.asCoordinate, ne: bounds.max.asCoordinate)
}

func lineStyleLayer(source: MLNSource, id: UUID, isSelected: Bool) -> MLNLineStyleLayer {
  let styleLayer = MLNLineStyleLayer(identifier: "trip-route-\(id)", source: source)
  styleLayer.lineColor = NSExpression(forConstantValue: isSelected ? UIColor.blue : UIColor.gray)
  styleLayer.lineWidth = NSExpression(forConstantValue: NSNumber(value: 4))
  return styleLayer
}
