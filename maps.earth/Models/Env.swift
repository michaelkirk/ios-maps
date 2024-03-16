//
//  Env.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/14/24.
//

import Foundation
import MapLibre

class Env {
  static var current = Env()

  private var _getMapFocus: () -> LngLat? = { nil }

  var getMapFocus: () -> LngLat? {
    get {
      dispatchPrecondition(condition: .onQueue(.main))
      return self._getMapFocus
    }
    set {
      dispatchPrecondition(condition: .onQueue(.main))
      self._getMapFocus = newValue
    }
  }
}