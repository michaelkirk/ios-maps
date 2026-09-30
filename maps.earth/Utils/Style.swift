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
  static let hw_fieldLabel = Color(rgb: 0x5B6167)
  static let hw_searchFieldPlaceholderForeground = Color(rgb: 0x7B7E82)
  static let hw_activeRoute = Color(rgb: 0x1296FF)
  static let hw_inactiveRoute = Color(rgb: 0x6FC1EE)

  // Accents for describing things, clear of the blue that means "selected" and
  // the green that means "go". 50 and 100 are washes to sit type on, 500 is for
  // shapes only, 600 and 700 are ink. See docs/style-guide.html.
  static let hw_teal50 = Color(rgb: 0xE7F9F8)
  static let hw_teal100 = Color(rgb: 0xC5EDEA)
  static let hw_teal500 = Color(rgb: 0x2DA9A1)
  static let hw_teal600 = Color(rgb: 0x218C85)
  static let hw_teal700 = Color(rgb: 0x156660)
  static let hw_amber50 = Color(rgb: 0xFCEED9)
  static let hw_amber100 = Color(rgb: 0xF5DAB2)
  static let hw_amber500 = Color(rgb: 0xD48611)
  static let hw_amber600 = Color(rgb: 0xAD6C0B)
  static let hw_amber700 = Color(rgb: 0x794D0C)

  // Favorite place colors
  static let hw_green = Color(rgb: 0x2ECC40)  // Fresh, vibrant green for Home
  static let hw_red = Color(rgb: 0xE74C3C)  // Warm red for Work
  static let hw_blue = Color(rgb: 0x3498DB)  // Complementary blue for Other

  /// GO's fill: system green's increased-contrast shade.
  static let hw_go = Color(rgb: 0x248A3D)

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

/// A step in the type scale. See docs/style-guide.html#typography.
enum TextRole {
  /// A sheet's name: "Directions", a place's name.
  case title
  /// Names a section or a row: "Favorites", a search result's name.
  case heading
  /// The number a trip row is about: "48 min", "4:05 – 4:52 PM".
  case figure
  case body
  /// Says more about the line above it: a distance, an address.
  case secondary
  /// Small print: sizes, dates, progress.
  case caption
  /// Type on a chip. Its color comes from the chip.
  case label

  var font: Font {
    switch self {
    case .title: .title.bold()
    case .heading: .headline
    case .figure: .title2.bold()
    case .body: .body
    case .secondary: .subheadline
    case .caption: .caption
    case .label: .caption.weight(.semibold)
    }
  }

  var color: Color? {
    switch self {
    case .secondary, .caption: .hw_darkGray
    case .title, .heading, .figure, .body, .label: nil
    }
  }
}

/// The spacing scale. See docs/style-guide.html#spacing.
enum Space {
  static let xs: CGFloat = 4
  static let s: CGFloat = 8
  static let m: CGFloat = 12
  static let l: CGFloat = 16
  static let xl: CGFloat = 24
}

extension View {
  /// Sets the font, and for the quieter roles the color, of a `TextRole`.
  @ViewBuilder
  func hwText(_ role: TextRole) -> some View {
    if let color = role.color {
      self.font(role.font).foregroundStyle(color)
    } else {
      self.font(role.font)
    }
  }

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
