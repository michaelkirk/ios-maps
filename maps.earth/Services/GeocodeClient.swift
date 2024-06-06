//
//  GeocodeClient.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import Foundation

struct GeocodeClient {
  enum Endpoint {
    var config: AppConfig {
      AppConfig()
    }

    case autocomplete(text: String, focus: LngLat?)
    case place(PlaceID)

    var url: URL {
      let baseURL = config.peliasEndpoint.appendingPathComponent(self.path)
      var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
      components.queryItems = queryItems
      return components.url!
    }

    var path: String {
      switch self {
      case .autocomplete:
        return "autocomplete"
      case .place(.venue):
        return "place"
      case .place(.lngLat):
        return "reverse"
      }
    }

    var queryItems: [URLQueryItem]? {
      switch self {
      case .autocomplete(let text, let focus):
        var queryParams = [URLQueryItem(name: "text", value: text)]
        if let focus = focus {
          queryParams.append(URLQueryItem(name: "focus.point.lon", value: String(focus.lng)))
          queryParams.append(URLQueryItem(name: "focus.point.lat", value: String(focus.lat)))
        }
        return queryParams
      case .place(let placeId):
        switch placeId {
        case .venue:
          return [URLQueryItem(name: "ids", value: placeId.serialized)]
        case .lngLat(let lngLat):
          return [
            URLQueryItem(name: "point.lat", value: String(lngLat.lat)),
            URLQueryItem(name: "point.lon", value: String(lngLat.lng)),
            URLQueryItem(name: "boundary.circle.radius", value: "0.1"),
            URLQueryItem(name: "sources", value: "osm"),
          ]
        }
      }
    }
  }

  func autocomplete(text: String, focus: LngLat? = nil) async throws -> [Place] {
    assert(focus != nil, "missing focus. env set up?")
    let endpoint = Endpoint.autocomplete(text: text, focus: focus)
    let response = try await fetchData(from: endpoint.url)
    return response.places
  }

  func details(placeID: PlaceID) async throws -> Place? {
    let endpoint = Endpoint.place(placeID)
    let response = try await fetchData(from: endpoint.url)
    if case .venue = placeID {
      assert(response.places.count == 1)
    }
    guard
      let place = response.places.first(where: { $0.properties.layer == "venue" })
        ?? response.places.first
    else {
      assertionFailure("places.first was unexpectedly nil")
      return nil
    }
    return place
  }

  private func fetchData(from url: URL) async throws -> AutocompleteResponse {
    print("GET \(url)")

    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }

    let decodedResponse = try JSONDecoder().decode(AutocompleteResponse.self, from: data)
    return decodedResponse
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

struct PlaceResponse: Decodable {
  var bbox: BBox?
  private(set) var places: [Place] = []

  private enum CodingKeys: String, CodingKey {
    case bbox
    case features
  }

  init(from decoder: Decoder) throws {
    let featureCollectionContainer = try decoder.container(
      keyedBy: CodingKeys.self)
    self.bbox = try featureCollectionContainer.decodeIfPresent(BBox.self, forKey: .bbox)
    var featuresContainer = try featureCollectionContainer.nestedUnkeyedContainer(forKey: .features)

    while !featuresContainer.isAtEnd {
      let place = try featuresContainer.decode(Place.self)
      places.append(place)
    }
  }
}

typealias AutocompleteResponse = PlaceResponse
