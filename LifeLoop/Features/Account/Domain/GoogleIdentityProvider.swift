//
//  GoogleIdentityProvider.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 17/11/26.
//

import Foundation

/// Google proves identity; the LifeLoop backend decides which account/session to create.
@MainActor
protocol GoogleIdentityProvider {
    func signIn() async throws -> String
    func signOut()
}

enum GoogleSignInFailure: Error, LocalizedError {
    case missingConfiguration
    case missingPresenter
    case missingToken
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: "Google sign-in is not configured for this build yet."
        case .missingPresenter: "The sign-in screen is not ready. Please try again."
        case .missingToken: "Google could not provide a sign-in token. Please try again."
        case .authenticationFailed: "Google sign-in could not finish. Please try again."
        }
    }
}
