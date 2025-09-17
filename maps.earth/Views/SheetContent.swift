//
//  SheetContent.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/15/24.
//

import SwiftUI

struct SheetContents<Content, NavigationAccessoryContent>: View
where Content: View, NavigationAccessoryContent: View {
  var title: String
  var onClose: () -> Void
  var presentationDetents: Set<PresentationDetent> = [.large, .medium, minDetentHeight]
  @Binding var currentDetent: PresentationDetent

  @ViewBuilder
  var content: () -> Content

  @ViewBuilder
  var navigationAccessoryContent: () -> NavigationAccessoryContent

  init(
    title: String,
    onClose: @escaping () -> Void,
    presentationDetents: Set<PresentationDetent> = [.large, .medium, minDetentHeight],
    currentDetent: Binding<PresentationDetent>,
    @ViewBuilder navigationAccessoryContent: @escaping () -> NavigationAccessoryContent = {
      EmptyView()
    },
    @ViewBuilder _ content: @escaping () -> Content
  ) {
    self.title = title
    self.onClose = onClose
    self.presentationDetents = presentationDetents
    self._currentDetent = currentDetent
    self.content = content
    self.navigationAccessoryContent = navigationAccessoryContent
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top) {
        Text(title).font(.title).bold()
        Spacer()
        navigationAccessoryContent()
        CloseButton {
          onClose()
        }
      }.padding(16)
      content()
    }.presentationBackground(Color.hw_sheetBackground)
      .presentationDetents(presentationDetents, selection: $currentDetent)
      .ignoresSafeArea()
      .presentationBackgroundInteraction(
        .enabled(upThrough: .medium)
      )
  }
}

struct SheetContentsWithoutTitle<Content>: View where Content: View {
  var presentationDetents: Set<PresentationDetent> = [.large, .medium, minDetentHeight]
  @Binding var currentDetent: PresentationDetent

  @ViewBuilder
  var content: () -> Content

  var body: some View {
    VStack(spacing: 0) {
      content()
    }
    .padding(16)
    .presentationBackground(Color.hw_sheetBackground)
    .presentationDetents(presentationDetents, selection: $currentDetent)
    .presentationBackgroundInteraction(
      .enabled(upThrough: .medium)
    )
  }
}
