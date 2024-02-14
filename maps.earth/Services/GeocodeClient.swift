//
//  GeocodeClient.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import Foundation
import OSLog

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
  func autocomplete(text: String, focus: LngLat? = nil) async throws -> [Place] {
    let test = false
    if test {
      return FixtureData.places
    } else {
      let endpoint = "https://maps.earth/pelias/v1/autocomplete"
      var queryParams = ["text": text]
      if let focus = focus {
        queryParams["focus.point.lon"] = String(focus.lng)
        queryParams["focus.point.lat"] = String(focus.lat)
      }
      guard let url = buildURL(baseURL: endpoint, queryParams: queryParams) else {
        throw URLError(.badURL)
      }

      print("GET \(url)")
      let response = try await fetchData(from: url)
      return response.places
    }
  }

  private func fetchData(from url: URL) async throws -> AutocompleteResponse {
    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }

    let decodedResponse = try JSONDecoder().decode(AutocompleteResponse.self, from: data)
    return decodedResponse
  }

  private func buildURL(baseURL: String, queryParams: [String: String]) -> URL? {
    var components = URLComponents(string: baseURL)

    components?.queryItems = queryParams.map { key, value in
      URLQueryItem(name: key, value: value)
    }

    return components?.url
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
