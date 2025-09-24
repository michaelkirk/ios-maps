//
//  Checkbox.swift
//  maps.earth
//
//  Created by Michael Kirk on 5/1/24.
//

import SwiftUI

struct LabeledCheckbox<Label>: View where Label: View {
  @Binding var isChecked: Bool

  @ViewBuilder
  var label: () -> Label

  var body: some View {
    Button(action: { isChecked.toggle() }) {
      HStack {
        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
          .foregroundColor(isChecked ? .hw_blue : .gray)
        label().foregroundColor(.primary)
      }
    }
  }
}

#Preview("unchecked") {
  VStack(alignment: .leading) {
    LabeledCheckbox(isChecked: .constant(false)) {
      Text("Some unchecked Option")
    }
    LabeledCheckbox(isChecked: .constant(true)) {
      Text("Some checked Option")
    }
  }
}
