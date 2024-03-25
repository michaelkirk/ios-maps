//
//  maps_earthApp.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import SwiftUI

@main
struct maps_earthApp: App {
  init() {
    Bench(title: "load preferences from storage") {
      PreferencesController.shared.loadFromStorage()
    }
  }
  var body: some Scene {
    WindowGroup {
      HomeView()
    }
  }
}
