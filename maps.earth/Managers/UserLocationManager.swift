//
//  UserLocationManager.swift
//  maps.earth
//
//  Created by Michael Kirk on 6/28/24.
//

import CoreLocation
import Foundation
import UIKit

private let logger = FileLogger()

class UserLocationManager: ObservableObject {
  @Published var mostRecentUserLocation: CLLocation?
  @Published var state: UserLocationState = .initial

  let locationManager = CLLocationManager()
  init() {
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] notification in
      guard let self else {
        return
      }

      // If the user authorized location with "Allow Once", it's intended to last "one session", which isn't necessarily one launch of the app.
      // authorization will revert to '.notDetermined" after leaving the app for even a short while (anecdotally: 10s)
      // So here we re-prompt upon their return.
      if locationManager.authorizationStatus == .notDetermined {
        logger.debug("didBecomeActive with locationManager.authorizationStatus == .notDetermined")
        locationManager.requestWhenInUseAuthorization()
      }
    }
  }
}
