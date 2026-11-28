//
//  GoogleSignInService.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 17/11/26.
//

import GoogleSignIn
import UIKit

@MainActor
final class GoogleSignInService: GoogleIdentityProvider {
    weak var presentingViewController: UIViewController?
    private let configuration: Result<GoogleOAuthConfiguration, Error>

    init(values: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        configuration = Result { try GoogleOAuthConfiguration(values: values) }
    }

    func signIn() async throws -> String {
        let settings = try configuration.get()
        guard let presenter = presentingViewController, presenter.view.window != nil else {
            throw GoogleSignInFailure.missingPresenter
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: settings.iOSClientID, serverClientID: settings.serverClientID
        )
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            try Task.checkCancellation()
            let user = try await result.user.refreshTokensIfNeeded()
            try Task.checkCancellation()
            guard let token = user.idToken?.tokenString, !token.isEmpty else {
                throw GoogleSignInFailure.missingToken
            }
            return token
        } catch {
            if error is CancellationError || Task.isCancelled {
                signOut()
                throw CancellationError()
            }
            let sdkError = error as NSError
            if sdkError.domain == kGIDSignInErrorDomain,
               sdkError.code == GIDSignInError.canceled.rawValue {
                throw CancellationError()
            }
            if let failure = error as? GoogleSignInFailure { throw failure }
            // SDK diagnostics can include account details; don't expose them in UI/logs.
            throw GoogleSignInFailure.authenticationFailed
        }
    }

    func signOut() { GIDSignIn.sharedInstance.signOut() }
}
