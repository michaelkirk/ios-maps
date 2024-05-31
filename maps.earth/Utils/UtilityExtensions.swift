//
//  UtilityExtensions.swift
//  maps.earth
//
//  Created by Michael Kirk on 5/23/24.
//

import Foundation

extension Collection {
  subscript(getOrNil index: Index) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}
