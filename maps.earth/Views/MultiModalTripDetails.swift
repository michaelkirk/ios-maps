//
//  MultiModalTripDetails.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/14/24.
//

import SwiftUI

struct TripDiagram {
  enum Element {
    case node(Node)
    case edge(TripLeg)
  }

  enum Node {
    case origin(from: Place, departureTime: Date)
    case stop(place: TripPlace, departureTime: Date)
    case destination(to: Place, arrivalTime: Date)

    var lngLat: LngLat {
      switch self {
      case .origin(from: let place, departureTime: _): place.location
      case .stop(let place, departureTime: _): place.location
      case .destination(to: let place, arrivalTime: _): place.location
      }
    }
  }

  let trip: Trip
  var elements: [Element]
  init(trip: Trip) {
    self.trip = trip
    var elements: [Element] = []
    let firstLeg = trip.legs[0]
    elements.append(
      .node(.origin(from: trip.from, departureTime: firstLeg.startTime))
    )
    var first = true
    for leg in trip.legs {
      if !first {
        elements.append(.node(.stop(place: leg.fromPlace, departureTime: leg.startTime)))
      }
      first = false
      elements.append(.edge(leg))
    }
    elements.append(
      .node(.destination(to: trip.to, arrivalTime: trip.legs.last!.endTime))
    )

    self.elements = elements
  }
}

extension MultiModalTripDetails {
  init(trip: Trip) {
    self.init(tripDiagram: TripDiagram(trip: trip))
  }
}

func formatDuration(from: Date, to: Date) -> String {
  let formatter = DateComponentsFormatter()
  formatter.unitsStyle = .full
  formatter.allowedUnits = [.hour, .minute]

  return formatter.string(from: from, to: to) ?? ""
}

struct MultiModalTripDetails: View {
  var tripDiagram: TripDiagram

  var trip: Trip {
    tripDiagram.trip
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("\(trip.durationFormatted) (\(trip.distanceFormatted))").scenePadding(.leading).bold()
      ScrollView {
        Grid(alignment: .trailing) {
          ForEach(tripDiagram.elements.identifiable()) {
            (step: IdentifiableValue<TripDiagram.Element>) in
            GridRow(alignment: .top) {
              let step = step.value
              switch step {
              case .node(.origin(from: let place, departureTime: let departureTime)):
                HStack {
                  Text(departureTime.formatted(date: .omitted, time: .shortened)).imageScale(.large)
                  Image(systemName: "mappin.circle").imageScale(.large)
                }
                HStack {
                  Text("Depart: \(place.name)")
                  Spacer()
                }
              case .node(.stop(place: let place, departureTime: let departureTime)):
                HStack {
                  Text(departureTime.formatted(date: .omitted, time: .shortened))
                  Image(systemName: "circle").foregroundColor(.secondary).imageScale(.large)
                }
                HStack {
                  Text(place.name ?? "")
                  Spacer()
                }
              case .node(.destination(to: let place, arrivalTime: let arrivalTime)):
                HStack {
                  Text(arrivalTime.formatted(date: .omitted, time: .shortened))
                  Image(systemName: "flag.checkered.circle").imageScale(.large)
                }
                HStack {
                  Text("Arrive: \(place.name)")
                  Spacer()
                }

              case .edge(let leg):
                HStack(alignment: .top) {
                  switch leg.modeLeg {
                  case .nonTransit(_):
                    Text(leg.mode.emoji).padding(.top, 4)
                  case .transit(let transitLeg):
                    Text(transitLeg.emojiRouteLabel).padding(.top, 4)
                  }
                  Spacer().frame(minWidth: 4, maxWidth: 4, maxHeight: .infinity)
                    .padding(.vertical, 40)
                    .background(.red)
                    // this number seems really brittle
                    .padding(.trailing, 11).padding(.leading, 8).padding(.top, -4)
                }
                HStack {
                  Text(formatDuration(from: leg.startTime, to: leg.endTime)).padding(.top, 4)
                  Spacer()
                }
              }
            }
          }
        }.padding()
      }
    }
  }
}

struct MultiModalTripDetailsSheetContents: View {
  var trip: Trip
  var onClose: () -> Void

  var body: some View {
    SheetContents(
      title: "Steps", onClose: onClose, presentationDetents: [.large],
      currentDetent: .constant(.large)
    ) {
      MultiModalTripDetails(trip: trip)
    }
  }
}

#Preview("Bus Trip Details") {
  let trip = FixtureData.transitTrips[0]
  return Text("").sheet(isPresented: .constant(true)) {
    MultiModalTripDetailsSheetContents(trip: trip, onClose: {})
  }
}
