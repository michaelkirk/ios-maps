//
//  UIHelper.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/11/24.
//

import UIKit

func dismissKeyboard() {
  // hide keyboard
  UIApplication.shared.sendAction(
    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
