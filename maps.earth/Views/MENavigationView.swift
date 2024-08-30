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

  private var locationProvider: LocationProviding
  @ObservedObject private var ferrostarCore: FerrostarCore

  @State private var camera: MapViewCamera
  @State private var snappedCamera = true

  @MainActor
  init(
    route: MapboxDirections.Route,
    stopNavigation: @escaping () -> Void,
    locationProvider: LocationProviding? = nil,
    ferrostarCore: FerrostarCore? = nil
  ) {
    self.route = FerrostarCoreFFI.Route(mapboxRoute: route)
    if let simulatedLocationProvider = Env.current.locationProvider as? SimulatedLocationProvider {
      try! simulatedLocationProvider.setSimulatedRoute(self.route)
      simulatedLocationProvider.startUpdating()
    }
    // TODO: revisit initialLocation - what is it actually? If I can infer it from route, maybe the param should be removed and inferred interneally rather than externally
    //    self.initialLocation =  CLLocation(coordinate: route.coordinates!.first!)
    self.stopNavigation = stopNavigation
    self.styleURL = AppConfig().tileserverStyleUrl
    self.locationProvider = locationProvider ?? Env.current.locationProvider
    self.ferrostarCore = ferrostarCore ?? Env.current.ferrostarCore

    let initialCoordinate: CLLocationCoordinate2D = route.coordinates!.first!
    self.camera = .center(initialCoordinate, zoom: 14)
  }

  var body: some View {
    DynamicallyOrientingNavigationView(
      styleURL: styleURL,
      camera: $camera,
      navigationState: ferrostarCore.state,
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
    .onAppear {
      // TODO: waiting for simulated location to take effect.
      DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
        try! Env.current.ferrostarCore.startNavigation(route: self.route)
      }
    }
  }
}
