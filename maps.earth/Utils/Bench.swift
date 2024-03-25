import Foundation
import QuartzCore

private let logger = FileLogger()

public func Bench<T>(title: String, block: () throws -> T) rethrows -> T {
  let startTime = CACurrentMediaTime()
  let value = try block()
  let timeElapsed = CACurrentMediaTime() - startTime
  let formattedTime = String(format: "%0.2fms", timeElapsed * 1000)
  let logMessage = "title: \(title), duration: \(formattedTime)"

  logger.info("\(logMessage)")
  return value
}
