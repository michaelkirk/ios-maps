//
//  SearchResultItem.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import CoreLocation
import Foundation
import PhoneNumberKit

let phoneNumberKit = PhoneNumberKit()

struct Place: Equatable, Hashable {
  var location: LngLat
  var properties: PlaceProperties
}

extension Place {
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
  var region: String? { self.properties.region }
  // matches weird spelling in api response
  var postalcode: String? { self.properties.postalcode }
  // This might be broken due to camelCase vs snake_case
  var countryCode: String? { self.properties.countryCode }
  var country: String? { self.properties.country }

  var websiteURL: URL? {
    guard let urlString = self.properties.addendum?.osm?.website else {
      return nil
    }
    return URL(string: urlString)
  }

  var phoneNumber: PhoneNumber? {
    guard let rawPhone = self.properties.addendum?.osm?.phone else {
      return nil
    }
    do {
      return try? phoneNumberKit.parse(rawPhone)
    }

  }
  var openingHours: String? { self.properties.addendum?.osm?.openingHours }
}

struct PlaceProperties: Codable, Equatable, Hashable {
  var id: String
  var name: String
  var label: String
  var address: String?
  // matches weird spelling in api response
  var housenumber: String?
  var street: String?
  var locality: String?
  var region: String?
  // matches weird spelling in api response
  var postalcode: String?
  var countryCode: String?
  var addendum: Addendum?
  var country: String?
}

struct Addendum: Codable, Equatable, Hashable {
  var osm: OSMAddendum?
}

struct OSMAddendum: Codable, Equatable, Hashable {
  var website: String?
  var phone: String?
  var openingHours: String?
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
