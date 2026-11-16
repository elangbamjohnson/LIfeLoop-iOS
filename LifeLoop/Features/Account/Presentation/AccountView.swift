import SwiftUI
import SwiftData

struct AccountView: View {
    @State private var viewModel: AccountViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var signInTask: Task<Void, Never>?
    private let server: URL
    private let container: Result<ModelContainer, Error>
    private let itemRepository: any ItemRepository

    init(accountRepository: any AccountRepository, itemRepository: any ItemRepository, server: URL, container: Result<ModelContainer, Error>) {
        self.server = server
        self.container = container
        self.viewModel = AccountViewModel(repository: accountRepository)
        self.itemRepository = itemRepository
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .restoring:
                ProgressView("Restoring your session…")
            case .signedOut:
                signInForm
            case .signedIn(let account):
                ConnectedOrganizerView(account: account, server: server, container: container,
                                       remote: itemRepository, onSignOut: { viewModel.signOut() },
                                       onSessionExpired: { viewModel.handleUnauthorized() })
                    .id(account.id)

            }
        }
        .task { await viewModel.restore() }
        .onDisappear { signInTask?.cancel() }
    }

    private var signInForm: some View {
        NavigationStack {
            Form {
                Section("Your existing LifeLoop account") {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                Section {
                    Button("Sign in") {
                        signInTask = Task {
                            await viewModel.signIn(email: email, password: password)
                            if case .signedIn = viewModel.state { password = "" }
                        }
                    }
                    .disabled(viewModel.isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                    if viewModel.isBusy { ProgressView("Signing in…") }
                    if let message = viewModel.errorMessage {
                        Text(message).foregroundStyle(.red)
                    }
                } footer: {
                    Text("Sign in with your existing LifeLoop account. Google sign-in and account recovery are coming soon.")
                }
            }
            .navigationTitle("Sign in to LifeLoop")
        }
    }
}
