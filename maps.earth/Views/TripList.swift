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
  @Binding var showSteps: Bool

  var body: some View {
    ScrollViewReader { scrollView in
      List(Array(trips.enumerated()), id: \.offset, selection: $tripPlan.selectedTrip) {
        tripIdx, trip in
        VStack(alignment: .leading) {
          Button(action: {
            if tripPlan.selectedTrip == trip {
              // single-mode steps from OTP aren't supported yet
              if trip.legs.count > 1 || tripPlan.mode != .transit {
                showSteps = true
              }
            } else {
              tripPlan.selectedTrip = trip
            }
          }) {
            HStack(spacing: 8) {
              Spacer().frame(maxWidth: 8, maxHeight: .infinity)
                .background(trip == tripPlan.selectedTrip ? .blue : .clear)
              HStack {
                if tripPlan.mode == .transit {
                  TransitPlanItem(trip: trip) {
                    tripPlan.selectedTrip = trip
                    showSteps = true
                  }
                } else {
                  NonTransitPlanItem(trip: trip) {
                    tripPlan.selectedTrip = trip
                    Task {
                      do {
                        self.tripPlan.selectedRoute = .success(
                          try await DirectionsService().directions(
                            from: trip.from, to: trip.to, mode: tripPlan.mode, tripIdx: tripIdx))
                      } catch {
                        self.tripPlan.selectedRoute = .failure(error)
                        print("error when getting directions: \(error)")
                      }
                    }
                  }
                }
              }
            }
          }
        }.listRowInsets(EdgeInsets())
      }.listStyle(.plain)
        .onChange(of: tripPlan.selectedTrip) { newValue in
          guard let newValue = newValue else {
            return
          }
          withAnimation {
            scrollView.scrollTo(newValue.id, anchor: .top)
          }
        }
    }.sheet(isPresented: $showSteps) {
      let trip = tripPlan.selectedTrip!
      let _ = assert(trip.legs.count > 0)
      if trip.legs.count == 1, case .nonTransit(let nonTransitLeg) = trip.legs[0].modeLeg {
        ManeuverListSheetContents(
          trip: trip, maneuvers: nonTransitLeg.maneuvers, onClose: { showSteps = false })
      } else {
        MultiModalTripDetailsSheetContents(trip: trip, onClose: { showSteps = false })
      }
    }
  }
}

#Preview {
  let tripPlan = FixtureData.walkTripPlan
  let trips = try! tripPlan.trips.get()
  return TripList(tripPlan: tripPlan, trips: .constant(trips), showSteps: .constant(false))
}
