//
//  MapView.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import MapLibre
import SwiftUI

protocol MapViewDelegate: NSObject {
  func mapView(mapView: MLNMapView, didSelect place: Place)
}

struct MapView: UIViewRepresentable {

  var places: [Place]
  @Binding var selectedPlace: Place?

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIView(context: Context) -> MLNMapView {
    let styleURL = URL(string: "https://maps.earth/tileserver/styles/basic/style.json")

    // create the mapview
    let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
    mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    mapView.logoView.isHidden = true
    mapView.setCenter(
      CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3),
      zoomLevel: 10,
      animated: false)

    mapView.delegate = context.coordinator

    // TODO: It seems like this should be some delegate/coordinate thing,
    // rather than in the initializer.
    for place in places {
      let addedMarker = self.addMarker(to: mapView, at: place.location)
      context.coordinator.markers[place] = addedMarker
    }

    return mapView
  }

  func updateUIView(_ mapView: MLNMapView, context: Context) {
    print("in updateUIView MapView")
    // TODO: this is overzealous. We only want to do this when the selection changes
    // not whenever the view gets updated. Perhaps other thing scould cause the view to update,
    // and we don't necessarily want to move the users map around.
    if let place = selectedPlace {
      context.coordinator.zoom(mapView: mapView, toPlace: place, animated: true)
    } else {
      // TODO: zoom out
    }
  }

  func addMarker(to mapView: MLNMapView, at lngLat: LngLat) -> MLNAnnotation {
    let marker = MLNPointAnnotation()
    marker.coordinate = CLLocationCoordinate2D(latitude: lngLat.lat, longitude: lngLat.lng)
    mapView.addAnnotation(marker)
    return marker
  }

  typealias UIViewType = MLNMapView

  class Coordinator: NSObject {
    let mapView: MapView
    var markers: [Place: MLNAnnotation] = [:]

    init(_ mapView: MapView) {
      self.mapView = mapView
    }

    func zoom(mapView: MLNMapView, toPlace place: Place, animated isAnimated: Bool) {
      let minZoom = 12.0
      let zoom = max(mapView.zoomLevel, minZoom)
      mapView.setCenter(place.location.asCoordinate, zoomLevel: zoom, animated: isAnimated)
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
    print("clicked marker for \(place)")

    self.zoom(mapView: mapView, toPlace: place, animated: true)
    self.mapView.selectedPlace = place
  }
}
