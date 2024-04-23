//
//  SwiftUIView.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/23/24.
//

import SwiftUI

struct RoundedCorner: Shape {
  var radius: CGFloat = .infinity
  var corners: UIRectCorner = .allCorners

  func path(in rect: CGRect) -> Path {
    let path = UIBezierPath(
      roundedRect: rect, byRoundingCorners: corners,
      cornerRadii: CGSize(width: radius, height: radius))
    return Path(path.cgPath)
  }
}

extension View {
  func roundedBorder(
    _ borderColor: Color, borderWidth: CGFloat = 1.0, cornerRadius: CGFloat,
    corners: UIRectCorner = .allCorners
  ) -> some View {
    clipShape(RoundedCorner(radius: cornerRadius, corners: corners))
      .overlay(
        RoundedCorner(radius: cornerRadius, corners: corners)
          .stroke(borderColor, lineWidth: borderWidth))
  }
}

#Preview("With roundedCornerBorders") {
  let basic = Text("foo").padding().background(.yellow)
  return VStack {
    basic.roundedBorder(.black, borderWidth: 2, cornerRadius: 12)
    basic.border(.black, width: 2)
    basic
  }
}
