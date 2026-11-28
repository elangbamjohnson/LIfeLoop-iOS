//
//  AppConfigurationTests.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 16/11/26.
//

import Foundation

import Testing
@testable import LifeLoop

@MainActor
struct AppConfigurationTests {
    @Test func missingEnvironmentDoesNotFallBackToDemo() {
        #expect(throws: AppConfiguration.ConfigurationError.self) {
            try AppConfiguration(values: [:])
        }
    }

    @Test func demoDoesNotNeedAServer() throws {
        let config = try AppConfiguration(values: ["LifeLoopEnvironment": "demo"])
        #expect(config.apiBaseURL == nil)
    }

    @Test(arguments: ["", "http://example.com", "https://user:password@example.com", "https://example.com?token=secret"])
    func connectedEnvironmentRejectsInvalidServer(address: String) {
        #expect(throws: AppConfiguration.ConfigurationError.self) {
            try AppConfiguration(values: [
                "LifeLoopEnvironment": "staging", "LifeLoopAPIBaseURL": address
            ])
        }
    }

    @Test func acceptsHTTPS() throws {
        let config = try AppConfiguration(values: [
            "LifeLoopEnvironment": "staging", "LifeLoopAPIBaseURL": "https://example.com"
        ])
        #expect(config.apiBaseURL?.host == "example.com")
    }
}
