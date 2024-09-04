//
//  MLNBounds+Extensions.swift
//  maps.earth
//
//  Created by Michael Kirk on 9/4/24.
//

import Foundation
import MapLibre

extension MLNCoordinateBounds {
  func extend(bufferMeters: Float64) -> MLNCoordinateBounds {
    let earthRadius = 6378137.0  // Earth's radius in meters
    let deltaLatitude = bufferMeters / earthRadius

    let deltaMinLongitude = bufferMeters / (earthRadius * cos(.pi * self.sw.latitude / 180))
    let minLatitude = self.sw.latitude - deltaLatitude * (180 / .pi)
    let minLongitude = self.sw.longitude - deltaMinLongitude * (180 / .pi)

    let deltaMaxLongitude = bufferMeters / (earthRadius * cos(.pi * self.ne.latitude / 180))
    let maxLongitude = self.ne.longitude + deltaMaxLongitude * (180 / .pi)
    let maxLatitude = self.ne.latitude + deltaLatitude * (180 / .pi)

    let sw = CLLocationCoordinate2D(latitude: minLatitude, longitude: minLongitude)
    let ne = CLLocationCoordinate2D(latitude: maxLatitude, longitude: maxLongitude)
    return MLNCoordinateBounds(sw: sw, ne: ne)
  }
}
