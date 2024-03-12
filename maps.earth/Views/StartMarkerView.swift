//
//  StartMarkerView.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/8/24.
//

import Foundation
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
