//
//  TopControls.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/20/24.
//

import SwiftUI
import UIKit

class TopControlsView: UIView {
  static let controlHeight: CGFloat = 38

  weak var delegate: TopControlsDelegate?
  var pendingMapFocus: MapFocus? {
    didSet {
      delegate?.topControlsDidUpdateMapFocus(self, mapFocus: pendingMapFocus)
    }
  }

  private let stackView = UIStackView()
  private let appInfoButton = AppInfoButton()
  private let locateMeButton = LocateMeButton()
  private let divider = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  private func setupView() {
    stackView.axis = .vertical
    stackView.spacing = 0
    stackView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stackView)

    divider.backgroundColor = UIColor.systemGray4
    divider.translatesAutoresizingMaskIntoConstraints = false

    stackView.addArrangedSubview(appInfoButton)
    stackView.addArrangedSubview(divider)
    stackView.addArrangedSubview(locateMeButton)

    appInfoButton.delegate = self
    locateMeButton.delegate = self

    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

      appInfoButton.widthAnchor.constraint(equalToConstant: TopControlsView.controlHeight),
      appInfoButton.heightAnchor.constraint(equalToConstant: TopControlsView.controlHeight),

      locateMeButton.widthAnchor.constraint(equalToConstant: TopControlsView.controlHeight),
      locateMeButton.heightAnchor.constraint(equalToConstant: TopControlsView.controlHeight),

      divider.heightAnchor.constraint(equalToConstant: 0.5),
    ])

    backgroundColor = Color.hw_sheetBackground.uiColor
    layer.cornerRadius = 8
    layer.shadowRadius = 3
    layer.shadowOpacity = 0.3
    layer.shadowOffset = CGSize(width: 0, height: 2)
    layer.shadowColor = UIColor.black.cgColor

    tintColor = Color.hw_sheetCloseForeground.uiColor
  }

  func updateUserLocationState(_ state: UserLocationState) {
    locateMeButton.updateUserLocationState(state)
  }
}

protocol TopControlsDelegate: AnyObject {
  func topControlsDidUpdateMapFocus(_ topControls: TopControlsView, mapFocus: MapFocus?)
  func topControlsDidRequestAppInfo(_ topControls: TopControlsView)
}

class AppInfoButton: UIButton {
  weak var delegate: AppInfoButtonDelegate?

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupButton()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupButton()
  }

  private func setupButton() {
    setImage(UIImage(systemName: "info.circle"), for: .normal)
    addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
  }

  @objc private func buttonTapped() {
    delegate?.appInfoButtonTapped()
  }
}

protocol AppInfoButtonDelegate: AnyObject {
  func appInfoButtonTapped()
}

extension TopControlsView: AppInfoButtonDelegate {
  func appInfoButtonTapped() {
    delegate?.topControlsDidRequestAppInfo(self)
  }
}

class AppInfoSheetContents: UIViewController {
  private let scrollView = UIScrollView()
  private let contentView = UIView()
  private let headerView = UIView()
  private let titleLabel = UILabel()
  private let closeButton = UIButton(type: .system)
  private let stackView = UIStackView()

  override func viewDidLoad() {
    super.viewDidLoad()
    setupView()
    setupHeader()
    setupContent()
  }

  private func setupView() {
    view.backgroundColor = Color.hw_sheetBackground.uiColor

    headerView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false

    stackView.axis = .vertical
    stackView.spacing = 16
    stackView.alignment = .leading

    view.addSubview(headerView)
    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(stackView)

    NSLayoutConstraint.activate([
      headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      headerView.heightAnchor.constraint(equalToConstant: 60),

      scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

      stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
      stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16),
    ])
  }

  private func setupHeader() {
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    closeButton.translatesAutoresizingMaskIntoConstraints = false

    titleLabel.text = "About"
    titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
    titleLabel.textColor = .label

    let closeButtonContainer = self.buildCloseButton()

    headerView.addSubview(titleLabel)
    headerView.addSubview(closeButtonContainer)

    NSLayoutConstraint.activate([
      titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
      titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),

      closeButtonContainer.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
      closeButtonContainer.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
      closeButtonContainer.widthAnchor.constraint(equalToConstant: 40),
      closeButtonContainer.heightAnchor.constraint(equalToConstant: 40),
    ])
  }

  @objc private func closeButtonTapped() {
    self.dismiss(animated: true)
  }

  private func buildCloseButton() -> UIView {
    closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
    closeButton.tintColor = Color.hw_sheetCloseBackground.uiColor
    closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

    let closeButtonContainer = UIView()
    closeButtonContainer.translatesAutoresizingMaskIntoConstraints = false

    let closeButtonBackground = UIView()
    closeButtonBackground.translatesAutoresizingMaskIntoConstraints = false
    closeButtonBackground.backgroundColor = Color.hw_sheetCloseForeground.uiColor
    closeButtonBackground.layer.cornerRadius = 12

    closeButtonContainer.addSubview(closeButtonBackground)
    closeButtonContainer.addSubview(closeButton)

    let offset: CGFloat = 10
    NSLayoutConstraint.activate([
      closeButtonBackground.topAnchor.constraint(equalTo: closeButtonContainer.topAnchor, constant: offset),
      closeButtonBackground.leadingAnchor.constraint(equalTo: closeButtonContainer.leadingAnchor, constant: offset),
      closeButtonBackground.trailingAnchor.constraint(equalTo: closeButtonContainer.trailingAnchor, constant: -offset),
      closeButtonBackground.bottomAnchor.constraint(equalTo: closeButtonContainer.bottomAnchor, constant: -offset),

      closeButton.topAnchor.constraint(equalTo: closeButtonContainer.topAnchor),
      closeButton.leadingAnchor.constraint(equalTo: closeButtonContainer.leadingAnchor),
      closeButton.trailingAnchor.constraint(equalTo: closeButtonContainer.trailingAnchor),
      closeButton.bottomAnchor.constraint(equalTo: closeButtonContainer.bottomAnchor),
    ])
    return closeButtonContainer
  }

  private func setupContent() {
    let p1 = createAttributedText(
      "This app is built on open source. Learn more at about.maps.earth",
      links: [("about.maps.earth", "https://about.maps.earth")]
    )

    let p2 = createAttributedText(
      "The services this app needs to function, such as routing, geo search, and the \"tiles\" used to render the map itself, are all built and provided by Headway — an open source self-hostable map stack.",
      links: [("Headway", "https://github.com/headwaymaps/headway")]
    )

    let p3 = createAttributedText(
      "Map data is sourced from OpenStreetMap, Daylight, OpenAddresses, OpenMapTiles, \"Who's On First\", and Natural Earth.",
      links: [
        ("OpenStreetMap", "https://www.openstreetmap.org"),
        ("Daylight", "https://daylightmap.org"),
        ("OpenMapTiles", "https://www.openmaptiles.org"),
        ("OpenAddresses", "https://www.openaddresses.io"),
        ("\"Who's On First\"", "https://whosonfirst.org"),
        ("Natural Earth", "https://www.naturalearthdata.com"),
      ]
    )

    let p4 = createAttributedText(
      "😍Happy? 🤬Angry? 🤔Curious?\n\n✉️ info@maps.earth",
      links: [("info@maps.earth", "mailto:info@maps.earth")]
    )

    let label1 = createLabel(with: p1)
    let label2 = createLabel(with: p2)
    let label3 = createLabel(with: p3)
    let label4 = createLabel(with: p4)

    label4.textAlignment = .center
    label4.font = UIFont.boldSystemFont(ofSize: 17)

    stackView.addArrangedSubview(label1)
    stackView.addArrangedSubview(label2)
    stackView.addArrangedSubview(label3)

    let spacerView = UIView()
    spacerView.setContentHuggingPriority(.defaultLow, for: .vertical)
    stackView.addArrangedSubview(spacerView)
    stackView.addArrangedSubview(label4)
  }

  private func createAttributedText(_ text: String, links: [(String, String)]) -> NSAttributedString
  {
    let attributedString = NSMutableAttributedString(string: text)

    for (linkText, urlString) in links {
      if let range = text.range(of: linkText) {
        let nsRange = NSRange(range, in: text)
        attributedString.addAttribute(.link, value: urlString, range: nsRange)
      }
    }

    return attributedString
  }

  private func createLabel(with attributedText: NSAttributedString) -> UILabel {
    let label = UILabel()
    label.attributedText = attributedText
    label.numberOfLines = 0
    label.isUserInteractionEnabled = true
    return label
  }
}
