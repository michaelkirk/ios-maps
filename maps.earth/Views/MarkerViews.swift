//
//  StartMarkerView.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/8/24.
//

import Foundation
import MapLibre
import SwiftUI
import UIKit

class StartMarkerView: UIView {
  init() {
    let frame = CGRect(x: 0, y: 0, width: 16, height: 16)
    super.init(frame: frame)
    self.backgroundColor = .white
    self.layer.borderColor = UIColor.black.cgColor
    self.layer.borderWidth = 2
    self.layer.cornerRadius = frame.width / 2
    self.layer.shadowRadius = 2
    self.layer.shadowOpacity = 0.7
    self.layer.shadowOffset = .zero
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class TransferMarkerView: UIView {
  init(isSelected: Bool) {
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    super.init(frame: frame)
    self.backgroundColor = isSelected ? Color.white.uiColor : Color(gray: 0.7).uiColor
    self.layer.borderColor =
      isSelected ? Color.hw_darkGray.cgColor : Color(gray: 0.7).uiColor.cgColor
    self.layer.borderWidth = 2
    self.layer.cornerRadius = frame.width / 2
    // It feels too noisy to show this for unselected routes.
    // I'm leaving the logic to render them in and making them invisible while I try it out for a while.
    self.isHidden = !isSelected
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

/// Labels a step the rider picked, where it happens.
class StepCalloutAnnotation: MLNPointAnnotation {
  init(step: TripPlan.FocusedStep) {
    super.init()
    self.coordinate = step.location.asCoordinate
    // VoiceOver reads this.
    self.title = step.description
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

/// Hosts `StepCallout`, its point on the step.
class StepCalloutView: MLNAnnotationView {
  private let host: UIHostingController<StepCallout>

  init(text: String) {
    self.host = UIHostingController(rootView: StepCallout(text: text))
    super.init(reuseIdentifier: nil)
    host.sizingOptions = .intrinsicContentSize
    host.view.backgroundColor = .clear
    let size = host.view.intrinsicContentSize
    self.frame = CGRect(origin: .zero, size: size)
    host.view.frame = self.bounds
    addSubview(host.view)
    self.centerOffset = CGVector(dx: 0, dy: -size.height / 2)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

/// e.g. "Board the D Line at 3rd Ave & Pine St" in a bubble pointing down at where it happens.
struct StepCallout: View {
  let text: String
  private static let pointerSize: CGFloat = 8

  var body: some View {
    VStack(spacing: 0) {
      Text(text)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.black)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 220)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
      Triangle().fill(.white)
        .frame(width: Self.pointerSize * 2, height: Self.pointerSize)
    }
    .compositingGroup()
    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
  }

  private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
      Path { path in
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
      }
    }
  }
}
