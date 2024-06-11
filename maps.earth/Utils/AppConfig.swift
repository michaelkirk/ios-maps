//
//  AppConfig.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/7/24.
//

import Foundation

struct AppConfig {
  let serverBase = URL(string: "https://maps.earth")!
  // let serverBase = URL(string: "https://seattle.maps.earth")!
  // let serverBase = URL(string: "http://localhost:9000")!
  // let serverBase = URL(string: "https://dev.maps.earth")!

  var peliasEndpoint: URL {
    self.serverBase.appending(path: "/pelias/v1/")
  }

  var travelmuxEndpoint: URL {
    self.serverBase.appending(path: "travelmux/v6/plan")
  }

  var valhallaEndpoint: URL {
    self.serverBase.appending(path: "/valhalla/route")
  }

  var tileserverStyleUrl: URL {
    self.serverBase.appending(path: "/tileserver/styles/basic/style.json")
  }
}
