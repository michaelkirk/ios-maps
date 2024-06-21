//
//  NavigationViewController.swift
//  maps.earth
//
//  Created by Michael Kirk on 5/9/24.
//

import CoreLocation
import MapLibre
import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigation
import SwiftUI

struct MENavigationViewController: UIViewControllerRepresentable {
  typealias UIViewControllerType = MapboxNavigation.NavigationViewController

  func makeCoordinator() -> Coordinator {
    Coordinator(onDismiss: onDismiss)
  }

  let route: Route
  let onDismiss: () -> Void

  class Coordinator {
    let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
      self.onDismiss = onDismiss
    }
  }

  var mlnDirections: Directions {
    Env.current.mlnDirections
  }

  init(route: Route, onDismiss: @escaping () -> Void) {
    self.route = route
    self.onDismiss = onDismiss
  }

  func makeUIViewController(context: Context) -> Self.UIViewControllerType {
    let simulatedLocationManager: SimulatedLocationManager?
    if Env.current.simulateLocationForTesting {
      let manager = SimulatedLocationManager(route: route)
      manager.speedMultiplier = 10
      // Uncomment to go off route and test re-route
      // manager.simulatedLocationManagerDelegate = context.coordinator
      simulatedLocationManager = manager
    } else {
      simulatedLocationManager = nil
    }
    let dayStyle = MEDayStyle(mapStyleURL: AppConfig().tileserverStyleUrl)
    let vc = MapboxNavigation.NavigationViewController(
      dayStyle: dayStyle,
      directions: mlnDirections
    )
    vc.mapView.setZoomLevel(17, animated: false)
    vc.startNavigation(with: route, locationManager: simulatedLocationManager)
    assert(vc.delegate == nil)
    // The built-in attribution control is positioned relative to the contentInset, which means it'll appear in the middle of the screen.
    // Instead attribution is handled in a custom control.
    vc.mapView.attributionButton.isHidden = true
    vc.mapView.logoView.alpha = 0
    vc.delegate = context.coordinator
    return vc
  }

  func updateUIViewController(_ uiViewController: Self.UIViewControllerType, context: Context) {
    // Update the view controller if needed
  }
}

extension MENavigationViewController.Coordinator: NavigationViewControllerDelegate {
  // e.g. after style is applied
  func navigationViewController(
    _ navigationViewController: NavigationViewController, didFinishLoading style: MLNStyle
  ) {
    add3DBuildingsLayer(mapView: navigationViewController.mapView)
  }

  @objc func navigationViewControllerDidFinishRouting(
    _ navigationViewController: NavigationViewController
  ) {
    onDismiss()
  }
}

extension MENavigationViewController.Coordinator: SimulatedLocationManagerDelegate {
  func simulatedLocationManager(
    _ simulatedLocationManager: MapboxCoreNavigation.SimulatedLocationManager,
    locationFor originalLocation: CLLocation
  ) -> CLLocation {
    let offsetCoordinate = originalLocation.coordinate.coordinate(at: 100, facing: 90)
    return CLLocation(latitude: offsetCoordinate.latitude, longitude: offsetCoordinate.longitude)
  }
}

class MEDayStyle: DayStyle {
  override open func apply() {
    super.apply()
    EndOfRouteButton.appearance().backgroundColor = Color(hexString: "FF3B30")!.uiColor
    EndOfRouteButton.appearance().cornerRadius = 10
    EndOfRouteButton.appearance().textColor = .white
    EndOfRouteButton.appearance().textFont = .systemFont(ofSize: 20, weight: .bold)
  }
}
