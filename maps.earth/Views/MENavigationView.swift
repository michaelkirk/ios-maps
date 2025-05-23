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
import Turf

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

    // Note: this is relative to your entry into the roundabout, so 180 would be "straight".
    // REVIEW: ferrostar allows this to be optional, but mapbox defaults to 180.
    let roundaboutExitDegrees: UInt16 = UInt16(visualInstruction.finalHeading)

    // TODO: added to ferrostar, but doesn't seem to exist in MapboxDirections.VisualInstruction
    // Presumably Mapbox has *some* concept of exitNumbers - not sure where they exist yet.
    let exitNumbers: [String] = []

    self.init(
      text: visualInstruction.text ?? "TODO: missing text", maneuverType: maneuverType,
      maneuverModifier: maneuverModifier, roundaboutExitDegrees: roundaboutExitDegrees,
      laneInfo: nil, exitNumbers: exitNumbers)
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

    // TODO: Integrate a reasonable default upstream
    let triggerDistanceBeforeManeuver: Double = 100

    self.init(
      primaryContent: primaryContent, secondaryContent: secondaryContent, subContent: nil,
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

    // TODO: added to ferrostar, but I'm not sure yet the corresponding fields from mapbox
    let exits: [String] = []
    let annotations: [String] = []
    let incidents: [Incident] = []

    self.init(
      geometry: geometry, distance: routeStep.distance, duration: routeStep.expectedTravelTime,
      roadName: routeStep.names?.first, exits: exits, instruction: routeStep.instructions,
      visualInstructions: visualInstructions, spokenInstructions: spokenInstructions,
      annotations: annotations, incidents: incidents)
  }
}

extension FerrostarCoreFFI.Route {
  init(mapboxRoute route: MapboxDirections.Route) {

    var waypoints = route.legs.map { $0.source }.map {
      FerrostarCoreFFI.Waypoint(mapboxWaypoint: $0)
    }
    if let destination = route.legs.last?.destination {
      waypoints.append(FerrostarCoreFFI.Waypoint(mapboxWaypoint: destination))
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

struct RouteNavigation {
  let route: FerrostarCoreFFI.Route
  let ferrostarCore: FerrostarCore
}

struct MENavigationView: View {
  var route: FerrostarCoreFFI.Route
  //  let initialLocation: CLLocation
  let styleURL: URL
  let stopNavigation: (_ didComplete: Bool) -> Void
  let destination: MapboxDirections.Waypoint

  @ObservedObject private var ferrostarCore: FerrostarCore

  @State private var camera: MapViewCamera

  @MainActor
  init(
    route mlnRoute: MapboxDirections.Route,
    travelMode: TravelMode,
    measurementSystem: MeasurementSystem,
    stopNavigation: @escaping (_ didComplete: Bool) -> Void
  ) {
    self.destination = mlnRoute.legs.last!.destination
    let route = FerrostarCoreFFI.Route(mapboxRoute: mlnRoute)
    self.stopNavigation = stopNavigation
    self.styleURL = AppConfig().tileserverStyleUrl

    let routeNavigation: RouteNavigation
    if let existingRouteNavigation = Env.current.activeRouteNavigation,
      existingRouteNavigation.route == route
    {
      routeNavigation = existingRouteNavigation
    } else {
      // TODO: remove as!
      let routeProvider = TripPlanClientFerrostarAdapter(
        tripPlanNetworkClient: Env.current.tripPlanClient as! TripPlanNetworkClient,
        travelMode: travelMode,
        measurementSystem: measurementSystem
      )

      let locationProvider: LocationProviding
      if Env.current.simulateLocationForTesting {
        let simulatedLocationProvider = SimulatedLocationProvider(
          coordinate: mlnRoute.coordinates!.first!)
        simulatedLocationProvider.warpFactor = 1
        try! simulatedLocationProvider.setSimulatedRoute(route)
        simulatedLocationProvider.startUpdating()
        let goOffTrack = false
        if goOffTrack {
          locationProvider = OffTrackSimulatedLocationProvider(
            simulatedLocationProvider: simulatedLocationProvider)
        } else {
          locationProvider = simulatedLocationProvider
        }
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
        locationProvider = coreLocationProvider
      }

      // Configure the navigation session.
      // You have a lot of flexibility here based on your use case.
      let config = SwiftNavigationControllerConfig(
        waypointAdvance: .waypointWithinRange(20),
        stepAdvance: .relativeLineStringDistance(
          minimumHorizontalAccuracy: 32,
          specialAdvanceConditions: .advanceAtDistanceFromEnd(10)
        ),
        routeDeviationTracking: .staticThreshold(
          minimumHorizontalAccuracy: 25,
          maxAcceptableDeviation: 20
        ),
        snappedLocationCourseFiltering: .snapToRoute
      )

      let ferrostarCore = FerrostarCore(
        customRouteProvider: routeProvider,
        locationProvider: locationProvider,
        navigationControllerConfig: config
      )
      routeNavigation = RouteNavigation(route: route, ferrostarCore: ferrostarCore)
      Env.current.activeRouteNavigation = routeNavigation
      try! ferrostarCore.startNavigation(route: routeNavigation.route)
    }
    self.route = routeNavigation.route
    self.ferrostarCore = routeNavigation.ferrostarCore

    let currentCamera = Env.current.getMapCamera()!
    // I'd prefer to start navigation from "within" the current map, rather than popping a sheet with a new modal on it,
    // but to at least keep up the illusion of consistency, we start the new map with the same camera as the old camera.
    // NOTE: This still feels a little glitchy, beyond just the animation of presenting the sheet, the new map has to load
    // in all the layers, so there's a little delay as the image in the newlyl popped "navigation" map catches up visually
    // with the presented "MapView".
    // Adding to this, there's also a zoom as we start the trip: zomming from "trip overview" to the "current location".
    self.camera = .center(currentCamera.centerCoordinate, zoom: 18)
  }

  var body: some View {
    var mapView = DynamicallyOrientingNavigationView(
      styleURL: styleURL,
      // I'm not sure why this is a binding exactly, since we soon override it in onStyleLoaded.
      // I guess so that we can transition to/from the navigation mode?
      camera: $camera,
      navigationState: ferrostarCore.state,
      isMuted: true,
      onTapMute: { assertionFailure("muting not implemented") },
      onTapExit: { stopNavigation(false) }
    )
    mapView.onStyleLoaded = { style in
      add3DBuildingsLayer(style: style)
    }
    mapView.progressView = {
      (navigationState: NavigationState?, onTapExit: (() -> Void)?) -> AnyView in
      if case .navigating = navigationState?.tripState,
        let progress = navigationState?.currentProgress
      {
        return AnyView(
          TripProgressView(
            progress: progress,
            onTapExit: onTapExit
          ))
      } else if case .complete = navigationState?.tripState {
        // No longer showing...
        return AnyView(
          TripCompleteBanner(
            destinationName: self.destination.name, onTapExit: { stopNavigation(true) }
          )
          .padding(.horizontal, 16))
      } else {
        return AnyView(EmptyView())
      }
    }

    return mapView.onChange(
      of: ferrostarCore.state,
      perform: { (value: NavigationState?) in
        guard let tripState = value?.tripState else {
          return
        }

        if case .complete = tripState {
          let coordinate = self.route.geometry.last!.clLocationCoordinate2D
          let bbox = MLNCoordinateBounds(sw: coordinate, ne: coordinate).extend(bufferMeters: 100)

          self.camera.setPitch(0)
          // HACKY way to get the destination *centered* in the screen
          // rather than centered towards the bottom where the puck lives
          self.camera = .boundingBox(
            bbox, edgePadding: UIEdgeInsets(top: 0, left: 0, bottom: 400, right: 0))
        }
      }
    ).onAppear {
      UIApplication.shared.isIdleTimerDisabled = true
    }.onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
    }
  }
}

class OffTrackSimulatedLocationProvider: LocationProviding {
  var simulatedLocationProvider: SimulatedLocationProvider

  init(simulatedLocationProvider: SimulatedLocationProvider) {
    self.simulatedLocationProvider = simulatedLocationProvider
  }

  var delegate: (any LocationManagingDelegate)? {
    get {
      simulatedLocationProvider.delegate
    }
    set {
      simulatedLocationProvider.delegate = newValue
    }
  }

  var authorizationStatus: CLAuthorizationStatus {
    simulatedLocationProvider.authorizationStatus
  }

  var lastLocation: FerrostarCoreFFI.UserLocation? {
    let goOffTrack = false
    if goOffTrack {
      let offsetMeters: CGFloat = 100
      let offsetDirection: CGFloat = 90
      return simulatedLocationProvider.lastLocation.map { location in
        let clCoord = location.clLocation.coordinate
        let translated = clCoord.coordinate(at: offsetMeters, facing: offsetDirection)
        return UserLocation(clCoordinateLocation2D: translated)
      }
    } else {
      return simulatedLocationProvider.lastLocation
    }
  }

  var lastHeading: FerrostarCoreFFI.Heading? {
    simulatedLocationProvider.lastHeading
  }

  func startUpdating() {
    simulatedLocationProvider.startUpdating()
  }

  func stopUpdating() {
    simulatedLocationProvider.stopUpdating()
  }
}
