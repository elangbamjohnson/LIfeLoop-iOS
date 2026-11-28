//
//  GoogleOAuthConfiguration.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 17/11/26.
//

import Foundation

struct GoogleOAuthConfiguration {
    let iOSClientID: String
    let serverClientID: String

    init(values: [String: Any]) throws {
        guard let iOS = values["GIDClientID"] as? String,
              let server = values["GIDServerClientID"] as? String,
              Self.isClientID(iOS), Self.isClientID(server), iOS != server else {
            throw GoogleSignInFailure.missingConfiguration
        }
        let reversed = iOS.split(separator: ".").reversed().joined(separator: ".")
        let types = values["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        guard schemes.contains(reversed) else { throw GoogleSignInFailure.missingConfiguration }
        iOSClientID = iOS
        serverClientID = server
    }

    private static func isClientID(_ value: String) -> Bool {
        value.hasSuffix(".apps.googleusercontent.com") &&
        value.count > ".apps.googleusercontent.com".count &&
        !value.contains("$(") && !value.contains(where: \.isWhitespace)
    }
}
