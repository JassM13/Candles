//
//  AccountView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI

struct AccountView: View {
    @ObservedObject var accountManager = AccountManager.shared // Use the singleton instance
    @State private var selectedBroker: Broker = .alphaticks // Default selection
    @State private var userName = ""
    @State private var apiKey = ""
    @State private var showingLoginError = false
    @State private var loginErrorMessage = ""

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Add New Account")) {
                        Picker("Select Broker", selection: $selectedBroker) {
                            ForEach(Broker.allCases, id: \.self) {
                                Text($0.rawValue.capitalized)
                            }
                        }
                        TextField("Username", text: $userName)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        SecureField("API Key", text: $apiKey)
                        Button("Login") {
                            login()
                        }
                    }

                    Section(header: Text("Logged-in Accounts")) {
                        if accountManager.accounts.isEmpty {
                            Text("No accounts logged in yet.")
                                .foregroundColor(.secondary)
                        } else {
                            List {
                                ForEach(accountManager.accounts) { account in
                                    VStack(alignment: .leading) {
                                        Text(account.displayName ?? "Unknown Account")
                                            .font(.headline)
                                        Text("Broker: \(account.broker.rawValue.capitalized)")
                                        Text("Username: \(account.userName)")
                                    }
                                }
                                .onDelete(perform: removeAccount)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
            .alert(isPresented: $showingLoginError) {
                Alert(title: Text("Login Failed"), message: Text(loginErrorMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    func login() {
        // Basic validation
        guard !userName.isEmpty, !apiKey.isEmpty else {
            loginErrorMessage = "Username and API Key cannot be empty."
            showingLoginError = true
            return
        }

        // Here you would typically call an async function to perform the actual login
        // For now, we'll simulate a successful login and add the account directly.
        // In a real app, you'd use AuthenticationRoutes.signIn and handle the response.

        // Simulate API call
        Task {
            let authRoutes = AuthenticationRoutes()
            do {
                let response = try await authRoutes.signIn(userName: userName, apiKey: apiKey, broker: selectedBroker)
                if let authResponse = response, authResponse.success, let token = authResponse.token {
                    DispatchQueue.main.async {
                        accountManager.addAccount(broker: selectedBroker, userName: userName, token: token)
                        // Clear fields after successful login
                        userName = ""
                        apiKey = ""
                    }
                } else {
                    DispatchQueue.main.async {
                        loginErrorMessage = response?.errorMessage ?? "An unknown error occurred."
                        showingLoginError = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loginErrorMessage = "Login request failed: \(error.localizedDescription)"
                    showingLoginError = true
                }
            }
        }
    }

    func removeAccount(at offsets: IndexSet) {
        accountManager.removeAccount(at: offsets)
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountView()
            // No need to pass environmentObject for singleton
    }
}
