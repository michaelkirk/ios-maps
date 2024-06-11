//
//  CloseButton.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/11/24.
//

import SwiftUI

struct SheetButton: View {
  var action: () -> Void
  var image: Image

  var body: some View {
    Button(action: action) {
      // Copied from ShareLink
      let width: CGFloat = 32
      ZStack {
        Circle().frame(width: width - 2)
        image.resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: width, height: width)
          .tint(.hw_sheetCloseBackground)
      }.tint(Color.hw_sheetCloseForeground)
    }
  }
}

struct CloseButton: View {
  var action: () -> Void

  var body: some View {
    SheetButton(action: action, image: Image(systemName: "xmark.circle.fill"))
  }
}
