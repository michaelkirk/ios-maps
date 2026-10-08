import SwiftUI

/// A walking or cycling leg's elevation, colored by grade, with its steepest climbs labeled and a
/// scrubber shared with the map.
struct ElevationChart: View {
  let elevation: LegElevation
  /// How far along the leg the scrubber is, as a fraction, or nil when it's hidden.
  @Binding var scrubFraction: Double?
  /// Whether the rider can scrub the chart and pick its climbs.
  var isInteractive: Bool = true
  var onSelectClimb: (SteepSection) -> Void = { _ in }

  var body: some View {
    GeometryReader { geometry in
      let layout = ElevationChartLayout(elevation: elevation, size: geometry.size)
      ZStack(alignment: .topLeading) {
        layout.areaPath.fill(
          LinearGradient(
            colors: [Color.hw_flatGrade.opacity(0.3), Color.hw_flatGrade.opacity(0.1)],
            startPoint: .top, endPoint: .bottom))

        if let scrubPoint = layout.point(atFraction: scrubFraction) {
          Path { path in
            path.move(to: CGPoint(x: scrubPoint.x, y: 0))
            path.addLine(to: CGPoint(x: scrubPoint.x, y: geometry.size.height))
          }.stroke(Color.black.opacity(0.25), lineWidth: 1)
        }

        layout.linePath.stroke(Color.hw_flatGrade, lineWidth: 1.5)
        ForEach(elevation.steepSections, id: \.self) { section in
          layout.path(along: section).stroke(
            section.shade.color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }

        ForEach(elevation.annotatedClimbs, id: \.self) { climb in
          climbLabel(climb, layout: layout)
        }

        if let scrubPoint = layout.point(atFraction: scrubFraction) {
          Circle().fill(.white).overlay(Circle().stroke(Color(white: 0.07), lineWidth: 2))
            .frame(width: 10, height: 10)
            .position(scrubPoint)
            .allowsHitTesting(false)
        }
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { value in
          scrubFraction = min(max(value.location.x / geometry.size.width, 0), 1)
        }, including: isInteractive ? .all : .none)
    }
  }

  /// e.g. "7% ↗", just above where selecting the climb puts the scrubber's dot. It reaches back over
  /// the lower part of the climb, unless that runs off the chart.
  private func climbLabel(_ climb: SteepSection, layout: ElevationChartLayout) -> some View {
    let labelWidth: CGFloat = 32
    // the label ends just past the dot's center, so its arrow sits over the dot
    let overhang: CGFloat = 4
    let dotRadius: CGFloat = 5
    let capHeight: CGFloat = 7
    let mid = layout.point(atFraction: elevation.midpointFraction(of: climb))!
    let fitsLeft = mid.x + overhang - labelWidth >= 0
    let number = Text("\(climb.percent)").font(.system(size: 10, weight: .bold))
    let percentSign = Text("%").font(.system(size: 7, weight: .bold))
    let arrow = Text("↗").font(.system(size: 10, weight: .bold))
    let label =
      fitsLeft
      ? number + percentSign + Text(" ") + arrow
      : arrow + Text(" ") + number + percentSign
    return Color.clear.frame(width: 0, height: 0)
      .overlay(alignment: fitsLeft ? .bottomTrailing : .bottomLeading) {
        label.foregroundStyle(Color.hw_climb)
          .fixedSize()
          .shadow(color: .white, radius: 0.5)
          .shadow(color: .white, radius: 0.5)
          .onTapGesture { onSelectClimb(climb) }
          .accessibilityLabel(climb.gradeDescription)
          .accessibilityAddTraits(.isButton)
      }
      .position(
        x: fitsLeft ? mid.x + overhang : mid.x - overhang,
        y: max(mid.y - dotRadius - 2, capHeight)
      )
      .allowsHitTesting(isInteractive)
  }
}

/// Where a leg's elevation profile lands in a chart of `size`.
struct ElevationChartLayout {
  let elevation: LegElevation
  let size: CGSize
  /// `(x, y)` for each profile point
  let points: [CGPoint]

  init(elevation: LegElevation, size: CGSize) {
    self.elevation = elevation
    self.size = size
    // Room for the scrubber's dot at the highest point.
    let lineTop: CGFloat = 6
    let lineBottom = size.height - 4
    let profile = elevation.profile
    let startDistance = profile.first!.distance
    let totalDistance = profile.last!.distance - startDistance
    let elevations = profile.map(\.elevation)
    let minElevation = elevations.min()!
    let elevationRange = elevations.max()! - minElevation
    self.points = profile.map { point in
      let normalized =
        elevationRange == 0 ? 0.5 : (point.elevation - minElevation) / elevationRange
      return CGPoint(
        x: (point.distance - startDistance) / totalDistance * size.width,
        y: lineBottom - normalized * (lineBottom - lineTop))
    }
  }

  var linePath: Path {
    Path { path in path.addLines(points) }
  }

  var areaPath: Path {
    Path { path in
      path.move(to: CGPoint(x: 0, y: size.height))
      // Not `addLines`, which would start a new subpath at the first point, leaving the fill to
      // close across the profile rather than along the bottom.
      for point in points {
        path.addLine(to: point)
      }
      path.addLine(to: CGPoint(x: size.width, y: size.height))
      path.closeSubpath()
    }
  }

  /// The line along `section`.
  func path(along section: SteepSection) -> Path {
    let along = zip(elevation.profile, points).filter { point, _ in
      point.distance >= section.startMeters && point.distance <= section.endMeters
    }.map { $1 }
    return Path { path in path.addLines(along) }
  }

  /// The point on the line `fraction` of the way across.
  func point(atFraction fraction: Double?) -> CGPoint? {
    guard let fraction else {
      return nil
    }
    let points = self.points
    let x = fraction * size.width
    guard let after = points.firstIndex(where: { $0.x >= x }), after > 0 else {
      return points.first { $0.x >= x } ?? points.last
    }
    let (p0, p1) = (points[after - 1], points[after])
    let t = p1.x == p0.x ? 0 : (x - p0.x) / (p1.x - p0.x)
    return CGPoint(x: x, y: p0.y + t * (p1.y - p0.y))
  }
}

/// How far a leg climbs and descends in all, e.g. "↗ 120 ft ↘ 80 ft".
struct ElevationTotals: View {
  let trip: Trip
  let elevation: LegElevation
  var fontSize: CGFloat = 11

  var body: some View {
    HStack(spacing: 8) {
      if elevation.totalClimbMeters > 0 {
        Text("↗ \(trip.formatFeetOrMeters(meters: elevation.totalClimbMeters))")
          .foregroundStyle(Color.hw_climb)
      }
      if elevation.totalFallMeters > 0 {
        Text("↘ \(trip.formatFeetOrMeters(meters: elevation.totalFallMeters))")
          .foregroundStyle(Color.hw_fall)
      }
    }.font(.system(size: fontSize, weight: .medium))
  }
}

#Preview("Elevation chart") {
  let trip = FixtureData.bikeGradeTrips[0]
  return VStack(alignment: .leading, spacing: 0) {
    ElevationChart(elevation: trip.elevation!, scrubFraction: .constant(0.3)).frame(height: 100)
    ElevationTotals(trip: trip, elevation: trip.elevation!)
  }.padding()
}
