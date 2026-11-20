//
//  TripList.swift
//  maps.earth
//
//  Created by Michael Kirk on 5/23/24.
//

import SwiftUI

struct TripList: View {
  @ObservedObject var tripPlan: TripPlan
  @Binding var trips: [Trip]
  @State var stepsDetent: PresentationDetent = initialDetentHeight
  @State private var selectedGroupId: UUID?

  var body: some View {
    ScrollViewReader { scrollView in
      List(Array(groups.enumerated()), id: \.element.id) { groupIdx, group in
        // Re-read, so a row moves on to its next departure as earlier ones leave.
        TimelineView(.periodic(from: .now, by: 30)) { context in
          let trip = shownTrip(group, now: context.date)
          VStack(alignment: .leading) {
            Button(action: {
              if tripPlan.selectedTrip == trip {
                // single-mode steps from OTP aren't supported yet
                if trip.legs.count > 1 || tripPlan.mode != .transit {
                  tripPlan.isShowingSteps = true
                }
              } else {
                tripPlan.selectedTrip = trip
              }
            }) {
              HStack(spacing: 8) {
                Spacer().frame(maxWidth: 8, maxHeight: .infinity)
                  .background(trip == tripPlan.selectedTrip ? Color.hw_blue : .clear)
                HStack {
                  if tripPlan.mode == .transit {
                    TransitPlanItem(
                      group: group, trip: trip,
                      onSelect: { tripPlan.selectedTrip = $0 },
                      onFocusLeg: { focus(legIdx: $0, of: trip) }
                    ) {
                      tripPlan.selectedTrip = trip
                      tripPlan.isShowingSteps = true
                    }
                  } else {
                    NonTransitPlanItem(trip: trip) { navigate(trip: trip) }
                  }
                }.padding(.top, Space.s)
              }
            }
          }
        }
        .clipShape(rowShape(groupIdx))
        .listRowBackground(rowShape(groupIdx).fill(.white))
        .listRowSeparator(groupIdx == groups.count - 1 ? .hidden : .automatic, edges: .bottom)
        .listRowInsets(EdgeInsets()).id(group.id)
      }.listStyle(.plain)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Space.xl) }
        .onChange(of: tripPlan.selectedTrip) { newValue in
          guard let newValue, let group = groups.first(where: { $0.contains(newValue) }) else {
            return
          }
          // Picking another departure of the same trip leaves its row where the rider tapped it.
          guard group.id != selectedGroupId else {
            return
          }
          selectedGroupId = group.id
          withAnimation {
            scrollView.scrollTo(group.id, anchor: .top)
          }
        }
    }.sheet(item: stepsTrip, onDismiss: { stepsDetent = initialDetentHeight }) { trip in
      let _ = assert(trip.legs.count > 0)
      if trip.legs.count == 1, case .nonTransit(let nonTransitLeg) = trip.legs[0].modeLeg {
        ManeuverListSheetContents(
          trip: trip, tripPlan: tripPlan, maneuvers: nonTransitLeg.maneuvers,
          currentDetent: $stepsDetent,
          // Like the trip list, a transit search has no GO, even for a trip that's all walking.
          onGo: tripPlan.mode == .transit
            ? nil
            : {
              // Navigation covers the whole screen, which it can't do over the steps sheet.
              tripPlan.isShowingSteps = false
              navigate(trip: trip)
            },
          onClose: { tripPlan.isShowingSteps = false })
      } else {
        MultiModalTripDetailsSheetContents(
          trip: trip, currentDetent: $stepsDetent,
          onFocus: { tripPlan.focusedStep = $0 },
          onClose: { tripPlan.isShowingSteps = false })
      }
    }
  }

  private var groups: [TripGroup] {
    TripGroup.group(trips)
  }

  /// The group's picked departure, else the next one yet to leave.
  private func shownTrip(_ group: TripGroup, now: Date) -> Trip {
    if let selected = tripPlan.selectedTrip, group.contains(selected) {
      return selected
    }
    return group.nextDeparture(at: now)
  }

  /// Picks `trip`, or once it's picked, zooms to where its leg at `legIdx` starts.
  private func focus(legIdx: Int, of trip: Trip) {
    guard tripPlan.selectedTrip == trip else {
      tripPlan.selectedTrip = trip
      return
    }
    tripPlan.focusedStep = trip.legs[legIdx].focusedStep
  }

  /// Rounds the list's outer corners, like the From/To field above it.
  private func rowShape(_ rowIdx: Int) -> UnevenRoundedRectangle {
    let radius: CGFloat = 8
    let top = rowIdx == 0 ? radius : 0
    let bottom = rowIdx == groups.count - 1 ? radius : 0
    return UnevenRoundedRectangle(
      topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom,
      topTrailingRadius: top)
  }

  /// Starts turn-by-turn navigation along `trip`.
  private func navigate(trip: Trip) {
    // The directions API answers with the same list, so matches the trip by position in it.
    let tripIdx = trips.firstIndex(of: trip)!
    tripPlan.selectedTrip = trip
    Task {
      do {
        self.tripPlan.selectedRoute = .success(
          try await DirectionsService().route(
            from: trip.from, to: trip.to, mode: tripPlan.mode,
            transitWithBike: tripPlan.bringsBike, tripIdx: tripIdx))
      } catch {
        self.tripPlan.selectedRoute = .failure(error)
        print("error when getting directions: \(error)")
      }
    }
  }

  /// The trip whose steps are showing, if any.
  var stepsTrip: Binding<Trip?> {
    Binding(
      get: { tripPlan.isShowingSteps ? tripPlan.selectedTrip : nil },
      set: { tripPlan.isShowingSteps = $0 != nil })
  }
}

#Preview("walking") {
  let tripPlan = FixtureData.walkTripPlan
  let trips = try! tripPlan.trips.get()
  return TripList(tripPlan: tripPlan, trips: .constant(trips))
}
