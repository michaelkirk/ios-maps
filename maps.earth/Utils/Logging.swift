//
//  Logging.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/15/24.
//

import Foundation
import OSLog

public func FileLogger(file: String = #file) -> Logger {
  let url = URL(fileURLWithPath: file)
  let file = url.lastPathComponent
  let directory = url.deletingLastPathComponent().lastPathComponent
  let category = "\(directory)/\(file)"
  return Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: category
  )
}
