import SwiftUI
import GRDB

struct WatchlistView: View {
    @StateObject private var watchlistManager = WatchlistManager()
    @State private var searchText: String = ""
    @State private var showingSearchSheet = false

    var body: some View {
        NavigationView {
            VStack {
                if watchlistManager.watchlistItems.isEmpty {
                    Text("Your watchlist is empty.")
                        .foregroundColor(.secondary)
                    Text("Tap the '+' button to search and add contracts.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    List {
                        ForEach(watchlistManager.watchlistItems) { item in
                            VStack(alignment: .leading) {
                                Text(item.name).font(.headline)
                                Text(item.description).font(.subheadline)
                                HStack {
                                    Text("Tick Size: \(item.tickSize, specifier: "%.3f")")
                                    Spacer()
                                    Text("Tick Value: $\(item.tickValue, specifier: "%.2f")")
                                }
                                .font(.caption)
                                .foregroundColor(.gray)
                            }
                        }
                        .onDelete(perform: removeItem)
                    }
                }
            }
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSearchSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !watchlistManager.watchlistItems.isEmpty {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingSearchSheet) {
                ContractSearchView(watchlistManager: watchlistManager)
            }
            .onAppear {
                Task {
                    await watchlistManager.fetchWatchlistItems()
                }
            }
            // Display error messages from WatchlistManager
            if let errorMessage = watchlistManager.errorMessage, !errorMessage.isEmpty {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
                    .onTapGesture { // Allow dismissing the error by tapping
                        watchlistManager.errorMessage = nil
                    }
            }
        }
    }

    private func removeItem(at offsets: IndexSet) {
        Task {
            await watchlistManager.removeWatchlistItem(at: offsets)
        }
    }
}

struct ContractSearchView: View {
    @ObservedObject var watchlistManager: WatchlistManager
    @State private var searchText: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Search for contracts (e.g., NQ, ES)", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                        .onSubmit { // Allow search on submit
                            Task {
                                await watchlistManager.searchContracts(searchText: searchText)
                            }
                        }
                    Button("Search") {
                        Task {
                            await watchlistManager.searchContracts(searchText: searchText)
                        }
                    }
                    .disabled(searchText.isEmpty)
                }
                .padding()

                if watchlistManager.isLoading {
                    ProgressView("Searching...")
                } else if let errorMessage = watchlistManager.errorMessage, !errorMessage.isEmpty {
                    // Error message is now handled in the parent WatchlistView for global display
                    // but we can show a specific search error here if needed or rely on the global one.
                    // For simplicity, relying on the global one displayed in WatchlistView.
                    // If you want a search-specific error, uncomment below:
                    // Text("Search Error: \(errorMessage)")
                    //    .foregroundColor(.red)
                    //    .padding()
                    //    .onTapGesture { watchlistManager.errorMessage = nil }
                    Text("Search failed. Check error message above or try again.")
                         .foregroundColor(.orange)
                         .padding()
                } else if watchlistManager.searchResults.isEmpty && !searchText.isEmpty && !watchlistManager.isLoading {
                    Text("No results found for '\(searchText)'.")
                        .foregroundColor(.secondary)
                } else {
                    List(watchlistManager.searchResults) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name).font(.headline)
                                Text(item.description).font(.subheadline)
                            }
                            Spacer()
                            Button {
                                Task {
                                    if watchlistManager.isItemInWatchlist(item) {
                                        // To remove, user should go back to watchlist and swipe to delete
                                        // Or, change this button to a remove button if preferred
                                    } else {
                                        await watchlistManager.addWatchlistItem(item)
                                    }
                                }
                            } label: {
                                Image(systemName: watchlistManager.isItemInWatchlist(item) ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundColor(watchlistManager.isItemInWatchlist(item) ? .green : .blue)
                            }
                            .disabled(watchlistManager.isItemInWatchlist(item)) // Disable add if already in watchlist
                        }
                    }
                }
                Spacer()
            }
            .navigationTitle("Search Contracts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        watchlistManager.searchResults = [] // Clear search results when dismissing
                        watchlistManager.errorMessage = nil // Clear error messages
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WatchlistView_Previews: PreviewProvider {
    static var previews: some View {
        // WatchlistManager now uses WatchlistDatabaseService.shared internally.
        // For previews, WatchlistView will use the default shared instance.
        // If specific preview data is needed, WatchlistDatabaseService might need
        // a mechanism to be configured for previews (e.g., in-memory DB, mock data).
        
        // Example of how you might populate data for previews if WatchlistDatabaseService
        // supported a preview mode or if you had a way to inject a preview-specific manager:
        // let previewManager = WatchlistManager() // Uses default shared service
        // Task {
        //    try? WatchlistDatabaseService.shared.deleteAllWatchlistItems() // Clear existing
        //    try? WatchlistDatabaseService.shared.saveWatchlistItem(WatchlistItem(id: "CON.F.US.MNQ.H25", name: "MNQH25", description: "Micro E-mini Nasdaq-100: March 2025", tickSize: 0.25, tickValue: 0.5, activeContract: true))
        //    try? WatchlistDatabaseService.shared.saveWatchlistItem(WatchlistItem(id: "CON.F.US.ES.H25", name: "ESH25", description: "E-mini S&P 500: March 2025", tickSize: 0.25, tickValue: 12.5, activeContract: true))
        //    await previewManager.fetchWatchlistItems() // Refresh manager's published list
        // }
        // return WatchlistView().environmentObject(previewManager) // If WatchlistView took manager as @EnvironmentObject

        // Since WatchlistView initializes its own @StateObject from DatabaseService.shared.watchlistManager,
        // we just return WatchlistView(). The preview will use the live shared services.
        // For isolated previews, a more advanced setup for DatabaseService/WatchlistDatabaseService would be needed.
        WatchlistView()
    }
}
