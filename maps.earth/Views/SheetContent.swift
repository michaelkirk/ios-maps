//
//  SheetContent.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/15/24.
//

import SwiftUI

struct SheetContents<Content>: View where Content: View {
  var title: String
  var onClose: () -> Void = {}
  var presentationDetents: Set<PresentationDetent> = [.large, .medium, minDetentHeight]
  @Binding var currentDetent: PresentationDetent

  @ViewBuilder
  var content: () -> Content

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top) {
        Text(title).font(.title).bold()
        Spacer()
        CloseButton {
          onClose()
        }
      }.padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
      content()
    }.background(Color.hw_sheetBackground)
      .presentationDetents(presentationDetents, selection: $currentDetent)
      .ignoresSafeArea()
      .presentationBackgroundInteraction(
        .enabled(upThrough: .medium)
      )
  }
}
