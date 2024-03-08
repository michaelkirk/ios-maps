//
//  MapView.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import Foundation
import MapLibre
import SwiftUI

protocol MapViewDelegate: NSObject {
  func mapView(mapView: MLNMapView, didSelect place: Place)
}

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
    if let places = self.places {
      context.coordinator.ensureMarkers(in: mapView, for: places)
      if let selectedTrip = self.tripPlan.selectedTrip {
        context.coordinator.ensureRoutes(in: mapView, for: [selectedTrip])
      } else {
        context.coordinator.ensureRoutes(in: mapView, for: [])
      }
    }
    // TODO: this is overzealous. We only want to do this when the selection changes
    // not whenever the view gets updated. Perhaps other thing scould cause the view to update,
    // and we don't necessarily want to move the users map around.
    if let place = selectedPlace {
      context.coordinator.zoom(mapView: mapView, toPlace: place, animated: true)
    } else {
      // TODO: zoom out
    }
  }

  typealias UIViewType = MLNMapView

  class Coordinator: NSObject {
    let mapView: MapView
    var markers: [Place: MLNAnnotation] = [:]
    var trips: [Trip: [MLNOverlay]] = [:]

    init(_ mapView: MapView) {
      self.mapView = mapView
    }

    func zoom(mapView: MLNMapView, toPlace place: Place, animated isAnimated: Bool) {
      let minZoom = 12.0
      let zoom = max(mapView.zoomLevel, minZoom)
      mapView.setCenter(place.location.asCoordinate, zoomLevel: zoom, animated: isAnimated)
    }

    func ensureMarkers(in mapView: MLNMapView, for places: [Place]) {
      for place in places {
        if self.markers[place] == nil {
          self.markers[place] = Self.addMarker(to: mapView, at: place.location)
        }
      }

      let stale = Set(self.markers.keys).subtracting(places)
      for place in stale {
        guard let marker = self.markers[place] else {
          print("unexpectely missing stale marker")
          continue
        }
        print("removing stale marker for \(place)")
        // PERF: more efficient to do this all at once?
        mapView.removeAnnotation(marker)
      }
    }

    func ensureRoutes(in mapView: MLNMapView, for trips: [Trip]) {
      for trip in trips {
        if self.trips[trip] == nil {
          self.trips[trip] = Self.addRoute(to: mapView, trip: trip)
        }
      }

      let stale = Set(self.trips.keys).subtracting(trips)
      for trip in stale {
        guard let tripOverlays = self.trips[trip] else {
          print("unexpectely missing stale marker")
          continue
        }
        print("removing stale marker for \(trip)")
        // TODO is this the right method?
        mapView.removeOverlays(tripOverlays)
      }
    }

    static func addMarker(to mapView: MLNMapView, at lngLat: LngLat) -> MLNAnnotation {
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

    self.zoom(mapView: mapView, toPlace: place, animated: true)
    self.mapView.selectedPlace = place
  }
}

func polyline(coordinates: [CLLocationCoordinate2D]) -> MLNPolyline {
  MLNPolyline(coordinates: coordinates, count: UInt(coordinates.count))
}
