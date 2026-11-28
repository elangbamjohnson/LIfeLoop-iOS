//
//  AppConfiguration.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 16/11/26.
//

import Foundation

/// Environment selection is independent of signing. No credentials belong here.
struct AppConfiguration {
    enum Environment: String {
        case demo
        case staging
        case production
    }

    let environment: Environment
    let apiBaseURL: URL?

    init(values: [String: Any]) throws {
        guard let name = values["LifeLoopEnvironment"] as? String else {
            throw ConfigurationError.invalidEnvironment
        }
        guard let environment = Environment(rawValue: name) else {
            throw ConfigurationError.invalidEnvironment
        }
        self.environment = environment
        if environment == .demo {
            apiBaseURL = nil
            return
        }
        guard let address = values["LifeLoopAPIBaseURL"] as? String,
              let url = URL(string: address), url.scheme == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else {
            throw ConfigurationError.invalidServerURL
        }
        apiBaseURL = url
    }

    enum ConfigurationError: Error {
        case invalidEnvironment
        case invalidServerURL
    }
}
