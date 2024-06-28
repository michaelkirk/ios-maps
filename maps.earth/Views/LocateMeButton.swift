//
//  LocateMeButton.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/12/24.
//

import SwiftUI

private let logger = FileLogger()

struct LocateMeButton: View {
  @Binding var pendingMapFocus: MapFocus?
  @EnvironmentObject var userLocationManager: UserLocationManager

  var systemImageName: String {
    switch self.userLocationManager.state {
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
    }
    // FIXME (minor): A "disabled" button makes sense for this state, but it means that taps "pass through" so if a confused
    // user repeatedly taps the disabled button the map will zoom in.
    .disabled(userLocationManager.state == .denied)
  }

  func tapped() {
    let newState: UserLocationState
    switch self.userLocationManager.state {
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
    logger.debug("tapped LocateMeButton with state \(userLocationManager.state) -> \(newState)")
    self.userLocationManager.state = newState
  }
}

#Preview("initial/on") {
  let userLocationManager = UserLocationManager()
  userLocationManager.state = .initial
  return LocateMeButton(pendingMapFocus: .constant(nil))
    .environmentObject(userLocationManager)
}

#Preview("following") {
  let userLocationManager = UserLocationManager()
  userLocationManager.state = .following
  return LocateMeButton(pendingMapFocus: .constant(nil))
    .environmentObject(userLocationManager)
}

#Preview("denied") {
  let userLocationManager = UserLocationManager()
  userLocationManager.state = .denied
  return LocateMeButton(pendingMapFocus: .constant(nil))
    .environmentObject(userLocationManager)
}
