//
//  MENavigationView.swift
//  maps.earth
//
//  Created by Michael Kirk on 8/30/24.
//

import FerrostarCore
import FerrostarCoreFFI
import FerrostarMapLibreUI
import FerrostarSwiftUI
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import MapboxDirections
import SwiftUI

extension FerrostarCoreFFI.Waypoint {
  init(mapboxWaypoint waypoint: MapboxDirections.Waypoint) {
    self.init(coordinate: .init(cl: waypoint.coordinate), kind: .break)
  }
}

extension FerrostarCoreFFI.ManeuverModifier {
  init?(mapboxManeuverDirection maneuverDirection: MapboxDirections.ManeuverDirection) {
    if case .none = maneuverDirection {
      return nil
    }

    self =
      switch maneuverDirection {
      case .none:
        fatalError("Shouldn't get here - already handled")
      case .sharpRight:
        FerrostarCoreFFI.ManeuverModifier.sharpRight
      case .right:
        FerrostarCoreFFI.ManeuverModifier.right
      case .slightRight:
        FerrostarCoreFFI.ManeuverModifier.slightRight
      case .straightAhead:
        FerrostarCoreFFI.ManeuverModifier.straight
      case .slightLeft:
        FerrostarCoreFFI.ManeuverModifier.slightLeft
      case .left:
        FerrostarCoreFFI.ManeuverModifier.left
      case .sharpLeft:
        FerrostarCoreFFI.ManeuverModifier.sharpLeft
      case .uTurn:
        FerrostarCoreFFI.ManeuverModifier.uTurn
      }
  }
}

extension FerrostarCoreFFI.ManeuverType {
  init(mapboxManeuverType maneuverType: MapboxDirections.ManeuverType) {
    self =
      switch maneuverType {
      case .none:
        // REVIEW
        fatalError("unimplemented 'none'")
      case .depart:
        FerrostarCoreFFI.ManeuverType.depart
      case .turn:
        FerrostarCoreFFI.ManeuverType.turn
      case .continue:
        FerrostarCoreFFI.ManeuverType.continue
      case .passNameChange:
        FerrostarCoreFFI.ManeuverType.newName
      case .merge:
        FerrostarCoreFFI.ManeuverType.merge
      case .takeOnRamp:
        FerrostarCoreFFI.ManeuverType.onRamp
      case .takeOffRamp:
        FerrostarCoreFFI.ManeuverType.offRamp
      case .reachFork:
        FerrostarCoreFFI.ManeuverType.fork
      case .reachEnd:
        FerrostarCoreFFI.ManeuverType.endOfRoad
      case .useLane:
        // TODO
        fatalError("unimplemented 'useLane'")
      case .takeRoundabout:
        FerrostarCoreFFI.ManeuverType.roundabout
      case .takeRotary:
        FerrostarCoreFFI.ManeuverType.rotary
      case .turnAtRoundabout:
        FerrostarCoreFFI.ManeuverType.roundaboutTurn
      case .exitRoundabout:
        FerrostarCoreFFI.ManeuverType.exitRoundabout
      case .exitRotary:
        FerrostarCoreFFI.ManeuverType.exitRotary
      case .heedWarning:
        FerrostarCoreFFI.ManeuverType.notification
      case .arrive:
        FerrostarCoreFFI.ManeuverType.arrive
      case .passWaypoint:
        // TODO
        fatalError("unimplemented 'passWaypoint'")
      }
  }

}

extension FerrostarCoreFFI.VisualInstructionContent {
  init(mapboxVisualInstruction visualInstruction: MapboxDirections.VisualInstruction) {
    let maneuverType = FerrostarCoreFFI.ManeuverType(
      mapboxManeuverType: visualInstruction.maneuverType)
    let maneuverModifier = FerrostarCoreFFI.ManeuverModifier(
      mapboxManeuverDirection: visualInstruction.maneuverDirection)

    // TODO:
    let roundaboutExitDegrees: UInt16? = nil

    self.init(
      text: visualInstruction.text ?? "TODO: missing text", maneuverType: maneuverType,
      maneuverModifier: maneuverModifier, roundaboutExitDegrees: roundaboutExitDegrees)
  }
}

extension FerrostarCoreFFI.VisualInstruction {
  init(
    mapboxVisualInstructionBanner visualInstructionBanner: MapboxDirections.VisualInstructionBanner
  ) {
    let primaryContent = FerrostarCoreFFI.VisualInstructionContent(
      mapboxVisualInstruction: visualInstructionBanner.primaryInstruction)
    let secondaryContent = visualInstructionBanner.secondaryInstruction.map {
      secondaryInstruction in
      FerrostarCoreFFI.VisualInstructionContent(mapboxVisualInstruction: secondaryInstruction)
    }

    // TODO:
    let triggerDistanceBeforeManeuver: Double = 100

    self.init(
      primaryContent: primaryContent, secondaryContent: secondaryContent,
      triggerDistanceBeforeManeuver: triggerDistanceBeforeManeuver)
  }
}

extension FerrostarCoreFFI.RouteStep {
  init(mapboxRouteStep routeStep: MapboxDirections.RouteStep) {
    let geometry: [GeographicCoordinate] = routeStep.coordinates!.map {
      GeographicCoordinate(lat: $0.latitude, lng: $0.longitude)
    }

    // REVIEW: unwrap
    let visualInstructions: [FerrostarCoreFFI.VisualInstruction] = routeStep
      .instructionsDisplayedAlongStep!.map {
        FerrostarCoreFFI.VisualInstruction(mapboxVisualInstructionBanner: $0)
      }

    // TODO
    let spokenInstructions: [FerrostarCoreFFI.SpokenInstruction] = []

    // REVIEW: roadName - is it *this* road or the next road?
    self.init(
      geometry: geometry, distance: routeStep.distance, duration: routeStep.expectedTravelTime,
      roadName: routeStep.names?.first, instruction: routeStep.instructions,
      visualInstructions: visualInstructions, spokenInstructions: spokenInstructions)
  }
}

extension FerrostarCoreFFI.Route {
  init(mapboxRoute route: MapboxDirections.Route) {
    let waypoints = route.legs.map { $0.source }.map {
      FerrostarCoreFFI.Waypoint(mapboxWaypoint: $0)
    }

    let geometry: [GeographicCoordinate] = route.coordinates!.map {
      GeographicCoordinate(lat: $0.latitude, lng: $0.longitude)
    }

    let bounds = Bounds(
      lngLats: route.coordinates!.map { LngLat(lng: $0.longitude, lat: $0.latitude) })!
    let bbox = FerrostarCoreFFI.BoundingBox(
      sw: GeographicCoordinate(cl: bounds.min.asCLLocation.coordinate),
      ne: GeographicCoordinate(cl: bounds.max.asCLLocation.coordinate)
    )

    let steps: [FerrostarCoreFFI.RouteStep] = route.legs.flatMap {
      $0.steps.map { FerrostarCoreFFI.RouteStep(mapboxRouteStep: $0) }
    }

    self.init(
      geometry: geometry, bbox: bbox, distance: route.distance, waypoints: waypoints, steps: steps)
  }
}

struct MENavigationView: View {
  var route: FerrostarCoreFFI.Route
  //  let initialLocation: CLLocation
  let styleURL: URL
  let stopNavigation: () -> Void
  let destinationName: String?
  let locationProvider: LocationProviding

  @ObservedObject private var ferrostarCore: FerrostarCore

  @State private var camera: MapViewCamera

  @MainActor
  init(
    route: MapboxDirections.Route,
    stopNavigation: @escaping () -> Void
  ) {
    self.destinationName = route.legs.last?.destination.name
    self.route = FerrostarCoreFFI.Route(mapboxRoute: route)
    self.stopNavigation = stopNavigation
    self.styleURL = AppConfig().tileserverStyleUrl

    // TODO
    let travelMode: TravelMode = .bike
    // TODO
    let measurementSystem: MeasurementSystem = .metric

    if Env.current.simulateLocationForTesting {
      let simulatedLocationProvider = SimulatedLocationProvider(
        coordinate: route.coordinates!.first!)
      simulatedLocationProvider.warpFactor = 4
      try! simulatedLocationProvider.setSimulatedRoute(self.route)
      simulatedLocationProvider.startUpdating()
      self.locationProvider = simulatedLocationProvider
    } else {
      let coreLocationProvider = Env.current.coreLocationProvider
      let newActivityType: CLActivityType =
        switch travelMode {
        case .car:
          .automotiveNavigation
        default:
          .otherNavigation
        }
      if newActivityType != coreLocationProvider.activityType {
        coreLocationProvider.activityType = newActivityType
      }
      self.locationProvider = coreLocationProvider
    }

    // TODO: remove as!
    let routeProvider = TripPlanClientFerrostarAdapter(
      tripPlanNetworkClient: Env.current.tripPlanClient as! TripPlanNetworkClient,
      travelMode: travelMode, measurementSystem: measurementSystem)
    // Configure the navigation session.
    // You have a lot of flexibility here based on your use case.
    let config = SwiftNavigationControllerConfig(
      stepAdvance: .relativeLineStringDistance(
        minimumHorizontalAccuracy: 32, automaticAdvanceDistance: 10),
      routeDeviationTracking: .staticThreshold(
        minimumHorizontalAccuracy: 25, maxAcceptableDeviation: 20)
    )
    self.ferrostarCore = FerrostarCore(
      customRouteProvider: routeProvider, locationProvider: locationProvider,
      navigationControllerConfig: config)

      let currentCamera = Env.current.getMapCamera()!
//      let zoom = log2(156543.03392 / currentCamera.altitude)
      self.camera = .center(currentCamera.centerCoordinate, zoom: 18)
  }

  var body: some View {
    var mapView = DynamicallyOrientingNavigationView(
      styleURL: styleURL,
      camera: $camera,
      navigationState: ferrostarCore.state,
      destinationName: destinationName,
      onTapExit: { stopNavigation() },
      makeMapContent: {
        let source = ShapeSource(identifier: "userLocation") {
          // Demonstrate how to add a dynamic overlay;
          // also incidentally shows the extent of puck lag
          if let userLocation = locationProvider.lastLocation {
            MLNPointFeature(coordinate: userLocation.clLocation.coordinate)
          }
        }
        CircleStyleLayer(identifier: "foo", source: source)
      }
    )
    return mapView.onAppear {
      try! ferrostarCore.startNavigation(route: self.route)
    }
  }
}
