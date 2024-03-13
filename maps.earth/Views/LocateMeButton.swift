//
//  LocateMeButton.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/12/24.
//

import SwiftUI

struct LocateMeButton: View {
  static let height: CGFloat = 38

  @Binding var state: UserLocationState
  @Binding var pendingRecenter: PendingRecenter?

  var systemImageName: String {
    switch self.state {
    case .initial, .showing:
      return "location"
    //    case .following:
    //      return "location.fill"
    case .denied:
      return "location.slash"
    }
  }

  var body: some View {
    Button(action: {
      self.tapped()
      print("tapped LocateMe. new state: \(self.state)")
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
    let oldState = self.state
    switch self.state {
    case .initial, .showing:
      self.state = .showing
      self.pendingRecenter = .pending
    case .denied:
      self.state = .denied
    }
    print("tapped. \(oldState) -> \(self.state)")
  }
}

enum LocateMeButtonState {
  case neverAsked
  case pending
  case showing
  case denied
}

#Preview("initial/on") {
  LocateMeButton(state: .constant(.initial), pendingRecenter: .constant(nil))
}

//#Preview("following") {
//  LocateMeButton(state: .constant(.following), pendingRecenter: .constant(nil))
//}

#Preview("denied") {
  LocateMeButton(state: .constant(.denied), pendingRecenter: .constant(nil))
}
