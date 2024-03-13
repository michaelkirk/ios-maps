//
//  SearchResultItem.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import CoreLocation
import Foundation

struct Place: Equatable, Hashable {
  var location: LngLat
  var properties: PlaceProperties

  init(location: LngLat, properties: PlaceProperties) {
    self.location = location
    self.properties = properties
  }

  init(currentLocation: CLLocation) {
    let location = LngLat(coord: currentLocation.coordinate)
    let properties = PlaceProperties(
      id: "current-location", name: "Current Location", label: "Current Location")
    self.init(location: location, properties: properties)
  }
}

extension Place: Identifiable {
  var id: String { self.properties.id }
}

extension Place {
  var name: String { self.properties.name }
  var label: String { self.properties.label }
  // matches weird spelling in api response
  var housenumber: String? { self.properties.housenumber }
  var street: String? { self.properties.street }
  var locality: String? { self.properties.locality }
  var state: String? { self.properties.state }
  var postalCode: String? { self.properties.postalCode }
  var countryCode: String? { self.properties.countryCode }
}

struct PlaceProperties: Codable, Equatable, Hashable {
  var id: String
  var name: String
  var label: String
  // matches weird spelling in api response
  var housenumber: String?
  var street: String?
  var locality: String?
  var state: String?
  var postalCode: String?
  var countryCode: String?
}

extension Place: Decodable {
  private enum FeatureCodingKeys: String, CodingKey {
    case geometry
    case properties
  }

  init(from decoder: Decoder) throws {
    let featureContainer = try decoder.container(keyedBy: FeatureCodingKeys.self)
    self.location = try featureContainer.decode(LngLat.self, forKey: .geometry)
    self.properties = try featureContainer.decode(PlaceProperties.self, forKey: .properties)
  }
}
