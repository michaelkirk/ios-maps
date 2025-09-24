//
//  Style.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/7/24.
//

import Foundation
import SwiftUI

extension Color {
  init?(hexString: String) {
    guard hexString.count == 6 else {
      assertionFailure("Invalid hex string length")
      return nil
    }

    guard let rgb = UInt64(hexString, radix: 16) else {
      assertionFailure("Invalid hex string")
      return nil
    }

    self.init(rgb: rgb)
  }

  init(rgb: UInt64) {
    let red = Double((rgb & 0xFF0000) >> 16) / 0xFF
    let green = Double((rgb & 0x00FF00) >> 8) / 0xFF
    let blue = Double((rgb & 0x0000FF) >> 0) / 0xFF

    self.init(red: red, green: green, blue: blue)
  }
  init(gray: CGFloat) {
    self.init(red: gray, green: gray, blue: gray)
  }
}

// Color Palette
extension Color {
  static let hw_darkGray = Color(gray: 0.5)
  static let hw_lightGray = Color(gray: 0.90)
  static let hw_offWhite = Color(gray: 0.95)
  static let hw_sheetCloseForeground = Color(rgb: 0x808084)
  static let hw_sheetCloseBackground = Color(rgb: 0xE8E8E8)
  static let hw_sheetBackground = Color(rgb: 0xE8F0F4)
  static let hw_searchFieldBackground = Color(rgb: 0xD9E1E8)
  static let hw_searchFieldPlaceholderForeground = Color(rgb: 0x7B7E82)
  static let hw_activeRoute = Color(rgb: 0x1296FF)
  static let hw_inactiveRoute = Color(rgb: 0x6FC1EE)

  // Favorite place colors
  static let hw_green = Color(rgb: 0x2ECC40)  // Fresh, vibrant green for Home
  static let hw_red = Color(rgb: 0xE74C3C)  // Warm red for Work
  static let hw_blue = Color(rgb: 0x3498DB)  // Complementary blue for Other

  var uiColor: UIColor {
    UIColor(self)
  }
}

struct Swatch: View {
  let color: Color
  var body: some View {
    Spacer()
      .frame(width: 20, height: 20)
      .background(color)
  }
}

struct ColorPalette: View {
  var body: some View {
    let rows = [Color.white, Color.hw_offWhite, .hw_lightGray, .hw_darkGray, .black].map {
      background in
      HStack(spacing: 16) {
        Swatch(color: .black)
        Swatch(color: .hw_darkGray)
        Swatch(color: .hw_lightGray)
        Swatch(color: .hw_offWhite)
        Swatch(color: .white)
      }.padding()
        .background(background)
    }

    // This seems like a dumb way to do it, but whatever
    VStack {
      rows[0]
      rows[1]
      rows[2]
      rows[3]
      rows[4]
    }
  }
}

extension View {
  @ViewBuilder
  public func hwListStyle() -> some View {
    self.listStyle(.plain)
      // some padding after the last element *before* background is applied,
      // so this padding will be white
      .scenePadding(.bottom)
      .background(Color.white)
      .cornerRadius(16)
      // lateral padding is applied outside of the background color - i.e. it'll be "sheet" colored
      .scenePadding(.leading)
      .scenePadding(.trailing)
      .scenePadding(.top)
  }
}

#Preview("Color Pallete") {
  ColorPalette()
}
