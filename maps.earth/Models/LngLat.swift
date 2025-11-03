//
//  LngLat.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import CoreLocation
import Foundation

/// GeoJSON point decodable
struct LngLat: Hashable, Equatable {
  var lng: Float64
  var lat: Float64
  var asCoordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: lat, longitude: lng)
  }
  var asCLLocation: CLLocation {
    CLLocation(latitude: self.lat, longitude: self.lng)
  }
}

extension LngLat: Decodable {
  private enum GeometryKeys: String, CodingKey {
    case type
    case coordinates
  }

  enum GeometryType: String, Codable {
    case point = "Point"
  }

  init(coord: CLLocationCoordinate2D) {
    self.init(lng: coord.longitude, lat: coord.latitude)
  }

  init(from decoder: Decoder) throws {
    let geometryContainer = try decoder.container(keyedBy: GeometryKeys.self)
    // TODO: handle non point geometries - for now we're just verifying it's
    // the type we expect
    let _ = try geometryContainer.decode(GeometryType.self, forKey: .type)

    var coordinatesContainer = try geometryContainer.nestedUnkeyedContainer(forKey: .coordinates)
    self.lng = try coordinatesContainer.decode(Float64.self)
    self.lat = try coordinatesContainer.decode(Float64.self)
  }
}
