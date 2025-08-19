//
//  LocateMeButton.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/12/24.
//

import UIKit

private let logger = FileLogger()

class LocateMeButton: UIButton {
  weak var delegate: LocateMeButtonDelegate?
  weak var userLocationManager: UserLocationManager?

  private var currentState: UserLocationState = .initial {
    didSet {
      updateAppearance()
    }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupButton()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupButton()
  }

  private func setupButton() {
    addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    updateAppearance()
  }

  private var systemImageName: String {
    switch currentState {
    case .initial, .showing:
      return "location"
    case .following:
      return "location.fill"
    case .denied:
      return "location.slash"
    }
  }

  private func updateAppearance() {
    setImage(UIImage(systemName: systemImageName), for: .normal)
    isEnabled = currentState != .denied
  }

  func updateUserLocationState(_ state: UserLocationState) {
    currentState = state
  }

  @objc private func buttonTapped() {
    let newState: UserLocationState
    let newMapFocus: MapFocus?

    switch currentState {
    case .initial:
      newState = .showing
      newMapFocus = .userLocation
    case .showing:
      newState = .following
      newMapFocus = .userLocation
    case .following:
      newState = .showing
      newMapFocus = .userLocation
    case .denied:
      newState = .denied
      newMapFocus = nil
    }

    logger.debug("tapped LocateMeButton with state \(self.currentState) -> \(newState)")

    currentState = newState
    userLocationManager?.state = newState
    delegate?.locateMeButtonTapped(newMapFocus: newMapFocus)
  }
}

protocol LocateMeButtonDelegate: AnyObject {
  func locateMeButtonTapped(newMapFocus: MapFocus?)
}

extension TopControlsView: LocateMeButtonDelegate {
  func locateMeButtonTapped(newMapFocus: MapFocus?) {
    pendingMapFocus = newMapFocus
  }
}
