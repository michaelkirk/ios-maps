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
    let roundaboutExitNumber: UInt8? = nil
    let drivingSide = FerrostarCoreFFI.DrivingSide.right

    self.init(
      geometry: geometry, distance: routeStep.distance, duration: routeStep.expectedTravelTime,
      roadName: routeStep.names?.first, exits: exits, instruction: routeStep.instructions,
      visualInstructions: visualInstructions, spokenInstructions: spokenInstructions,
      annotations: annotations, incidents: incidents, drivingSide: drivingSide,
      roundaboutExitNumber: roundaboutExitNumber)
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

@MainActor
final class NavigationSession: ObservableObject {
  let route: FerrostarCoreFFI.Route
  let ferrostarCore: FerrostarCore
  let destination: MapboxDirections.Waypoint

  // FerrostarCore is an NSObject with @Published fields, but it does not
  // conform to ObservableObject — so observing `ferrostarCore.state` directly
  // from a SwiftUI view doesn't trigger re-renders. We mirror it here so the
  // session's own objectWillChange drives the view.
  @Published private(set) var navigationState: NavigationState?

  init(
    mapboxRoute mlnRoute: MapboxDirections.Route,
    travelMode: TravelMode,
    measurementSystem: MeasurementSystem
  ) {
    self.destination = mlnRoute.legs.last!.destination
    let route = FerrostarCoreFFI.Route(mapboxRoute: mlnRoute)
    self.route = route

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

      // Set to true to simulate driving off the route, exercising the
      // recalculation path. Has no effect outside the simulator.
      let goOffTrack = false
      if goOffTrack {
        try! simulatedLocationProvider.setSimulatedRoute(route, bias: .right(30.0))
      } else {
        try! simulatedLocationProvider.setSimulatedRoute(route)
      }
      simulatedLocationProvider.startUpdating()
      locationProvider = simulatedLocationProvider
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
    let minimumHorizontalAccuracy: UInt16 = 32
    let config = SwiftNavigationControllerConfig(
      waypointAdvance: .waypointWithinRange(20),
      stepAdvanceCondition: stepAdvanceDistanceEntryAndExit(
        distanceToEndOfStep: 10, distanceAfterEndOfStep: 10,
        minimumHorizontalAccuracy: minimumHorizontalAccuracy),
      arrivalStepAdvanceCondition: stepAdvanceDistanceToEndOfStep(
        distance: 20, minimumHorizontalAccuracy: minimumHorizontalAccuracy),
      routeDeviationTracking: .staticThreshold(
        minimumHorizontalAccuracy: minimumHorizontalAccuracy, maxAcceptableDeviation: 20),
      snappedLocationCourseFiltering: .snapToRoute
    )

    let ferrostarCore = FerrostarCore(
      customRouteProvider: routeProvider,
      locationProvider: locationProvider,
      navigationControllerConfig: config
    )
    self.ferrostarCore = ferrostarCore
    try! ferrostarCore.startNavigation(route: route)

    ferrostarCore.$state.assign(to: &$navigationState)
  }
}

struct MENavigationView: View {
  let styleURL: URL
  let stopNavigation: (_ didComplete: Bool) -> Void

  @StateObject private var session: NavigationSession
  @State private var camera: MapViewCamera

  @MainActor
  init(
    route mlnRoute: MapboxDirections.Route,
    travelMode: TravelMode,
    measurementSystem: MeasurementSystem,
    stopNavigation: @escaping (_ didComplete: Bool) -> Void
  ) {
    self.stopNavigation = stopNavigation
    self.styleURL = Env.current.preferences.tileserverStyleUrl

    _session = StateObject(
      wrappedValue: NavigationSession(
        mapboxRoute: mlnRoute,
        travelMode: travelMode,
        measurementSystem: measurementSystem
      )
    )

    // I'd prefer to start navigation from "within" the current map, rather than popping a sheet with a new modal on it,
    // but to at least keep up the illusion of consistency, we start the new map with the same camera as the old camera.
    // NOTE: This still feels a little glitchy, beyond just the animation of presenting the sheet, the new map has to load
    // in all the layers, so there's a little delay as the image in the newlyl popped "navigation" map catches up visually
    // with the presented "MapView".
    // Adding to this, there's also a zoom as we start the trip: zomming from "trip overview" to the "current location".
    let currentCamera = Env.current.getMapCamera()!
    _camera = State(initialValue: .center(currentCamera.centerCoordinate, zoom: 18))
  }

  var body: some View {
    let ferrostarCore = session.ferrostarCore
    let rawUserCoordinate: CLLocationCoordinate2D? = {
      if case .navigating(_, let userLocation, _, _, _, _, _, _, _, _, _) =
        session.navigationState?.tripState
      {
        return userLocation.coordinates.clLocationCoordinate2D
      }
      return nil
    }()

    var mapView = DynamicallyOrientingNavigationView(
      styleURL: styleURL,
      // I'm not sure why this is a binding exactly, since we soon override it in onStyleLoaded.
      // I guess so that we can transition to/from the navigation mode?
      camera: $camera,
      navigationState: session.navigationState,
      isMuted: ferrostarCore.spokenInstructionObserver.isMuted,
      onTapMute: { ferrostarCore.spokenInstructionObserver.toggleMute() },
      onTapExit: { stopNavigation(false) }
    ) {
      // Debug overlay: raw GPS location (the built-in puck shows the snapped location).
      let rawLocationSource = ShapeSource(identifier: "debug-raw-location-source") {
        if let coordinate = rawUserCoordinate {
          MLNPointFeature(coordinate: coordinate)
        }
      }
      CircleStyleLayer(identifier: "debug-raw-location", source: rawLocationSource)
        .radius(6)
        .color(.systemGray)
        .circleOpacity(0.5)
        .strokeWidth(1)
        .strokeColor(.white)
        .circleStrokeOpacity(0.5)
    }

    mapView.onStyleLoaded = { style in
      add3DBuildingsLayer(style: style)
    }

    return mapView.navigationViewProgressView({
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
            destinationName: self.session.destination.name, onTapExit: { stopNavigation(true) }
          )
          .padding(.horizontal, 16))
      } else {
        return AnyView(EmptyView())
      }
    }).onChange(
      of: session.navigationState,
      perform: { (value: NavigationState?) in
        guard let tripState = value?.tripState else {
          return
        }

        if case .complete = tripState {
          let coordinate = self.session.route.geometry.last!.clLocationCoordinate2D
          let bbox = MLNCoordinateBounds(sw: coordinate, ne: coordinate).extend(bufferMeters: 100)

          self.camera.setPitch(0)
          // HACKY way to get the destination *centered* in the screen when the trip is complete
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
