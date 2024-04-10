//
//  StartMarkerView.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/8/24.
//

import Foundation
import SwiftUI
import UIKit

class StartMarkerView: UIView {
  init() {
    let frame = CGRect(x: 0, y: 0, width: 16, height: 16)
    super.init(frame: frame)
    self.backgroundColor = .white
    self.layer.borderColor = UIColor.black.cgColor
    self.layer.borderWidth = 2
    self.layer.cornerRadius = frame.width / 2
    self.layer.shadowRadius = 2
    self.layer.shadowOpacity = 0.7
    self.layer.shadowOffset = .zero
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class TransferMarkerView: UIView {
  init(isSelected: Bool) {
    let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    super.init(frame: frame)
    self.backgroundColor = isSelected ? Color.white.uiColor : Color(gray: 0.7).uiColor
    self.layer.borderColor =
      isSelected ? Color.hw_darkGray.cgColor : Color(gray: 0.7).uiColor.cgColor
    self.layer.borderWidth = 2
    self.layer.cornerRadius = frame.width / 2
    // It feels too noisy to show this for unselected routes.
    // I'm leaving the logic to render them in and making them invisible while I try it out for a while.
    self.isHidden = !isSelected
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
