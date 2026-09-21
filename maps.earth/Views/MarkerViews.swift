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

/// A live transit vehicle: the emoji for its kind on a white chip ringed in the route's color,
/// badged with the route it runs.
class TransitVehicleMarkerView: MLNAnnotationView {
  private static let chipSize: CGFloat = 22
  private static let badgeHeight: CGFloat = 13
  /// Where the badge hangs off the chip, relative to the chip's own origin.
  private static let badgeOrigin = CGPoint(x: 14, y: 13)

  var isFaded: Bool {
    didSet {
      self.alpha = isFaded ? 0.35 : 1
    }
  }

  init(vehicle: TransitVehicle, isFaded: Bool) {
    self.isFaded = isFaded
    super.init(reuseIdentifier: nil)
    self.alpha = isFaded ? 0.35 : 1

    let chip = Self.chipView(vehicle: vehicle)
    let badge = vehicle.badge.map { Self.badgeView($0, color: vehicle.color.uiColor) }

    // MapLibre puts the view's center on the coordinate, and it's the chip - not the badge hanging
    // off it - that marks where the vehicle is. So the view is padded to keep the chip concentric
    // with it, which is what lets `centerOffset` stay zero.
    let radius: CGFloat = Self.chipSize / 2
    let badgeCorner: CGPoint =
      badge.map {
        CGPoint(x: Self.badgeOrigin.x + $0.frame.width, y: Self.badgeOrigin.y + $0.frame.height)
      } ?? .zero
    let halfWidth: CGFloat = max(radius, badgeCorner.x - radius)
    let halfHeight: CGFloat = max(radius, badgeCorner.y - radius)
    self.frame = CGRect(x: 0, y: 0, width: halfWidth * 2, height: halfHeight * 2)

    chip.frame.origin = CGPoint(x: halfWidth - radius, y: halfHeight - radius)
    self.addSubview(chip)

    if let badge {
      badge.frame.origin = CGPoint(
        x: chip.frame.minX + Self.badgeOrigin.x, y: chip.frame.minY + Self.badgeOrigin.y)
      self.addSubview(badge)
    }
  }

  /// White so the emoji stays legible over any basemap, ringed in the route's color.
  private static func chipView(vehicle: TransitVehicle) -> UIView {
    let chip = roundedView(
      frame: CGRect(x: 0, y: 0, width: chipSize, height: chipSize),
      borderColor: vehicle.color.uiColor, borderWidth: 2, shadowRadius: 2, shadowOpacity: 0.4)

    let emoji = UILabel(frame: chip.bounds)
    emoji.text = vehicle.emoji
    emoji.font = .systemFont(ofSize: 12)
    emoji.textAlignment = .center
    chip.addSubview(emoji)

    return chip
  }

  /// White with a colored border rather than colored with white text: GTFS route colors run light
  /// (King County Metro's is yellow), so white-on-color can't be relied on to stay readable.
  private static func badgeView(_ text: String, color: UIColor) -> UIView {
    let label = UILabel()
    label.text = text
    label.font = .systemFont(ofSize: 9, weight: .bold)
    label.textAlignment = .center
    label.textColor = UIColor(white: 0.07, alpha: 1)

    let frame = CGRect(
      x: 0, y: 0, width: ceil(label.intrinsicContentSize.width) + 8, height: badgeHeight)
    let badge = roundedView(
      frame: frame, borderColor: color, borderWidth: 1, shadowRadius: 1.5, shadowOpacity: 0.35)

    label.frame = badge.bounds
    badge.addSubview(label)

    return badge
  }

  /// A white pill carrying its own shadow.
  ///
  /// The fill lives on a bare view rather than on the label itself: a label paints its background
  /// into its contents, which `cornerRadius` alone doesn't clip, and clipping the label's layer
  /// would take the shadow with it.
  private static func roundedView(
    frame: CGRect, borderColor: UIColor, borderWidth: CGFloat, shadowRadius: CGFloat,
    shadowOpacity: Float
  ) -> UIView {
    let view = UIView(frame: frame)
    view.backgroundColor = .white
    view.layer.cornerRadius = frame.height / 2
    view.layer.borderColor = borderColor.cgColor
    view.layer.borderWidth = borderWidth
    view.layer.shadowRadius = shadowRadius
    view.layer.shadowOpacity = shadowOpacity
    view.layer.shadowOffset = .zero
    return view
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

/// What a tapped vehicle says: the route it runs, the number painted on it, and how much of the
/// position on screen is reported rather than guessed.
///
/// The system callout stacks a title over a subtitle and aligns both left; the route and the
/// vehicle number belong on one line, with the number trailing, as they read on the web map.
class TransitVehicleCalloutView: UIView, MLNCalloutView {
  /// Between the chip the vehicle is drawn as and the callout above it.
  private static let anchorGap: CGFloat = 6
  /// The narrowest gap between the route and the vehicle number before they read as one phrase.
  private static let columnGap: CGFloat = 16

  var representedObject: any MLNAnnotation
  lazy var leftAccessoryView = UIView()
  lazy var rightAccessoryView = UIView()
  weak var delegate: MLNCalloutViewDelegate?

  /// MapLibre hands us the annotation's anchor - the top center of its marker - and leaves placing
  /// the callout relative to it to us.
  override var center: CGPoint {
    get { super.center }
    set {
      super.center = CGPoint(
        x: newValue.x, y: newValue.y - bounds.height / 2 - Self.anchorGap)
    }
  }

  var isAnchoredToAnnotation: Bool { true }
  var dismissesAutomatically: Bool { false }

  private let routeLabel = UILabel()
  private let vehicleLabel = UILabel()
  private let freshnessLabel = UILabel()

  init(annotation: TransitVehicleAnnotation) {
    self.representedObject = annotation
    super.init(frame: .zero)

    backgroundColor = UIColor(white: 0, alpha: 0.8)
    layer.cornerRadius = 6

    routeLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    routeLabel.textColor = .white

    vehicleLabel.font = .systemFont(ofSize: 12)
    vehicleLabel.textColor = UIColor(white: 1, alpha: 0.75)
    vehicleLabel.textAlignment = .right

    freshnessLabel.font = .systemFont(ofSize: 12)
    freshnessLabel.textColor = UIColor(white: 1, alpha: 0.8)

    for label in [routeLabel, vehicleLabel, freshnessLabel] {
      label.translatesAutoresizingMaskIntoConstraints = false
      addSubview(label)
    }

    // The route is what's being named, so it keeps its width and the vehicle number yields.
    routeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    vehicleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let margin: CGFloat = 8
    NSLayoutConstraint.activate([
      routeLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
      routeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),

      vehicleLabel.firstBaselineAnchor.constraint(equalTo: routeLabel.firstBaselineAnchor),
      vehicleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -margin),
      vehicleLabel.leadingAnchor.constraint(
        greaterThanOrEqualTo: routeLabel.trailingAnchor, constant: Self.columnGap),

      freshnessLabel.topAnchor.constraint(equalTo: routeLabel.bottomAnchor, constant: 2),
      freshnessLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
      freshnessLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: trailingAnchor, constant: -margin),
      freshnessLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func presentCallout(
    from rect: CGRect, in view: UIView, constrainedTo constrainedRect: CGRect, animated: Bool
  ) {
    guard let annotation = representedObject as? TransitVehicleAnnotation else {
      return
    }
    let vehicle = annotation.vehicle
    routeLabel.text = "\(vehicle.emoji) \(vehicle.routeName)"
    vehicleLabel.text = vehicle.labelFormatted
    // How stale a position is keeps changing, so it's phrased as the callout is about to show.
    freshnessLabel.text = vehicle.freshnessFormatted(at: annotation.correctedNow)

    view.addSubview(self)

    var size = systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    size.width = min(size.width, constrainedRect.width)
    bounds = CGRect(origin: .zero, size: size)
    center = CGPoint(x: rect.midX, y: rect.minY)
    // Nudged back inside rather than left hanging off the edge for a vehicle near the map's border.
    frame.origin.x = min(
      max(frame.origin.x, constrainedRect.minX), constrainedRect.maxX - size.width)

    guard animated else { return }
    alpha = 0
    UIView.animate(withDuration: 0.15) { self.alpha = 1 }
  }

  func dismissCallout(animated: Bool) {
    guard superview != nil else { return }
    guard animated else {
      removeFromSuperview()
      return
    }
    UIView.animate(withDuration: 0.15) {
      self.alpha = 0
    } completion: { _ in
      self.removeFromSuperview()
    }
  }
}
