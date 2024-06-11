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
  var bbox: BBox?
  var lng: Float64 {
    location.lng
  }
  var lat: Float64 {
    location.lat
  }
  var properties: PlaceProperties
}

extension Place {
  init(currentLocation: CLLocation) {
    let location = LngLat(coord: currentLocation.coordinate)
    let properties = PlaceProperties(
      gid: "current-location-\(currentLocation)", name: "Current Location",
      label: "Current Location")
    self.init(location: location, properties: properties)
  }

  init(location: CLLocation) {
    let lngLat = LngLat(coord: location.coordinate)
    let name = location.coordinate.formattedString(includeCardinalDirections: true)
    let properties = PlaceProperties(
      gid: "location-\(location.coordinate)", name: name, label: name)
    self.init(location: lngLat, properties: properties)
  }
}

enum PlaceID: Equatable, Hashable {
  case venue(gid: String)
  case lngLat(LngLat)

  init?(pathComponents: inout IndexingIterator<[String]>) {
    guard let firstComponent = pathComponents.next() else {
      assertionFailure("expected at least one path component for PathID")
      return nil
    }

    if firstComponent == "_" {
      return nil
    }

    let coords = firstComponent.split(separator: ",")
    if coords.count == 2 {
      // Looks like LngLat
      guard let lng = Double(coords[0]),
        let lat = Double(coords[1])
      else {
        assertionFailure(
          "comma separated pathComponent was expected to be LngLat, but it was not parsable as one: \(firstComponent)"
        )
        return nil
      }
      self = .lngLat(LngLat(lng: lng, lat: lat))
    } else {
      self = .venue(gid: firstComponent)
    }
  }

  init(string: String) {
    let components = string.split(separator: ",")
    if components.count == 2,
      let lat = Double(components[0]),
      let lng = Double(components[1])
    {
      self = .lngLat(LngLat(lng: lng, lat: lat))
      return
    } else {
      assert(string.filter { $0 == "/" }.count <= 1)
      self = .venue(gid: string)
    }
  }

  var serialized: String {
    switch self {
    case .venue(let gid):
      return gid
    case .lngLat(let lngLat):
      return "\(lngLat.lng),\(lngLat.lat)"
    }
  }
}

extension Place: Identifiable {
  var id: PlaceID {
    PlaceID(string: self.properties.gid)
  }
}

extension Place {
  var gid: String { self.properties.gid }
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
  //  var id: String
  var gid: String
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
  var layer: String?
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
    case bbox
  }

  init(from decoder: Decoder) throws {
    let featureContainer = try decoder.container(keyedBy: FeatureCodingKeys.self)
    self.bbox = try featureContainer.decodeIfPresent(BBox.self, forKey: .bbox)
    self.location = try featureContainer.decode(LngLat.self, forKey: .geometry)
    self.properties = try featureContainer.decode(PlaceProperties.self, forKey: .properties)
  }
}

extension CLLocationCoordinate2D {
  func formattedString(includeCardinalDirections: Bool = false) -> String {
    let latitudeDegrees = fabs(latitude)
    let latitudeDirection = latitude >= 0 ? "N" : "S"

    let longitudeDegrees = fabs(longitude)
    let longitudeDirection = longitude >= 0 ? "E" : "W"

    if includeCardinalDirections {
      return String(
        format: "%.6f° %@, %.6f° %@", latitudeDegrees, latitudeDirection, longitudeDegrees,
        longitudeDirection)
    } else {
      return String(format: "%.6f°, %.6f°", latitudeDegrees, longitudeDegrees)
    }
  }
}
