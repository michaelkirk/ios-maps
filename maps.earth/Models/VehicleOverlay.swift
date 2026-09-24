//
//  VehicleOverlay.swift
//  maps.earth
//
//  Created by Michael Kirk on 9/17/26.
//

import Foundation
import MapLibre

private let logger = FileLogger()

/// A transit vehicle drawn on the map. Outlives a poll so the marker can be animated between
/// polls, and so a callout being read doesn't vanish out from under the reader.
class TransitVehicleAnnotation: MLNPointAnnotation {
  var vehicle: TransitVehicle
  weak var callout: TransitVehicleCalloutView?
  /// Vehicles that aren't on the selected trip are drawn faded.
  var isFaded: Bool = false
  /// How far this device's clock is from the server's, so both the dot and the callout talk about
  /// the same instant the server does.
  var clockOffset: TimeInterval

  /// Now, by the server's clock.
  var correctedNow: Date {
    Date.now.addingTimeInterval(clockOffset)
  }

  init(vehicle: TransitVehicle, clockOffset: TimeInterval) {
    self.vehicle = vehicle
    self.clockOffset = clockOffset
    super.init()
    self.coordinate = vehicle.location(at: correctedNow).asCoordinate
    // MapLibre won't ask whether a callout can be shown unless the annotation already has a
    // title. `TransitVehicleCalloutView` draws its own contents; this is only the gate.
    self.title = vehicle.routeName
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

/// Polls for the vehicles serving the transit legs of the trips on screen and walks each along
/// travelmux's predicted track between polls.
///
/// Only some feeds publish positions, so most trips draw nothing at all.
@MainActor
class VehicleOverlay: NSObject {
  /// OTP polls its GTFS-RT vehicle position updaters once a minute, so asking much more often than
  /// this just re-fetches a position we already have.
  private static let pollInterval: Duration = .seconds(30)

  private let client = VehiclePositionsClient()
  private weak var mapView: MLNMapView?
  private var query: Query?
  private var pollTask: Task<Void, Never>?
  private var displayLink: CADisplayLink?
  private var annotations: [String: TransitVehicleAnnotation] = [:]
  /// The patterns of the trip the traveler has picked. Vehicles on any other trip's patterns are
  /// faded.
  private var selectedPatternCodes: Set<String> = []
  /// Set from each poll's `serverTime`: a device a few minutes out otherwise pins every vehicle at
  /// one end of its track.
  private var clockOffset: TimeInterval = 0

  nonisolated override init() {
    super.init()
  }

  /// What we're asking travelmux about: the plan's endpoints, which pick the transit graph, and
  /// the patterns its legs ride.
  private struct Query: Equatable {
    let from: LngLat
    let to: LngLat
    let patterns: [PatternRequest]
  }

  /// Every trip shares the plan's endpoints, which pick the transit graph.
  func update(mapView: MLNMapView, selected: MapTrip, unselected: [MapTrip]) {
    AssertMainThread()
    self.mapView = mapView

    let selectedTrip = selected.trip
    let query = Query(
      from: selectedTrip.from.location, to: selectedTrip.to.location,
      patterns: Self.patterns(trips: [selectedTrip] + unselected.map { $0.trip }))
    guard !query.patterns.isEmpty else {
      stop()
      return
    }

    self.selectedPatternCodes = Set(selectedTrip.patternCodes)

    if self.query != query {
      self.query = query
      start()
    }
    applyFading()
  }

  func stop() {
    AssertMainThread()
    self.query = nil
    self.pollTask?.cancel()
    self.pollTask = nil
    self.displayLink?.invalidate()
    self.displayLink = nil
    for annotation in annotations.values {
      annotation.callout?.dismissCallout(animated: false)
      mapView?.removeAnnotation(annotation)
    }
    self.annotations.removeAll()
  }

  /// The pattern each transit leg rides, and where the rider boards it.
  private static func patterns(trips: [Trip]) -> [PatternRequest] {
    var seen: Set<String> = []
    return trips.flatMap { $0.legs }.compactMap { leg in
      guard let patternCode = leg.transitLeg?.patternCode, seen.insert(patternCode).inserted else {
        return nil
      }
      return PatternRequest(code: patternCode, boardingStop: leg.fromPlace.location)
    }
  }

  private func start() {
    self.pollTask?.cancel()
    self.pollTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.refresh()
        try? await Task.sleep(for: Self.pollInterval)
      }
    }

    guard displayLink == nil else {
      return
    }
    // A vehicle reports about once a minute but moves continuously, so positions are interpolated
    // per frame rather than per poll. A dot creeping along a street doesn't need 60fps to do it.
    let displayLink = CADisplayLink(target: self, selector: #selector(animate))
    displayLink.preferredFramesPerSecond = 15
    displayLink.add(to: .main, forMode: .common)
    self.displayLink = displayLink
  }

  @objc private func animate() {
    let now = Date.now.addingTimeInterval(clockOffset)
    for annotation in annotations.values {
      annotation.coordinate = annotation.vehicle.location(at: now).asCoordinate
    }
  }

  private func refresh() async {
    guard let query else {
      return
    }

    let response: VehiclePositionsResponse
    do {
      response = try await client.query(
        from: query.from, to: query.to, patterns: query.patterns)
    } catch {
      logger.warning("failed to fetch vehicle positions: \(error)")
      return
    }

    // A poll that lands after the screen has moved on has nothing left to draw onto.
    guard self.query == query, let mapView else {
      return
    }

    // The round trip is part of how stale the answer already is, so measure against its receipt.
    self.clockOffset = response.serverTime.timeIntervalSince(.now)
    if let unknownPatterns = response.unknownPatterns {
      // The plan these came from predates a transit data rebuild - its vehicles are gone for good.
      logger.info("travelmux doesn't recognize patterns: \(unknownPatterns)")
    }

    var stale = Set(annotations.keys)
    for vehicle in response.vehicles {
      stale.remove(vehicle.id)
      if let existing = annotations[vehicle.id] {
        // Keep the annotation: replacing it would drop an open callout.
        existing.vehicle = vehicle
        existing.clockOffset = clockOffset
      } else {
        let annotation = TransitVehicleAnnotation(vehicle: vehicle, clockOffset: clockOffset)
        annotations[vehicle.id] = annotation
        mapView.addAnnotation(annotation)
      }
    }

    // Vehicles that stopped reporting, or left the patterns we asked about.
    for id in stale {
      if let annotation = annotations.removeValue(forKey: id) {
        annotation.callout?.dismissCallout(animated: false)
        mapView.removeAnnotation(annotation)
      }
    }

    applyFading()
  }

  private func applyFading() {
    for annotation in annotations.values {
      let isFaded =
        !selectedPatternCodes.isEmpty
        && !selectedPatternCodes.contains(annotation.vehicle.patternCode)
      annotation.isFaded = isFaded
      if let view = mapView?.view(for: annotation) as? TransitVehicleMarkerView {
        view.isFaded = isFaded
      }
    }
  }
}
