//
//  TransitVehicleMarker.swift
//  maps.earth
//
//  Created by Michael Kirk on 10/2/26.
//

import Foundation
import MapLibre
import SwiftUI
import UIKit

/// Hosts `TransitVehicleMarker` as the annotation view MapLibre draws for a vehicle.
class TransitVehicleMarkerView: MLNAnnotationView {
  private let vehicle: TransitVehicle
  private let host: UIHostingController<TransitVehicleMarker>

  var isFaded: Bool {
    didSet { host.rootView = marker }
  }

  private var marker: TransitVehicleMarker {
    TransitVehicleMarker(vehicle: vehicle, isFaded: isFaded, isSelected: isSelected)
  }

  init(vehicle: TransitVehicle, isFaded: Bool) {
    self.vehicle = vehicle
    self.isFaded = isFaded
    self.host = UIHostingController(
      rootView: TransitVehicleMarker(vehicle: vehicle, isFaded: isFaded, isSelected: false))
    super.init(reuseIdentifier: nil)

    host.sizingOptions = .intrinsicContentSize
    host.view.backgroundColor = .clear
    let content = host.view.intrinsicContentSize

    // MapLibre puts the view's center on the coordinate, and it's the chip - not the badge hanging
    // off it - that marks where the vehicle is. So the view is padded to keep the chip concentric
    // with it, which is what lets `centerOffset` stay zero.
    let radius = TransitVehicleMarker.chipSize / 2
    let halfWidth = max(radius, content.width - radius)
    let halfHeight = max(radius, content.height - radius)
    self.frame = CGRect(x: 0, y: 0, width: halfWidth * 2, height: halfHeight * 2)
    host.view.frame = CGRect(
      origin: CGPoint(x: halfWidth - radius, y: halfHeight - radius), size: content)
    addSubview(host.view)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
    host.rootView = marker
  }
}

/// A live transit vehicle: the emoji for its kind on a white chip ringed in the route's color,
/// badged with the route it runs.
struct TransitVehicleMarker: View {
  static let chipSize: CGFloat = 22
  private static let badgeHeight: CGFloat = 13
  /// Where the badge hangs off the chip, relative to the chip's own origin.
  private static let badgeOrigin = CGPoint(x: 14, y: 13)
  private static let ringWidth: CGFloat = 2
  /// How much thicker the ring is drawn on the vehicle whose callout is being read.
  private static let selectedRingGrowth: CGFloat = 2

  let vehicle: TransitVehicle
  let isFaded: Bool
  let isSelected: Bool

  var body: some View {
    ZStack(alignment: .topLeading) {
      chip
      if let badge = vehicle.badge {
        badgeView(badge)
          .padding(.leading, Self.badgeOrigin.x)
          .padding(.top, Self.badgeOrigin.y)
      }
    }
    .compositingGroup()
    .opacity(isFaded ? 0.35 : 1)
  }

  /// White so the emoji stays legible over any basemap, ringed in the route's color. The ring
  /// thickens outwards when selected, so the emoji inside keeps its size.
  private var chip: some View {
    let growth = isSelected ? Self.selectedRingGrowth : 0
    return Text(vehicle.emoji)
      .font(.system(size: 12))
      .frame(width: Self.chipSize, height: Self.chipSize)
      .background {
        Circle()
          .fill(.white)
          .overlay(Circle().strokeBorder(vehicle.color, lineWidth: Self.ringWidth + growth))
          .padding(-growth)
          .shadow(color: .black.opacity(0.4), radius: 2)
      }
  }

  /// White with a colored border rather than colored with white text: GTFS route colors run light
  /// (King County Metro's is yellow), so white-on-color can't be relied on to stay readable.
  private func badgeView(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 9, weight: .bold))
      .foregroundStyle(Color(white: 0.07))
      .padding(.horizontal, 4)
      .frame(height: Self.badgeHeight)
      .background {
        Capsule()
          .fill(.white)
          .overlay(Capsule().strokeBorder(vehicle.color, lineWidth: 1))
          .shadow(color: .black.opacity(0.35), radius: 1.5)
      }
      .fixedSize()
  }
}

#Preview("Vehicle markers") {
  let reported = Date.now
  HStack(spacing: 24) {
    TransitVehicleMarker(
      vehicle: .fixture(lastUpdated: reported, boardingStop: nil), isFaded: false,
      isSelected: false)
    TransitVehicleMarker(
      vehicle: .fixture(lastUpdated: reported, boardingStop: nil), isFaded: false,
      isSelected: true)
    TransitVehicleMarker(
      vehicle: .fixture(lastUpdated: reported, boardingStop: nil), isFaded: true,
      isSelected: false)
    TransitVehicleMarker(
      vehicle: .fixture(
        route: TransitRoute(shortName: "RapidRide E", longName: nil, color: "B6111B"),
        lastUpdated: reported, boardingStop: nil),
      isFaded: false, isSelected: false)
    TransitVehicleMarker(
      vehicle: .fixture(
        route: TransitRoute(shortName: nil, longName: "1 Line", color: "28813F"), mode: .subway,
        label: nil, lastUpdated: reported, boardingStop: nil),
      isFaded: false, isSelected: false)
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color(white: 0.9))
}

/// Hosts `TransitVehicleCallout` as the callout MapLibre shows over a tapped vehicle.
class TransitVehicleCalloutView: UIView, MLNCalloutView {
  /// Between the chip the vehicle is drawn as and the callout above it.
  private static let anchorGap: CGFloat = 6

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

  private let host: UIHostingController<TickingTransitVehicleCallout>

  init(annotation: TransitVehicleAnnotation) {
    self.representedObject = annotation
    self.host = UIHostingController(rootView: TickingTransitVehicleCallout(annotation: annotation))
    super.init(frame: .zero)
    annotation.callout = self

    host.sizingOptions = .intrinsicContentSize
    host.view.backgroundColor = .clear
    host.view.frame = bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(host.view)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func presentCallout(
    from rect: CGRect, in view: UIView, constrainedTo constrainedRect: CGRect, animated: Bool
  ) {
    view.addSubview(self)

    var size = host.view.intrinsicContentSize
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

/// Re-reads the annotation once a second, so the wait and freshness keep counting and a fresh
/// poll shows up in a callout that's already open.
struct TickingTransitVehicleCallout: View {
  let annotation: TransitVehicleAnnotation

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { _ in
      TransitVehicleCallout(vehicle: annotation.vehicle, now: annotation.correctedNow)
    }
  }
}

/// What a tapped vehicle says: the route it runs, the number painted on it, when it reaches the
/// rider's stop, and how much of the position on screen is reported rather than guessed.
struct TransitVehicleCallout: View {
  /// The narrowest gap between the two sides of a row before they read as one phrase.
  private static let columnGap: CGFloat = 16

  let vehicle: TransitVehicle
  let now: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .bottom, spacing: 0) {
        // The route is what's being named, so it keeps its width and the vehicle number yields.
        TransitVehicleMarker(vehicle: vehicle, isFaded: false, isSelected: false)
        Spacer(minLength: Self.columnGap)
        if let label = vehicle.labelFormatted {
          Text(label)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.75))
        }
      }
      if let row = vehicle.boardingStopRow(at: now) {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
          if let text = row.text {
            Text(text).font(.system(size: 13, weight: .semibold))
          }
          Spacer(minLength: Self.columnGap)
          // The wait is the thing a rider is reading for, so it's the phrase beside it that yields.
          if let countdown = row.countdown {
            Self.countdownView(countdown).layoutPriority(1)
          }
        }
      }
      Text(vehicle.freshnessFormatted(at: now))
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(0.8))
    }
    .lineLimit(1)
    .foregroundStyle(.white)
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
  }

  /// The countdown, with its unit set small enough to read as an aside to the number, badged with
  /// the glyph the trip list uses to mark a realtime departure.
  private static func countdownView(_ countdown: Countdown) -> some View {
    HStack(alignment: .lastTextBaseline, spacing: 1) {
      Text(countdown.value).font(.system(size: 17, weight: .semibold))
      VStack(alignment: .leading, spacing: -2) {
        Image(systemName: "dot.radiowaves.up.forward").font(.system(size: 6, weight: .semibold))
        Text(countdown.unit).font(.system(size: 9))
      }
      .foregroundStyle(.white.opacity(0.75))
    }
  }
}

#Preview("Vehicle callouts") {
  let now = Date.now
  let reported = now.addingTimeInterval(-20)
  let vehicles: [TransitVehicle] = [
    .fixture(
      lastUpdated: reported,
      boardingStop: .approaching(
        arrival: now + 5 * 60, stopArrivals: [now + 60, now + 3 * 60, now + 5 * 60])),
    .fixture(
      lastUpdated: reported.addingTimeInterval(-200), boardingStop: .approaching(arrival: now + 90, stopArrivals: [now + 90])
    ),
    .fixture(
      lastUpdated: reported, boardingStop: .approaching(arrival: now + 75 * 60, stopArrivals: [])),
    .fixture(
      lastUpdated: reported, boardingStop: .approaching(arrival: now + 10, stopArrivals: [])),
    .fixture(lastUpdated: reported, boardingStop: .departed(arrival: now - 90)),
    .fixture(lastUpdated: reported, isEstimated: true, boardingStop: nil),
    .fixture(
      route: TransitRoute(shortName: nil, longName: "1 Line", color: "28813F"), mode: .subway,
      label: nil, lastUpdated: reported, boardingStop: nil),
  ]
  VStack(spacing: 12) {
    ForEach(vehicles.indices, id: \.self) { idx in
      TransitVehicleCallout(vehicle: vehicles[idx], now: now).fixedSize()
    }
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color(white: 0.9))
}
