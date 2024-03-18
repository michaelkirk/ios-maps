//
//  LocateMeButton.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/12/24.
//

import OSLog
import SwiftUI

private let logger = Logger(
  subsystem: Bundle.main.bundleIdentifier!,
  category: String(describing: #file)
)

struct LocateMeButton: View {
  static let height: CGFloat = 38

  @Binding var state: UserLocationState
  @Binding var pendingMapFocus: MapFocus?

  var systemImageName: String {
    switch self.state {
    case .initial, .showing:
      return "location"
    case .following:
      return "location.fill"
    case .denied:
      return "location.slash"
    }
  }

  var body: some View {
    Button(action: {
      self.tapped()
    }) {
      Image(systemName: self.systemImageName)
        .imageScale(.large)
        .tint(Color.hw_sheetCloseForeground)
    }.frame(width: Self.height, height: Self.height)
      .background(Color.hw_sheetBackground)
      .cornerRadius(8)
      .shadow(radius: 3)
      // FIXME (minor): A "disabled" button makes sense for this state, but it means that taps "pass through" so if a confused
      // user repeatedly taps the disabled button the map will zoom in.
      .disabled(state == .denied)
  }

  func tapped() {
    let newState: UserLocationState
    switch self.state {
    case .initial:
      newState = .showing
      self.pendingMapFocus = .userLocation
    case .showing:
      newState = .following
      self.pendingMapFocus = .userLocation
    case .following:
      newState = .showing
      self.pendingMapFocus = .userLocation
    case .denied:
      newState = .denied
    }
    logger.debug("tapped LocateMeButton with state \(state) -> \(newState)")
    self.state = newState
  }
}

enum LocateMeButtonState {
  case neverAsked
  case pending
  case showing
  case denied
}

#Preview("initial/on") {
  LocateMeButton(state: .constant(.initial), pendingMapFocus: .constant(nil))
}

#Preview("following") {
  LocateMeButton(state: .constant(.following), pendingMapFocus: .constant(nil))
}

#Preview("denied") {
  LocateMeButton(state: .constant(.denied), pendingMapFocus: .constant(nil))
}
