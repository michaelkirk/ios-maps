//
//  RelativeDateFormatter.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/24/24.
//

import Foundation

func formatRelativeDate(_ date: Date, relativeTo: Date = Date.now) -> String {
  let days = date.days(from: relativeTo)

  if days < 0 {
    // In the past
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm MMMM d"
    return formatter.string(from: date)
  } else if days < 1 {
    // Today
    return date.formatted(date: .omitted, time: .shortened)
  } else if days == 1 {
    // Tomorrow
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let time = formatter.string(from: date)
    return "\(time) Tomorrow"
  } else if days < 7 {
    // Within a week
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm EEEE"
    return formatter.string(from: date)
  } else {
    // Later
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm MMMM d"
    return formatter.string(from: date)
  }
}

extension Date {
  func days(from otherDate: Date) -> Int {
    let calendar = Calendar.current
    let components = calendar.dateComponents(
      [.day], from: calendar.startOfDay(for: otherDate), to: calendar.startOfDay(for: self))
    guard let days = components.day else {
      assertionFailure("days was unexpectedly nil")
      return 0
    }
    return days
  }
}
