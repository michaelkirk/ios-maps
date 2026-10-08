//
//  Grade.swift
//  maps.earth
//

import CoreLocation
import SwiftUI

/// How hilly a walking or cycling leg is.
struct LegElevation: Decodable, Equatable {
  /// Meters above sea level, by meters along the leg.
  let profile: [ProfilePoint]
  let totalClimbMeters: Double
  let totalFallMeters: Double
  let steepSections: [SteepSection]

  struct ProfilePoint: Decodable, Equatable {
    let distance: Double
    let elevation: Double

    init(distance: Double, elevation: Double) {
      self.distance = distance
      self.elevation = elevation
    }

    /// travelmux sends each point as `[distance, elevation]`.
    init(from decoder: Decoder) throws {
      var container = try decoder.unkeyedContainer()
      self.distance = try container.decode(Double.self)
      self.elevation = try container.decode(Double.self)
    }
  }

  var climbs: [SteepSection] {
    steepSections.filter { $0.isClimb }
  }

  /// The steepest few climbs, spread out enough that their labels don't crowd each other.
  var annotatedClimbs: [SteepSection] {
    let maxAnnotated = 3
    let minSpacingMeters = 100.0
    var annotated: [SteepSection] = []
    for climb in climbs.sorted(by: { $0.averageGrade > $1.averageGrade }) {
      if annotated.count == maxAnnotated {
        break
      }
      let isSpacedOut = annotated.allSatisfy { other in
        max(climb.startMeters - other.endMeters, other.startMeters - climb.endMeters)
          >= minSpacingMeters
      }
      if isSpacedOut {
        annotated.append(climb)
      }
    }
    return annotated
  }

  /// How far along the profile the middle of `section` is, as a fraction.
  func midpointFraction(of section: SteepSection) -> Double {
    let start = profile.first!.distance
    let end = profile.last!.distance
    return ((section.startMeters + section.endMeters) / 2 - start) / (end - start)
  }
}

extension LegElevation {
  private enum CodingKeys: String, CodingKey {
    case profile
    case totalClimbMeters
    case totalFallMeters
    case steepSections
  }

  /// Drops any steep section without a line to draw, which travelmux can send when it can't place
  /// a section along the leg.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      profile: try container.decode([ProfilePoint].self, forKey: .profile),
      totalClimbMeters: try container.decode(Double.self, forKey: .totalClimbMeters),
      totalFallMeters: try container.decode(Double.self, forKey: .totalFallMeters),
      steepSections: try container.decode([SteepSection].self, forKey: .steepSections)
        .filter { $0.coordinates.count >= 2 })
  }
}

/// A stretch of a leg that climbs or descends at 5% or more.
struct SteepSection: Decodable, Hashable {
  let startMeters: Double
  let endMeters: Double
  /// Rise over run: positive climbs, negative descends.
  let averageGrade: Double
  let maxGrade: Double
  let streetName: String?
  /// encoded polyline, 1e-6 scale
  let geometry: String

  var isClimb: Bool {
    averageGrade > 0
  }

  var coordinates: [CLLocationCoordinate2D] {
    decodePolyline(geometry, precision: 6)
  }

  var tier: GradeTier {
    GradeTier(grade: averageGrade)
  }

  var shade: GradeShade {
    GradeShade(grade: averageGrade)
  }

  /// e.g. 12 for a 12% grade, climbing or descending.
  var percent: Int {
    Int((abs(averageGrade) * 100).rounded())
  }

  /// e.g. "12% steep grade"
  var gradeDescription: String {
    "\(percent)% \(tier.name) grade"
  }
}

enum GradeTier {
  case moderate
  case steep
  case verySteep

  init(grade: Double) {
    let steepness = abs(grade)
    if steepness >= 0.13 {
      self = .verySteep
    } else if steepness >= 0.09 {
      self = .steep
    } else {
      self = .moderate
    }
  }

  var name: String {
    switch self {
    case .moderate: "moderate"
    case .steep: "steep"
    case .verySteep: "very steep"
    }
  }
}

/// How a steep stretch is drawn: climbs in warm colors and descents in deep greens, by how steep.
enum GradeShade: String, CaseIterable {
  case moderateClimb
  case steepClimb
  case verySteepClimb
  case moderateDescent
  case steepDescent

  init(grade: Double) {
    let tier = GradeTier(grade: grade)
    if grade < 0 {
      self = tier == .moderate ? .moderateDescent : .steepDescent
      return
    }
    switch tier {
    case .moderate: self = .moderateClimb
    case .steep: self = .steepClimb
    case .verySteep: self = .verySteepClimb
    }
  }

  var color: Color {
    switch self {
    case .moderateClimb: Color(rgb: 0xF2B705)
    case .steepClimb: Color(rgb: 0xF27405)
    case .verySteepClimb: Color(rgb: 0xD92B04)
    case .moderateDescent: Color(rgb: 0x2E7D32)
    case .steepDescent: Color(rgb: 0x1B5E20)
    }
  }
}

extension Color {
  /// Ground that isn't steep enough to be a `SteepSection`.
  static let hw_flatGrade = Color(rgb: 0x43A047)
  /// Climbing: the total climbed, and each steep climb's label on the elevation chart.
  static let hw_climb = Color(rgb: 0xE53E3E)
  static let hw_fall = Color(rgb: 0x3182CE)
}
