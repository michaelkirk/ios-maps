//
//  SteepClimbMarker.swift
//  maps.earth
//

import MapLibre
import SwiftUI
import UIKit

/// Where one of a trip's steepest climbs begins. Tapping it says how steep the climb is.
class SteepClimbAnnotation: MLNPointAnnotation {
  let climb: SteepSection

  init(climb: SteepSection) {
    self.climb = climb
    super.init()
    self.coordinate = climb.coordinates[0]
    // The callout shows this.
    self.title = climb.gradeDescription
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

/// Hosts `SteepClimbPill`, standing just above where the climb begins.
class SteepClimbMarkerView: MLNAnnotationView {
  private let climb: SteepSection
  private let host: UIHostingController<SteepClimbPill>

  var isEmphasized: Bool = false {
    didSet { host.rootView = SteepClimbPill(climb: climb, isEmphasized: isEmphasized) }
  }

  init(climb: SteepSection) {
    self.climb = climb
    self.host = UIHostingController(rootView: SteepClimbPill(climb: climb, isEmphasized: false))
    super.init(reuseIdentifier: nil)
    host.sizingOptions = .intrinsicContentSize
    host.view.backgroundColor = .clear
    let size = host.view.intrinsicContentSize
    self.frame = CGRect(origin: .zero, size: size)
    host.view.frame = self.bounds
    addSubview(host.view)
    self.centerOffset = CGVector(dx: 0, dy: -size.height / 2 - 2)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

/// e.g. "9% ↗" on a pill in the climb's steepness color.
struct SteepClimbPill: View {
  let climb: SteepSection
  let isEmphasized: Bool

  var body: some View {
    (Text("\(climb.percent)").font(.system(size: 11, weight: .bold))
      + Text("%").font(.system(size: 8, weight: .bold))
      + Text("↗").font(.system(size: 11, weight: .bold)))
      .foregroundStyle(.white)
      // keeps white legible on the lighter grades
      .shadow(color: .black.opacity(0.45), radius: 1)
      .padding(.horizontal, 5)
      .padding(.vertical, 1)
      .background(Capsule().fill(climb.shade.color))
      .overlay(Capsule().stroke(.white, lineWidth: 1))
      .shadow(
        color: .black.opacity(isEmphasized ? 0.6 : 0.3), radius: isEmphasized ? 4 : 1,
        y: isEmphasized ? 0 : 1)
  }
}

/// Where the elevation chart's scrubber is along the selected trip.
class ElevationScrubberAnnotation: MLNPointAnnotation {}

/// The scrubber's dot, which the rider can drag along the route.
class ElevationScrubberView: MLNAnnotationView {
  /// Called with where the rider has dragged the dot to, for the caller to snap onto the route.
  var onDrag: (CLLocationCoordinate2D) -> Void = { _ in }

  init() {
    super.init(reuseIdentifier: nil)
    let diameter: CGFloat = 10
    // A bigger target than the dot, so it's easy to grab.
    self.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
    let dot = UIView(
      frame: CGRect(
        x: (32 - diameter) / 2, y: (32 - diameter) / 2, width: diameter, height: diameter))
    dot.backgroundColor = .white
    dot.layer.cornerRadius = diameter / 2
    dot.layer.borderWidth = 2
    dot.layer.borderColor = UIColor(white: 0.07, alpha: 1).cgColor
    dot.isUserInteractionEnabled = false
    addSubview(dot)
    addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPan)))
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private var mapView: MLNMapView? {
    sequence(first: superview, next: { $0?.superview }).compactMap { $0 as? MLNMapView }.first
  }

  @objc private func didPan(_ gesture: UIPanGestureRecognizer) {
    guard let mapView else {
      return
    }
    switch gesture.state {
    case .began:
      // The dot moves rather than the map.
      mapView.isScrollEnabled = false
    case .ended, .cancelled, .failed:
      mapView.isScrollEnabled = true
      return
    default:
      break
    }
    let point = gesture.location(in: mapView)
    onDrag(mapView.convert(point, toCoordinateFrom: mapView))
  }
}
