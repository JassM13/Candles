import SwiftUI

struct AccountListView: View {
    @EnvironmentObject var accountManager: AccountManager
    @State private var showingAddAccountSheet = false

    var body: some View {
        NavigationView {
            List {
                ForEach(accountManager.accounts) { account in
                    VStack(alignment: .leading) {
                        Text(account.displayName ?? "Account")
                            .font(.headline)
                        Text("Broker: \(account.broker.rawValue.capitalized)")
                            .font(.subheadline)
                        Text("Username: \(account.userName)")
                            .font(.subheadline)
                        // You might want to hide or partially show the token for security
                        // Text("Token: \(account.token.prefix(8))...")
                        //    .font(.caption)
                        //    .foregroundColor(.gray)
                        if let subAccounts = account.subAccounts, !subAccounts.isEmpty {
                            Text("Sub-Accounts: \(subAccounts.count)")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Total Sub-Account Balance: $\(subAccounts.reduce(0) { $0 + $1.balance }, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("No sub-accounts")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .onDelete(perform: deleteAccount)
            }
            .navigationTitle("Connected Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddAccountSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddAccountSheet) {
                AuthenticationView()
                    .environmentObject(accountManager) // Pass the environment object to the sheet
            }
            .overlay {
                if accountManager.accounts.isEmpty {
                    Text("No accounts added yet.\nTap the '+' button to add an account.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding()
                }
            }
        }
    }

    private func deleteAccount(at offsets: IndexSet) {
        accountManager.removeAccount(at: offsets)
    }
}

struct AccountListView_Previews: PreviewProvider {
    static var previews: some View {
        
        return AccountListView()
    }
}
