import Foundation
import GRDB

class WatchlistManager: ObservableObject {
    // dbQueue is now managed by WatchlistDatabaseService
    @Published var watchlistItems: [WatchlistItem] = []
    @Published var searchResults: [WatchlistItem] = [] // To store search results from API
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // API Configuration will be sourced from AccountManager
    private var authToken: String? // To store the fetched auth token
    private var activeAccountToken: String?
    private var activeAccountUsername: String?

    // Dependency on AccountManager
    private let accountManager: AccountManager

    init(accountManager: AccountManager = .shared) {
        self.accountManager = accountManager
        Task {
            // Table creation is handled by WatchlistDatabaseService's init
            await fetchWatchlistItems()
        }
    }

    // MARK: - Database Operations
    // createWatchlistTable is now handled by WatchlistDatabaseService's initializer

    func fetchWatchlistItems() async {
        do {
            let items = try WatchlistDatabaseService.shared.fetchAllWatchlistItems()
            DispatchQueue.main.async {
                self.watchlistItems = items
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to fetch watchlist items: \(error.localizedDescription)"
            }
        }
    }

    func addWatchlistItem(_ item: WatchlistItem) async {
        do {
            try WatchlistDatabaseService.shared.saveWatchlistItem(item)
            await fetchWatchlistItems() // Refresh the list
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to add watchlist item: \(error.localizedDescription)"
            }
        }
    }

    func removeWatchlistItem(at offsets: IndexSet) async {
        let itemsToRemove = offsets.map { watchlistItems[$0] }
        do {
            for item in itemsToRemove {
                try WatchlistDatabaseService.shared.deleteWatchlistItem(item: item)
            }
            await fetchWatchlistItems() // Refresh the list
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to remove watchlist item(s): \(error.localizedDescription)"
            }
        }
    }
    
    func isItemInWatchlist(_ item: WatchlistItem) -> Bool {
        return watchlistItems.contains(where: { $0.id == item.id })
    }

    // MARK: - API Token Fetch
    // Fetches token and username from the first TopstepX account
    private func loadCredentialsFromAccount() async -> Bool {
        var foundAccount: Account? = nil
        for account in accountManager.accounts {
            let isTopstepX = account.broker == .topstepx
            let hasToken = !account.token.isEmpty
            let hasUsername = !account.userName.isEmpty
            if isTopstepX && hasToken && hasUsername {
                foundAccount = account
                break
            }
        }

        guard let topstepXAccount = foundAccount else {
            DispatchQueue.main.async {
                self.errorMessage = "No TopstepX account with valid credentials found. Please add or update your TopstepX account in settings."
                self.isLoading = false
            }
            return false
        }
        
        self.activeAccountToken = topstepXAccount.token
        self.activeAccountUsername = topstepXAccount.userName // Though not used in current search API body
        // The API uses the token for Bearer auth, which seems to be the primary credential.
        // The original placeholder `getAuthToken` was to fetch a separate `authToken`.
        // Now, we'll directly use the account's token as the `authToken` for API calls.
        self.authToken = topstepXAccount.token
        
        print("Using credentials from account: \(topstepXAccount.displayName ?? topstepXAccount.userName) for API calls.")
        return true
    }

    // MARK: - API Token Fetch (Now uses account's token directly)
    private func getAuthToken() async -> String? {
        if await loadCredentialsFromAccount() {
            return self.authToken
        }
        return nil
    }

    // MARK: - Contract Search API Call
    func searchContracts(searchText: String) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
            self.searchResults = [] // Clear previous results
        }

        if authToken == nil {
            authToken = await getAuthToken()
        }

        guard let token = authToken else {
            DispatchQueue.main.async {
                self.isLoading = false
                // Error message is already set by getAuthToken if it fails
                if self.errorMessage == nil {
                     self.errorMessage = "Authentication token is missing. Cannot search contracts."
                }
            }
            return
        }

        guard let url = URL(string: "https://api.topstepx.com/api/Contract/search") else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid API URL"
                self.isLoading = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "searchText": searchText,
            "live": false // As per example, or make this configurable
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to serialize request body: \(error.localizedDescription)"
                self.isLoading = false
            }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.errorMessage = "Invalid response from server."
                    self.isLoading = false
                }
                return
            }

            if httpResponse.statusCode == 401 { // Unauthorized
                 DispatchQueue.main.async {
                    self.errorMessage = "Unauthorized: Invalid or expired token. Please check your API key and username."
                    self.authToken = nil // Clear token so it's refetched next time
                    self.isLoading = false
                }
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                DispatchQueue.main.async {
                    self.errorMessage = "API Error: \(httpResponse.statusCode) - \(responseBody)"
                    self.isLoading = false
                }
                return
            }

            // Define a temporary struct to match the API response structure
            struct APIContract: Decodable {
                let id: String
                let name: String
                let description: String
                let tickSize: Double
                let tickValue: Double
                let activeContract: Bool
            }
            struct SearchResponse: Decodable {
                let contracts: [APIContract]
                let success: Bool
                let errorCode: Int?
                let errorMessage: String?
            }

            let decodedResponse = try JSONDecoder().decode(SearchResponse.self, from: data)

            if decodedResponse.success {
                let items = decodedResponse.contracts.map {
                    WatchlistItem(id: $0.id, name: $0.name, description: $0.description, tickSize: $0.tickSize, tickValue: $0.tickValue, activeContract: $0.activeContract)
                }
                DispatchQueue.main.async {
                    self.searchResults = items
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = decodedResponse.errorMessage ?? "API returned success false with no error message."
                    self.isLoading = false
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Network request failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}