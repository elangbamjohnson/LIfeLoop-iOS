//
//  GoogleSignInWelcomeView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 17/11/26.
//

import SwiftUI
import GoogleSignInSwift

/// This view renders state and reports taps. The ViewModel owns the sign-in work.
struct GoogleSignInWelcomeView: View {
    let isBusy: Bool
    let errorMessage: String?
    let onSignIn: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .accessibilityHidden(true)
                    Text("Your life, organized")
                        .font(.title2.bold())
                    Text("Use Google to create an account or sign in to your existing LifeLoop account.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    GoogleSignInButton(action: onSignIn)
                        .disabled(isBusy)
                        .accessibilityIdentifier("googleSignIn")
                    if isBusy { ProgressView("Signing in…") }
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("signInError")
                    }
                }
                .padding(24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Welcome to LifeLoop")
        }
    }
}

#Preview("Google sign-in") {
    GoogleSignInWelcomeView(isBusy: false, errorMessage: nil, onSignIn: {})
}

#Preview("Signing in") {
    GoogleSignInWelcomeView(isBusy: true, errorMessage: nil, onSignIn: {})
}

#Preview("Sign-in failure") {
    GoogleSignInWelcomeView(isBusy: false, errorMessage: "Could not sign in. Please try again.", onSignIn: {})
}
