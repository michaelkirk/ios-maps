//
//  GeocodeClient.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import Foundation
import OSLog

//
//struct GeoJson {
//    private enum RootCodingKeys: String, CodingKey {
//         case features
//     }
//
//     private enum FeatureCodingKeys: String, CodingKey {
//         case properties
//     }
//
//    private(set) var places: [Place] = []
//
//    init(from decoder: Decoder) throws {
//      let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
//        var featuresContainer = try rootContainer.nestedUnkeyedContainer(forKey: .features)
//
//        while !featuresContainer.isAtEnd {
//            let propertiesContainer = try featuresContainer.nestedContainer(keyedBy: FeatureCodingKeys.self)
//
//            if let properties = try? propertiesContainer.decode(Place.self, forKey: .properties) {
//                places.append(properties)
//            }
//        }
//    }
//}

struct GeocodeClient {
  func autocomplete(text: String) throws -> [Place] {
    fatalError("todo")
  }
}

struct BBox: Codable {
  var top: Float64
  var right: Float64
  var bottom: Float64
  var left: Float64

  // Decode from an array format
  init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    self.top = try container.decode(Float64.self)
    self.right = try container.decode(Float64.self)
    self.bottom = try container.decode(Float64.self)
    self.left = try container.decode(Float64.self)
  }

  // Encode to an array format
  func encode(to encoder: Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(top)
    try container.encode(right)
    try container.encode(bottom)
    try container.encode(left)
  }
}

struct AutocompleteResponse: Decodable {
  var bbox: BBox?
  private(set) var places: [Place] = []

  private enum FeatureCollectionCodingKeys: String, CodingKey {
    case bbox
    case features
  }

  init(from decoder: Decoder) throws {
    let featureCollectionContainer = try decoder.container(
      keyedBy: FeatureCollectionCodingKeys.self)
    self.bbox = try featureCollectionContainer.decodeIfPresent(BBox.self, forKey: .bbox)
    var featuresContainer = try featureCollectionContainer.nestedUnkeyedContainer(forKey: .features)

    while !featuresContainer.isAtEnd {
      let place = try featuresContainer.decode(Place.self)
      places.append(place)
    }
  }
}
