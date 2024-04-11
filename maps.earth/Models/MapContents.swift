//
//  MapContents.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/11/24.
//

import Foundation
import MapLibre
import SwiftUI

enum MapContents {
  case trips(selected: MapTrip, unselected: [MapTrip])
  case pins(selected: PlaceMarker?, unselected: [PlaceMarker])
  case empty

  struct Diff {
    let adds: [any MapContent]
    let removes: [any MapContent]
  }

  func diff(newContents: MapContents) -> Diff {
    var adds: [any MapContent]
    var removes: [any MapContent]

    switch self {
    case .trips(let oldSelected, let oldUnselected):
      switch newContents {
      case .trips(let newSelected, let newUnselected):
        adds = Array(Set(newUnselected).subtracting(oldUnselected))
        removes = Array(Set(oldUnselected).subtracting(newUnselected))
        // `newSelected` needs to be last to be on top
        if oldSelected != newSelected {
          adds.append(newSelected)
          removes.append(oldSelected)
        }
      case .pins(let newSelected, let newUnselected):
        let newPins: [PlaceMarker]
        if let newSelected = newSelected {
          newPins = [newSelected]
        } else {
          newPins = newUnselected
        }
        adds = newPins
        removes = [oldSelected] + oldUnselected
      case .empty:
        adds = []
        removes = [oldSelected] + oldUnselected
      }
    case .pins(let oldSelected, let oldUnselected):
      let oldPins: [PlaceMarker]
      if let oldSelected = oldSelected {
        oldPins = [oldSelected]
      } else {
        oldPins = oldUnselected
      }
      switch newContents {
      case .trips(let newSelected, let newUnselected):
        removes = oldPins
        // `selected` needs to be last to be on top
        adds = newUnselected + [newSelected]
      case .pins(let newSelected, let newUnselected):
        let newPins: [PlaceMarker]
        if let newSelected = newSelected {
          newPins = [newSelected]
        } else {
          newPins = newUnselected
        }
        adds = Array(Set(newPins).subtracting(oldPins))
        removes = Array(Set(oldPins).subtracting(newPins))
      case .empty:
        removes = oldUnselected
        if let oldSelected = oldSelected {
          removes.append(oldSelected)
        }
        adds = []
      }
    case .empty:
      removes = []
      switch newContents {
      case .trips(let newSelected, let newUnselected):
        // `selected` needs to be last to be on top
        adds = newUnselected + [newSelected]
      case .pins(let newSelected, let newUnselected):
        if let newSelected = newSelected {
          adds = [newSelected]
        } else {
          adds = newUnselected
        }
      case .empty:
        adds = []
      }
    }
    return Diff(adds: adds, removes: removes)
  }
}

protocol MapContent: Equatable, Hashable {
  func add(to mapView: MLNMapView)
  func remove(from mapView: MLNMapView)
}

struct MapTrip: MapContent {
  let trip: Trip
  let isSelected: Bool

  struct TripLayers {
    struct LegLayer {
      let identifier: String
      let source: MLNShapeSource
      let styleLayer: MLNLineStyleLayer
    }
    let trip: Trip
    let isSelected: Bool
    let legLayers: [LegLayer]
    let markers: [PlaceMarker]

    init(trip: Trip, isSelected: Bool) {
      self.trip = trip
      self.isSelected = isSelected
      self.legLayers = trip.legs.enumerated().map { idx, leg in
        let polyline = polyline(coordinates: leg.geometry)
        let identifier =
          "trip-route-\(trip.id)-leg-\(idx)-\(isSelected ? "selected" : "unselected")"
        let source = MLNShapeSource(identifier: identifier, shapes: [polyline], options: nil)
        let styleLayer = lineStyleLayer(
          source: source, identifier: identifier, travelMode: leg.mode, isSelected: isSelected)
        return LegLayer(identifier: identifier, source: source, styleLayer: styleLayer)
      }
      var markers = trip.transferPlaces.map { transfer in
        let style =
          isSelected
          ? PlaceMarker.MarkerStyle.selectedTripTransfer
          : PlaceMarker.MarkerStyle.unselectedTripTransfer
        return PlaceMarker(place: transfer.intoMarkerLocation, style: style)
      }
      markers.append(PlaceMarker(place: trip.to.intoMarkerLocation, style: .pin))
      markers.append(PlaceMarker(place: trip.from.intoMarkerLocation, style: .start))
      self.markers = markers
    }
  }

  static var allTripLayers: [MapTrip: TripLayers] = [:]
  var tripLayers: TripLayers {
    dispatchPrecondition(condition: .onQueue(.main))
    if let annotation = Self.allTripLayers[self] {
      return annotation
    } else {
      let annotation = TripLayers(trip: trip, isSelected: isSelected)
      Self.allTripLayers[self] = annotation
      return annotation
    }
  }

  func add(to mapView: MLNMapView) {
    //    print("adding to map: \(self)")
    let tripLayers = self.tripLayers

    guard let style = mapView.style else {
      print("mapView.style was unexpectedly nil")
      return
    }

    // Insert the route line behind the annotation layer to keep the "end" markers above the routes.
    //     identifier = com.mapbox.annotations.points; sourceIdentifier = com.mapbox.annotations; sourceLayerIdentifier = com.mapbox.annotations.points
    let annotationLayer = style.layers.first(where: {
      $0.identifier == "com.mapbox.annotations.points"
    })

    for legLayer in tripLayers.legLayers {
      style.addSource(legLayer.source)
      if let annotationLayer = annotationLayer {
        style.insertLayer(legLayer.styleLayer, below: annotationLayer)
      } else {
        assertionFailure("couldn't find points layer. Did maplibre change their API?")
        style.addLayer(legLayer.styleLayer)
      }
    }
    for marker in tripLayers.markers {
      marker.add(to: mapView)
    }
  }

  func remove(from mapView: MLNMapView) {
    //    print("removing from map: \(self)")
    let tripLayers = self.tripLayers
    guard let style = mapView.style else {
      print("mapView.style was unexpectedly nil")
      return
    }
    for legLayer in tripLayers.legLayers {
      style.removeLayer(legLayer.styleLayer)
      try! style.removeSource(legLayer.source, error: ())
    }
    for marker in tripLayers.markers {
      marker.remove(from: mapView)
    }
  }
}

struct PlaceMarker: MapContent {
  let place: MarkerLocation
  let style: MarkerStyle

  enum MarkerStyle {
    case start
    case pin
    case selectedTripTransfer
    case unselectedTripTransfer
  }

  static var annotations: [PlaceMarker: MLNPointAnnotation] = [:]
  static var markerLookup: [MLNPointAnnotation: PlaceMarker] = [:]

  var annotation: MLNPointAnnotation {
    dispatchPrecondition(condition: .onQueue(.main))
    if let annotation = PlaceMarker.annotations[self] {
      return annotation
    } else {
      let annotation = MLNPointAnnotation()
      annotation.coordinate = self.place.location.asCoordinate
      PlaceMarker.annotations[self] = annotation
      return annotation
    }
  }

  func add(to mapView: MLNMapView) {
    //    print("Adding to map: \(self)")
    dispatchPrecondition(condition: .onQueue(.main))
    Self.markerLookup[self.annotation] = self
    mapView.addAnnotation(self.annotation)
  }

  func remove(from mapView: MLNMapView) {
    //    print("Removing from map: \(self)")
    mapView.removeAnnotation(self.annotation)
    dispatchPrecondition(condition: .onQueue(.main))
    Self.markerLookup[self.annotation] = nil
    Self.annotations[self] = nil
  }
}

extension PlaceMarker: CustomDebugStringConvertible {
  var debugDescription: String {
    "MapPlace(\(self.place.name ?? "nil")\", lngLat: (\(self.place.lng), \(self.place.lat)))"
  }
}

func lineStyleLayer(source: MLNSource, identifier: String, travelMode: TravelMode, isSelected: Bool)
  -> MLNLineStyleLayer
{
  let styleLayer = MLNLineStyleLayer(identifier: identifier, source: source)
  styleLayer.lineColor = NSExpression(
    forConstantValue: isSelected ? UIColor(Color.hw_activeRoute) : UIColor(Color.hw_inactiveRoute))
  styleLayer.lineWidth = NSExpression(forConstantValue: NSNumber(value: 4))

  switch travelMode {
  case .walk:
    styleLayer.lineDashPattern = NSExpression(forConstantValue: NSArray(array: [1, 1]))
  default:
    break
  }
  return styleLayer

}