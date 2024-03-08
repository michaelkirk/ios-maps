//
//  AppConfig.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/7/24.
//

import Foundation

struct AppConfig {
  let serverBase = "https://maps.earth"
  var peliasEndpoint: URL {
    URL(string: "\(self.serverBase)/pelias/v1/autocomplete")!
  }
  var travelmuxEndpoint: URL {
    URL(string: "\(self.serverBase)/travelmux/v2/plan")!
  }
  var tileserverStyleUrl: URL {
    URL(string: "\(self.serverBase)/tileserver/styles/basic/style.json")!
  }
}
