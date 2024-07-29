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
struct TripLegId: Equatable {
  let tripId: UUID
  let legIdx: Int
  let isSelected: Bool
  var asString: String {
    "trip-route-\(tripId)-leg-\(legIdx)-\(isSelected ? "selected" : "unselected")"
  }
  static let pattern =
    "trip-route-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-leg-(\\d+)-(selected|unselected)"
  static let regex = try! NSRegularExpression(pattern: Self.pattern)
  struct ParseError: Error {}
}

extension TripLegId {
  init(string: String) throws {
    guard
      let match = Self.regex.firstMatch(
        in: string, range: NSRange(string.startIndex..., in: string))
    else {
      throw Self.ParseError()
    }

    guard let tripId = UUID(uuidString: (string as NSString).substring(with: match.range(at: 1)))
    else {
      throw Self.ParseError()
    }
    self.tripId = tripId

    guard let legIdx = Int((string as NSString).substring(with: match.range(at: 2))) else {
      throw Self.ParseError()
    }
    self.legIdx = legIdx

    switch (string as NSString).substring(with: match.range(at: 3)) {
    case "selected":
      self.isSelected = true
    case "unselected":
      self.isSelected = false
    default:
      throw Self.ParseError()
    }
  }
}

struct MapTrip: MapContent {
  let trip: Trip
  let isSelected: Bool

  struct TripLayers {
    struct LegLayer {
      let identifier: TripLegId
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
        let identifier = TripLegId(tripId: trip.id, legIdx: idx, isSelected: isSelected)
        let polyline = polylineFeature(coordinates: leg.geometry, identifier: identifier)

        // We want to style each leg independently, so we can style the dashed line for walking.
        // It's also sufficient for styling routeColor (once we support that)
        // But it ends up being a lot of source/layers. Rather than a source/layer for *each* leg of the trip,
        // maybe we can put in the whole trip (or all the trips?!) and use a runtime MGLVectorStyleeLayer.predicate
        // to filter out the subset of features we want to style as dashed.
        // Or maybe we can figure out why MGL doesn't support "data properties" for dynamic line type styling.
        let source = MLNShapeSource(
          identifier: identifier.asString, features: [polyline], options: nil)

        let styleLayer = lineStyleLayer(
          source: source, identifier: identifier, leg: leg, isSelected: isSelected)
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
    AssertMainThread()
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

    // Insert the route line behind the symbol layer to keep the routes below the "end" markers and street labels
    let firstSymbolLayer = style.firstSymbolLayer

    for legLayer in tripLayers.legLayers {
      style.addSource(legLayer.source)
      if let firstSymbolLayer {
        style.insertLayer(legLayer.styleLayer, below: firstSymbolLayer)
      } else {
        assertionFailure("couldn't find firstSymbolLayer layer. Did maplibre change their API?")
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
      // this errors in the canvas preview
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
    AssertMainThread()
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
    AssertMainThread()
    Self.markerLookup[self.annotation] = self
    mapView.addAnnotation(self.annotation)
  }

  func remove(from mapView: MLNMapView) {
    //    print("Removing from map: \(self)")
    mapView.removeAnnotation(self.annotation)
    AssertMainThread()
    Self.markerLookup[self.annotation] = nil
    Self.annotations[self] = nil
  }
}

extension PlaceMarker: CustomDebugStringConvertible {
  var debugDescription: String {
    "MapPlace(\(self.place.name ?? "nil")\", lngLat: (\(self.place.lng), \(self.place.lat)))"
  }
}

func lineStyleLayer(
  source: MLNSource, identifier: TripLegId, leg: TripLeg, isSelected: Bool
)
  -> MLNLineStyleLayer
{
  let styleLayer = MLNLineStyleLayer(identifier: identifier.asString, source: source)
  styleLayer.lineWidth = NSExpression(forConstantValue: NSNumber(value: 4))
  styleLayer.lineColor = NSExpression(
    forConstantValue: UIColor(isSelected ? leg.activeLineColor : Color.hw_inactiveRoute))
  switch leg.mode {
  case .walk, .bike:
    styleLayer.lineDashPattern = NSExpression(forConstantValue: NSArray(array: [1, 1]))
  default:
    break
  }
  return styleLayer

}

func polylineFeature(coordinates: [CLLocationCoordinate2D], identifier: TripLegId)
  -> MLNPolylineFeature
{
  let feature = MLNPolylineFeature(coordinates: coordinates, count: UInt(coordinates.count))
  feature.identifier = identifier.asString
  return feature
}
