//
//  AddressFormatter.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import Contacts
import Foundation

struct AddressFormatter {
  func format(place: Place) -> String {
    let address = CNMutablePostalAddress()

    if let houseNumber = place.housenumber {
      address.street = houseNumber
    }
    if let street = place.street {
      if address.street.isEmpty {
        address.street = street
      } else {
        address.street += " " + street
      }
    }
    if let locality = place.locality {
      address.city = locality
    }
    if let state = place.state {
      address.state = state
    }
    if let postalCode = place.postalCode {
      address.postalCode = postalCode
    }
    // This might not be right -
    if let countryCode = place.countryCode {
      address.isoCountryCode = countryCode
    }
    // TODO: locality

    return CNPostalAddressFormatter.string(from: address, style: .mailingAddress)
  }
}
