//
//  DirectionsService.swift
//  maps.earth
//
//  Created by Michael Kirk on 5/20/24.
//

import MapboxCoreNavigation
import MapboxDirections
import MapboxDirectionsObjc

struct DirectionsService {
  var mlnDirections: Directions {
    Env.current.mlnDirections
  }
  enum DirectionsError: Error {
    case noneFound
  }

  func routes(from: Place, to: Place, mode: TravelMode, transitWithBike: Bool) async throws
    -> [Route]
  {
    let options = routeOptions(from: from, to: to, mode: mode, transitWithBike: transitWithBike)

    print(
      "[\(type(of:self))] Calculating directions with URL: \(mlnDirections.url(forCalculating: options))"
    )

    return try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<[Route], any Error>) in
      self.mlnDirections.calculate(options) {
        (waypoints: [Waypoint]?, routes: [Route]?, error: NSError?) -> Void in
        if let error = error {
          return continuation.resume(throwing: error)
        }

        guard let routes = routes else {
          assertionFailure("routes was unexpectedly nil")
          return continuation.resume(throwing: DirectionsError.noneFound)
        }

        continuation.resume(returning: routes)
      }
    }
  }

  /// - Parameters:
  ///   - tripIdx: Try to match this trip. This is a hack. We have a trips API and a Directions API.
  ///                    In theory they should correspond to the same Route, but the API formats are different.
  func route(from: Place, to: Place, mode: TravelMode, transitWithBike: Bool, tripIdx: Int)
    async throws -> Route
  {
    let routes = try await self.routes(
      from: from, to: to, mode: mode, transitWithBike: transitWithBike)

    guard let route = routes[getOrNil: tripIdx] else {
      assertionFailure("route at idx was unexpectedly nil")
      guard let firstRoute = routes.first else {
        throw DirectionsError.noneFound
      }
      return firstRoute
    }

    return route
  }

  private func routeOptions(from: Place, to: Place, mode: TravelMode, transitWithBike: Bool)
    -> RouteOptions
  {
    let waypoints = [from, to].map { Waypoint(location: $0.location.asCLLocation) }

    let options: RouteOptions
    let profileIdentifier = mode.asMBDirectionsProfileIdentifier
    if mlnDirections == Env.current.travelmuxDirectionsService {
      var modes = [mode]
      if transitWithBike {
        assert(mode == .transit)
        modes.append(.bike)
      }
      let travelmuxOptions = TravelmuxNavigationRouteOptions(
        waypoints: waypoints, profileIdentifier: profileIdentifier)
      travelmuxOptions.modes = modes
      options = travelmuxOptions
    } else if mlnDirections == Env.current.valhallaDirectionsService {
      options = ValhallaNavigationRouteOptions(
        waypoints: waypoints, profileIdentifier: profileIdentifier)
    } else if mlnDirections == Env.current.mapboxDirectionsService {
      options = NavigationRouteOptions(waypoints: waypoints, profileIdentifier: profileIdentifier)
    } else {
      fatalError("unknown directions service: \(String(describing: mlnDirections))")
    }
    options.shapeFormat = .polyline6
    options.attributeOptions = []

    return options
  }
}

extension TravelMode {
  var asMBDirectionsProfileIdentifier: MBDirectionsProfileIdentifier {
    switch self {
    case .bike:
      return MBDirectionsProfileIdentifier.cycling
    case .car:
      return MBDirectionsProfileIdentifier.automobile
    case .walk:
      return MBDirectionsProfileIdentifier.walking
    case .transit:
      assertionFailure("MBDirections not supported for transit")
      return MBDirectionsProfileIdentifier.walking
    }
  }
}

class ValhallaNavigationRouteOptions: NavigationRouteOptions {
  override var path: String {
    AppConfig().valhallaEndpoint.path()
  }

  open override var params: [URLQueryItem] {
    let from = LngLat(coord: self.waypoints[0].coordinate)
    let to = LngLat(coord: self.waypoints[1].coordinate)

    let mode: String
    switch self.profileIdentifier {
    case .automobile, .automobileAvoidingTraffic:
      mode = "auto"
    case .cycling:
      mode = "bicycle"
    case .walking:
      mode = "pedestrian"
    default:
      assertionFailure("unexpected mode")
      mode = "auto"
    }

    let units =
      switch self.distanceMeasurementSystem {
      case .imperial:
        DistanceUnit.miles
      case .metric:
        DistanceUnit.kilometers
      }

    struct ValhallaParams: Codable {
      struct LatLon: Codable {
        let lat: Double
        let lon: Double
        init(lngLat: LngLat) {
          lat = lngLat.lat
          lon = lngLat.lng
        }
      }

      let locations: [LatLon]
      let costing: String
      let units: DistanceUnit
      let format: String
      let banner_instructions: Bool
      let voice_instructions: Bool
    }

    // `voice_instructions` false for now - it's crashing due to a missing non-optional (in Swift, anway) `ssml` field
    // let ssmlText = json["ssmlAnnouncement"] as! String
    let valhallaParams = ValhallaParams(
      locations: [.init(lngLat: from), .init(lngLat: to)],
      costing: mode,
      units: units,
      format: "osrm",
      banner_instructions: true,
      voice_instructions: false
    )
    let jsonParams = String(bytes: try! JSONEncoder().encode(valhallaParams), encoding: .utf8)!
    // print("jsonParams: \(jsonParams)")

    var params: [URLQueryItem] = []
    params.append(URLQueryItem(name: "json", value: jsonParams))

    return params
  }
}

class TravelmuxNavigationRouteOptions: NavigationRouteOptions {
  override var path: String {
    AppConfig().travelmuxEndpoint.replacingLastPathComponent(with: "directions").path()
  }

  var modes: [TravelMode] = []

  open override var params: [URLQueryItem] {
    assert(!modes.isEmpty)

    let from = LngLat(coord: self.waypoints[0].coordinate)
    let to = LngLat(coord: self.waypoints[1].coordinate)

    let params = TripPlanClient.RealClient.queryParams(
      from: from, to: to, modes: self.modes, measurementSystem: self.distanceMeasurementSystem)
    return params
  }

  override func copy(with zone: NSZone? = nil) -> Any {
    let options = super.copy(with: zone) as! TravelmuxNavigationRouteOptions
    options.modes = self.modes
    return options
  }
}

extension URL {
  func replacingLastPathComponent(with newComponent: String) -> URL {
    var url = self.deletingLastPathComponent()
    url.append(path: newComponent, directoryHint: .notDirectory)
    return url
  }
}
