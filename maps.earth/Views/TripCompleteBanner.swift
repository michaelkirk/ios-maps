//
//  TripCompleteBanner.swift
//  maps.earth
//
//  Created by Michael Kirk on 5/14/25.
//

import FerrostarSwiftUI
import Foundation
import SwiftUI

public struct TripCompleteBanner: View {
  let theme: any TripProgressViewTheme
  let onTapExit: (() -> Void)?
  let destinationName: String?

  /// Initialize the ArrivalView
  ///
  /// - Parameters:
  ///   - theme: The arrival view theme.
  ///   - onTapExit: The action to run when the exit button is tapped.
  public init(
    theme: any TripProgressViewTheme = DefaultTripProgressViewTheme(),
    destinationName: String?,
    onTapExit: (() -> Void)? = nil
  ) {
    self.theme = theme
    self.destinationName = destinationName
    self.onTapExit = onTapExit
  }

  public var body: some View {
    HStack {
      Spacer()
      VStack(spacing: 16) {
        if let destinationName {
          Text("You have arrived!").font(.headline)
          Text(destinationName).font(.title)
        } else {
          Text("You have arrived at your destination.").font(.headline)
        }
        if let onTapExit {
          Button(action: onTapExit) {
            Text("End Navigation")
          }.padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(.red)  // TODO: theme
            .cornerRadius( /*@START_MENU_TOKEN@*/3.0 /*@END_MENU_TOKEN@*/)
            .foregroundColor(.white)  // TODO: theme
        }
      }
      Spacer()
    }
    .padding()
    .background(theme.backgroundColor)
    .cornerRadius(16.0)
    .shadow(radius: 12)
  }
}
