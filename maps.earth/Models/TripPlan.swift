//
//  TripPlan.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/8/24.
//

import Foundation
import MapboxDirections

// TODO: split this into something like TripQuery and TripResponse
//       since many of these fields will be blank.
@MainActor
class TripPlan: ObservableObject {
  @Published
  var navigateFrom: Place?

  @Published
  var navigateTo: Place?

  @Published
  var mode: TravelMode

  @Published var transitWithBike: Bool = false
  /// The rider only brings a bike on transit, though the option outlives a switch to another mode.
  var bringsBike: Bool { mode == .transit && transitWithBike }
  @Published var bounds: Bounds?
  @Published var trips: Result<[Trip], Error>
  @Published var selectedTrip: Trip? {
    didSet {
      if selectedTrip == nil {
        isShowingSteps = false
      }
      if selectedTrip != oldValue {
        scrubFraction = nil
        focusedClimb = nil
        focusedStep = nil
      }
    }
  }

  /// How far along the selected trip the elevation scrubber is, shared by its chart and the map.
  @Published var scrubFraction: Double?
  /// The climb the rider picked, which the map zooms to and highlights.
  @Published var focusedClimb: SteepSection?
  /// The step the rider picked, which the map zooms to. New for each pick, so picking the same
  /// step again zooms back to it.
  @Published var focusedStep: FocusedStep?

  struct FocusedStep: Equatable {
    let location: LngLat
    let id = UUID()
  }

  /// Scrubs to the middle of `climb` and shows it on the map.
  func select(climb: SteepSection, of elevation: LegElevation) {
    scrubFraction = elevation.midpointFraction(of: climb)
    focusedClimb = climb
  }
  @Published var selectedRoute: Result<Route, Error>?

  /// Whether the rider has opened the selected trip's details.
  @Published var isShowingSteps: Bool = false

  init(
    from fromPlace: Place? = nil,
    to toPlace: Place? = nil,
    mode: TravelMode = .walk,
    trips: Result<[Trip], Error> = .success([]),
    selectedTrip: Trip? = nil,
    bounds: Bounds? = nil
  ) {
    self.navigateFrom = fromPlace
    self.navigateTo = toPlace
    self.mode = mode
    self.trips = trips
    if case .success(let trips) = trips {
      self.selectedTrip = selectedTrip ?? trips.first
    } else {
      assert(self.selectedTrip == nil)
    }
    self.bounds = bounds
  }

  var isEmpty: Bool {
    if self.navigateFrom == nil && self.navigateTo == nil {
      assert(self.bounds == nil)
      switch self.trips {
      case .success([]):
        break
      default:
        assertionFailure("unexpected trips: \(self.trips)")
      }
      assert(self.selectedTrip == nil)
      return true
    } else {
      return false
    }
  }

  /// Reverse the trip, discarding trips planned in the old direction.
  func swapEndpoints() {
    (self.navigateFrom, self.navigateTo) = (self.navigateTo, self.navigateFrom)
    self.trips = .success([])
    self.selectedTrip = nil
  }

  func clear() {
    self.navigateFrom = nil
    self.navigateTo = nil
    self.bounds = nil
    self.trips = .success([])
    self.selectedTrip = nil
  }
}
