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

  var body: some View {
    ScrollViewReader { scrollView in
      List(Array(trips.enumerated()), id: \.offset, selection: $tripPlan.selectedTrip) {
        tripIdx, trip in
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
                  TransitPlanItem(trip: trip) {
                    tripPlan.selectedTrip = trip
                    tripPlan.isShowingSteps = true
                  }
                } else {
                  NonTransitPlanItem(trip: trip, tripPlan: tripPlan) {
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
                }
              }
            }
          }
        }.listRowInsets(EdgeInsets()).id(trip.id)
      }.listStyle(.plain)
        .onChange(of: tripPlan.selectedTrip) { newValue in
          guard let newValue = newValue else {
            return
          }
          withAnimation {
            scrollView.scrollTo(newValue.id, anchor: .top)
          }
        }
    }.sheet(item: stepsTrip, onDismiss: { stepsDetent = initialDetentHeight }) { trip in
      let _ = assert(trip.legs.count > 0)
      if trip.legs.count == 1, case .nonTransit(let nonTransitLeg) = trip.legs[0].modeLeg {
        ManeuverListSheetContents(
          trip: trip, tripPlan: tripPlan, maneuvers: nonTransitLeg.maneuvers,
          currentDetent: $stepsDetent,
          onClose: { tripPlan.isShowingSteps = false })
      } else {
        MultiModalTripDetailsSheetContents(
          trip: trip, currentDetent: $stepsDetent, onClose: { tripPlan.isShowingSteps = false })
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
