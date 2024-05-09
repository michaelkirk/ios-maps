//
//  UIHelper.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/11/24.
//

import UIKit

func dismissKeyboard() {
  // hide keyboard
  // NOTE: This frequently hangs on simulator if the software keyboard isn't actually presented
  // This commonly happens on the simulator because I'm typing with the hardware keyboard. Plausibly this could
  // happen with a hardware keyboard on a non-simulator device.
  UIApplication.shared.sendAction(
    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
