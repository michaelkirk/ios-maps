//
//  Style.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/7/24.
//

import Foundation
import SwiftUI

extension Color {
  static func rgb(_ value: UInt64) -> Self {
    let red = Double(value & 0xFF0000 >> 16) / 0xFF
    let green = Double(value & 0x00FF00 >> 8) / 0xFF
    let blue = Double(value & 0x0000FF >> 0) / 0xFF
    return Self(red: red, green: green, blue: blue)
  }
  static func gray(_ value: CGFloat) -> Self {
    return Self(red: value, green: value, blue: value)
  }
}

// Color Palette
extension Color {
  static let hw_lightGray = Color.gray(0.90)
  static let hw_offWhite = Color.gray(0.95)
}
