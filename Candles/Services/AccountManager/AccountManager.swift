import Foundation
import Combine

class AccountManager: ObservableObject {
    static let shared = AccountManager() // Singleton instance
    @Published var accounts: [Account] = []
    private var cancellables = Set<AnyCancellable>()
    
    private init() { // Private initializer for singleton
        loadAccountsFromDatabase()
    }
    
    private func loadAccountsFromDatabase() {
        do {
            let fetchedAccounts = try AccountDatabaseService.shared.fetchAllAccounts()
            // Placeholder: Here you would typically fetch sub-accounts for each account
            // For now, we'll assume sub-accounts are either part of the initial fetch (if model supports it)
            // or would be fetched in a separate step and assigned.
            // Example: self.accounts = fetchedAccounts.map { account in
            // var mutableAccount = account
            var accountsWithSubAccounts: [Account] = []
            for var account in fetchedAccounts {
                // Fetch sub-accounts for each account
                // This is a simplified example; error handling and proper async management are needed.
                self.fetchSubAccountsAPI(for: account) { subAccounts in
                    account.subAccounts = subAccounts
                    accountsWithSubAccounts.append(account)
                    // If all accounts have been processed, update the main list
                    if accountsWithSubAccounts.count == fetchedAccounts.count {
                        // Ensure updates on the main thread if this callback isn't already
                        DispatchQueue.main.async {
                            self.accounts = accountsWithSubAccounts.sorted(by: { $0.displayName ?? "" < $1.displayName ?? "" }) // Or some other consistent sorting
                            print("Accounts and sub-accounts loaded.")
                        }
                    }
                }
            }
            // If there are no accounts, or if fetching sub-accounts is fully synchronous and handled above:
            if fetchedAccounts.isEmpty {
                DispatchQueue.main.async {
                    self.accounts = []
                    print("No accounts found or loaded.")
                }
            }
        } catch {
            print("Error loading accounts from database: \(error). Starting with an empty list.")
            self.accounts = []
        }
    }
    
    func addAccount(broker: Broker, userName: String, token: String, displayName: String? = nil) {
        let newAccount = Account(broker: broker, userName: userName, token: token, displayName: displayName)
        // Prevent adding duplicate accounts (simple check based on broker and username)
        // Prevent adding duplicate accounts (simple check based on broker and username)
        if !accounts.contains(where: { $0.broker == newAccount.broker && $0.userName == newAccount.userName }) {
            do {
                try AccountDatabaseService.shared.saveAccount(newAccount)
                accounts.append(newAccount)
                print("Account added and saved: \(newAccount.displayName ?? "Unknown Account")")
            } catch {
                print("Error saving account \(newAccount.displayName ?? "Unknown Account") to database: \(error)")
            }
        } else {
            print("Account for \(broker.rawValue) - \(userName) already exists.")
        }
    }
    
    func removeAccount(at offsets: IndexSet) {
        let accountsToRemove = offsets.map { accounts[$0] }
        accounts.remove(atOffsets: offsets)
        for account in accountsToRemove {
            do {
                try AccountDatabaseService.shared.deleteAccount(account: account)
                print("Account removed from database: \(account.displayName ?? "Unknown Account")")
            } catch {
                print("Error removing account \(account.displayName ?? "Unknown Account") from database: \(error)")
            }
        }
    }
    
    func removeAccount(id: UUID) {
        if let accountToRemove = accounts.first(where: { $0.id == id }) {
            accounts.removeAll { $0.id == id }
            do {
                try AccountDatabaseService.shared.deleteAccount(id: id)
                print("Account with ID \(id) removed from database.")
            } catch {
                print("Error removing account with ID \(id) from database: \(error)")
            }
        } else {
            print("Account with ID \(id) not found.")
        }
    }
    
    // Placeholder for the actual API call to fetch sub-accounts
    private func fetchSubAccountsAPI(for account: Account, completion: @escaping ([SubAccount]?) -> Void) {
        // Construct the URL based on the documentation: https://gateway-api-demo.s2f.projectx.com/api/Account/search
        // The documentation shows a POST request. We'll need a networking layer to make this call.
        // For now, this is a placeholder. You'll need to integrate your actual networking code here.
        // This example assumes the API might return sub-accounts related to the main account's token or ID.
        // The API doc provided is for a general search, so specific filtering for sub-accounts of a *particular* parent account isn't detailed.
        // We'll use the actual API call now.
        print("Fetching sub-accounts for \(account.displayName ?? "Unknown Account") (Broker: \(account.broker.rawValue), ID: \(account.id.uuidString)) using token: \(account.token.prefix(8))...")

        // Use the broker-specific base URL and append the account search path
        // Assuming '/api/Account/search' is a common path. This might need to be broker-specific if APIs differ significantly.
        guard let baseURL = URL(string: account.broker.baseURLString) else {
            print("Invalid base URL for broker \(account.broker.rawValue): \(account.broker.baseURLString)")
            completion(nil)
            return
        }
        let url = baseURL.appendingPathComponent("/api/Account/search")
        print("Constructed sub-account search URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(account.token)", forHTTPHeaderField: "Authorization") // Add bearer token for authorization

        // Construct the request body. This is an assumption based on a typical search API.
        // The API documentation is needed for the exact structure.
        // For example, it might expect the parent account's token or ID to filter sub-accounts.
        let requestBody: [String: Any] = [
            "parentAccountToken": account.token, // Assuming the API uses the token to find related sub-accounts
            "searchTerm": "", // General search term, might not be needed if filtering by token
            "pageNumber": 1,
            "pageSize": 100 // Fetch up to 100 sub-accounts
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            print("Error serializing request body: \(error)")
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error fetching sub-accounts for \(account.displayName ?? "Unknown Account"): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("HTTP error fetching sub-accounts. Status code: \(statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("Error response: \(errorString)")
                }
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            guard let data = data else {
                print("No data received for sub-accounts.")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let decoder = JSONDecoder()
            do {
                // Assuming the API returns a structure that has an "accounts" key with an array of sub-account-like objects.
                struct APIResponse: Codable {
                    struct SubAccountData: Codable {
                        let id: Int
                        let name: String
                        let balance: Double
                        let canTrade: Bool
                        let isVisible: Bool
                    }
                    let accounts: [SubAccountData] // This matches the mock structure, assuming API is similar
                    // Add other fields like totalCount, isSuccess, message if needed from the actual API response
                }
                let decodedResponse = try decoder.decode(APIResponse.self, from: data)
                let subAccounts = decodedResponse.accounts.compactMap { data -> SubAccount? in
                    guard data.canTrade else { return nil } // Filter out accounts that cannot trade
                    return SubAccount(id: data.id, name: data.name, balance: data.balance, canTrade: data.canTrade, isVisible: data.isVisible)
                }
                DispatchQueue.main.async {
                    print("Successfully fetched, parsed, and filtered \(subAccounts.count) sub-accounts for \(account.displayName ?? "Unknown Account")")
                    completion(subAccounts)
                }
            } catch {
                DispatchQueue.main.async {
                    print("Error decoding sub-accounts response for \(account.displayName ?? "Unknown Account"): \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Raw response data: \(responseString)")
                    }
                    completion(nil)
                }
            }
        }.resume()
    }
}