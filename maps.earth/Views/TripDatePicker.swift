//
//  TripDatePicker.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/24/24.
//

import SwiftUI

struct TripDatePicker: View {

  @State
  var date: Date
  @State
  var oldDate: Date

  @Binding
  var mode: TripDateMode
  @State
  var oldMode: TripDateMode

  init(mode: Binding<TripDateMode>) {
    self._mode = mode
    self.oldMode = mode.wrappedValue
    switch mode.wrappedValue {
    case .departNow:
      let now = Date.now
      self.date = now
      self.oldDate = now
    case .departAt(let date):
      self.date = date
      self.oldDate = date
    case .arriveBy(let date):
      self.date = date
      self.oldDate = date
    }
  }

  var body: some View {
    VStack {
      HStack {
        ModeButton(mode: .departNow, selectedMode: $mode)
        ModeButton(mode: .departAt(date), selectedMode: $mode)
        ModeButton(mode: .arriveBy(date), selectedMode: $mode)
      }
      .padding(.bottom, -16)
      Spacer()
      DatePicker(
        "",
        selection: $date,
        displayedComponents: [.hourAndMinute, .date]
      )
      .datePickerStyle(.wheel)
      .onChange(of: mode) { newValue in
        // Avoid unnecessary UI churn
        guard !oldMode.sameMode(newValue) else {
          return
        }

        print("mode changed")
        oldMode = newValue
        let now = Date.now
        if case .departNow = newValue, now.minutesSince1970 != date.minutesSince1970 {
          date = now
          oldDate = now
        }
      }
      .onChange(of: date) { newValue in
        print("date changed")
        switch mode {
        case .departNow:
          // Avoid Unneccessary UI churn
          guard oldDate.minutesSince1970 != newValue.minutesSince1970 else {
            return
          }
          mode = .departAt(newValue)
        case .departAt(_):
          mode = .departAt(newValue)
        case .arriveBy(_):
          mode = .arriveBy(newValue)
        }
        oldDate = newValue
      }
      Spacer()
    }
  }

  // MARK: Private Views
  struct ModeButton: View {
    var mode: TripDateMode

    @Binding
    var selectedMode: TripDateMode

    var body: some View {
      let button = Button(action: {
        selectedMode = mode
      }) {
        let text =
          switch mode {
          case .arriveBy: "Arrive By"
          case .departAt: "Depart At"
          case .departNow: "Depart Now"
          }
        Text(text)
      }.padding(.horizontal, 8).padding(.vertical, 4)

      if selectedMode.sameMode(mode) {
        button.background(Color.hw_blue).foregroundColor(.white).cornerRadius(4)
      } else {
        button
      }
    }
  }
}

enum TripDateMode: Equatable {
  case departNow
  case departAt(Date)
  case arriveBy(Date)

  func sameMode(_ other: Self) -> Bool {
    switch self {
    case .departNow:
      if case .departNow = other {
        return true
      } else {
        return false
      }
    case .departAt(_):
      if case .departAt(_) = other {
        return true
      } else {
        return false
      }
    case .arriveBy(_):
      if case .arriveBy(_) = other {
        return true
      } else {
        return false
      }
    }
  }
}

extension Date {
  var minutesSince1970: Int {
    Int(self.timeIntervalSince1970 / 60)
  }
}

#Preview("Depart Now") {
  TripDatePicker(mode: .constant(.departNow))
}

#Preview("Depart At") {
  TripDatePicker(mode: .constant(.departAt(Date.now)))
}

#Preview("Arrive By") {
  TripDatePicker(mode: .constant(.arriveBy(Date.now)))
}
