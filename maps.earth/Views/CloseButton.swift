//
//  CloseButton.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/11/24.
//

import SwiftUI

struct CloseButton: View {
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      let width: CGFloat = 32
      ZStack {
        Circle().frame(width: width - 2)
        Image(systemName: "xmark.circle.fill").resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: width, height: width)
          .tint(.hw_sheetCloseBackground)
      }
    }
    .tint(Color.hw_sheetCloseForeground)
  }
}
