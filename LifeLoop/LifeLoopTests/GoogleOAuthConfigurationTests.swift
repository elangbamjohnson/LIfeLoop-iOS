import Testing
@testable import LifeLoop

@MainActor
struct GoogleOAuthConfigurationTests {
    private var validValues: [String: Any] {
        [
            "GIDClientID": "ios-client.apps.googleusercontent.com",
            "GIDServerClientID": "web-client.apps.googleusercontent.com",
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["com.googleusercontent.apps.ios-client"]]]
        ]
    }

    @Test func acceptsSeparateClientsAndMatchingCallbackScheme() throws {
        let configuration = try GoogleOAuthConfiguration(values: validValues)
        #expect(configuration.iOSClientID == "ios-client.apps.googleusercontent.com")
        #expect(configuration.serverClientID == "web-client.apps.googleusercontent.com")
    }

    @Test(arguments: ["GIDClientID", "GIDServerClientID", "CFBundleURLTypes"])
    func missingConfigurationCannotStartGoogleSignIn(key: String) {
        var values = validValues
        values.removeValue(forKey: key)
        #expect(throws: GoogleSignInFailure.self) { try GoogleOAuthConfiguration(values: values) }
    }

    @Test func wrongCallbackSchemeIsRejected() {
        var values = validValues
        values["CFBundleURLTypes"] = [["CFBundleURLSchemes": ["wrong-scheme"]]]
        #expect(throws: GoogleSignInFailure.self) { try GoogleOAuthConfiguration(values: values) }
    }

    @Test func usingWebClientAsIOSClientIsRejected() {
        var values = validValues
        values["GIDServerClientID"] = values["GIDClientID"]
        #expect(throws: GoogleSignInFailure.self) { try GoogleOAuthConfiguration(values: values) }
    }

    @Test func unresolvedBuildVariableIsRejected() {
        var values = validValues
        values["GIDClientID"] = "$(GOOGLE_IOS_CLIENT_ID)"
        #expect(throws: GoogleSignInFailure.self) { try GoogleOAuthConfiguration(values: values) }
    }
}
