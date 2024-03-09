//
//  MapView.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import Foundation
import MapLibre
import SwiftUI

struct MapView: UIViewRepresentable {

  @Binding var places: [Place]?
  @Binding var selectedPlace: Place?
  @Binding var mapView: MLNMapView?
  @ObservedObject var tripPlan: TripPlan

  //  @Binding var selectedTrip: Trip?

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIView(context: Context) -> MLNMapView {
    let styleURL = AppConfig().tileserverStyleUrl

    // create the mapview
    let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
    mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    mapView.logoView.isHidden = true
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
    print("in updateUIView MapView")
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
        context.coordinator.zoom(mapView: mapView, toPlace: selectedPlace, animated: true)
      } else if let places = self.places {
        context.coordinator.ensureMarkers(in: mapView, places: places)
        // TODO zoom to search results bbox
      }
    }
  }

  typealias UIViewType = MLNMapView

  class Coordinator: NSObject {
    let mapView: MapView
    // pin markers, like those used in search or at the end of a trip
    var markers: [Place: MLNAnnotation] = [:]
    // circle markers, like those used at the start of a trip
    var startMarkers: [Place: MLNAnnotation] = [:]
    var selectedTrips: [Trip: (MLNShapeSource, MLNLineStyleLayer)] = [:]
    var unselectedTrips: [Trip: (MLNShapeSource, MLNLineStyleLayer)] = [:]

    init(_ mapView: MapView) {
      self.mapView = mapView
    }

    func zoom(mapView: MLNMapView, toPlace place: Place, animated isAnimated: Bool) {
      let minZoom = 12.0
      let zoom = max(mapView.zoomLevel, minZoom)
      mapView.setCenter(place.location.asCoordinate, zoomLevel: zoom, animated: isAnimated)
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
        // This padding is brittle. It should depend on how high the sheet is
        // and maybe whether there is a notch
        let padding = UIEdgeInsets(top: 70, left: 30, bottom: 70, right: 30)
        mapView.setVisibleCoordinateBounds(
          bounds, edgePadding: padding, animated: true, completionHandler: nil)
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
