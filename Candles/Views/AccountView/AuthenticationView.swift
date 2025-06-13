import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var accountManager: AccountManager
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedBroker: Broker = .alphaticks
    @State private var userName: String = ""
    @State private var apiKey: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false

    let authenticationRoutes = AuthenticationRoutes()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Broker Details")) {
                    Picker("Select Broker", selection: $selectedBroker) {
                        ForEach(Broker.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                    TextField("Username", text: $userName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("API Key", text: $apiKey)
                }

                Section {
                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Login & Add Account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(userName.isEmpty || apiKey.isEmpty || isLoading)
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    func login() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                print("Hello, \(userName)!, \(apiKey)")
                let response = try await authenticationRoutes.signIn(userName: userName, apiKey: apiKey, broker: selectedBroker)
                isLoading = false
                if let authResponse = response, authResponse.success == true, let token = authResponse.token {
                    print("Successfully authenticated with \(selectedBroker.rawValue). Token: \(token)")
                    accountManager.addAccount(broker: selectedBroker, userName: userName, token: token)
                    presentationMode.wrappedValue.dismiss() // Dismiss after successful login
                } else {
                    errorMessage = response?.errorMessage ?? "Login failed. Please check your credentials and try again."
                }
            } catch {
                isLoading = false
                errorMessage = "An error occurred: \(error.localizedDescription)"
            }
        }
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
    }
}
