//
//  Platform.swift
//  maps.earth
//
//  Created by Michael Kirk on 5/29/24.
//

import Foundation

struct Platform {
  static let isSimulator: Bool = {
    #if targetEnvironment(simulator)
      return true
    #else
      return false
    #endif
  }()
}
