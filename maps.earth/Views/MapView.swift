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
      context.coordinator.ensureRoutes(in: mapView, for: [selectedTrip], selected: selectedTrip)
      // TODO: Avoid unwrap - maybe package non-optional query with tripPlan results
      context.coordinator.ensureStartMarkers(in: mapView, places: [selectedTrip.from])
      context.coordinator.ensureMarkers(in: mapView, places: [selectedTrip.to])
    } else {
      context.coordinator.ensureRoutes(in: mapView, for: [], selected: nil)
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
    var trips: [Trip: [MLNOverlay]] = [:]

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
          self.markers[place] = Self.addMarker(to: mapView, at: place.location)
        }
      }

      let stale = Set(self.markers.keys).subtracting(places)
      for place in stale {
        guard let marker = self.markers.removeValue(forKey: place) else {
          print("unexpectely missing stale marker")
          continue
        }
        // PERF: more efficient to do this all at once with `removeAnnotations`?
        mapView.removeAnnotation(marker)
      }
    }

    func ensureStartMarkers(in mapView: MLNMapView, places: [Place]) {
      for place in places {
        if self.startMarkers[place] == nil {
          self.startMarkers[place] = Self.addStartMarker(to: mapView, at: place.location)
        }
      }

      let stale = Set(self.startMarkers.keys).subtracting(places)
      for place in stale {
        guard let marker = self.startMarkers.removeValue(forKey: place) else {
          print("unexpectely missing stale marker")
          continue
        }
        // PERF: more efficient to do this all at once with `removeAnnotations`?
        mapView.removeAnnotation(marker)
      }
    }

    func ensureRoutes(in mapView: MLNMapView, for trips: [Trip], selected selectedTrip: Trip?) {
      for trip in trips {
        if self.trips[trip] == nil {
          self.trips[trip] = Self.addRoute(to: mapView, trip: trip)
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

      let stale = Set(self.trips.keys).subtracting(trips)
      for trip in stale {
        guard let tripOverlays = self.trips.removeValue(forKey: trip) else {
          print("unexpectely missing stale tripOverlays")
          continue
        }
        mapView.removeOverlays(tripOverlays)
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

    static func addRoute(to mapView: MLNMapView, trip: Trip) -> [MLNOverlay] {
      let polylines: [MLNPolyline] = trip.legs.map {
        polyline(coordinates: $0.geometry)
      }
      mapView.addOverlays(polylines)
      return polylines
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

func polyline(coordinates: [CLLocationCoordinate2D]) -> MLNPolyline {
  MLNPolyline(coordinates: coordinates, count: UInt(coordinates.count))
}

func bounds(_ bounds: Bounds) -> MLNCoordinateBounds {
  MLNCoordinateBounds(sw: bounds.min.asCoordinate, ne: bounds.max.asCoordinate)
}
