import SwiftUI
import GRDB

struct WatchlistView: View {
    @StateObject private var watchlistManager = WatchlistManager()
    @State private var searchText: String = ""
    @State private var isSearching = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 16) {
                    // Title
                    HStack {
                        Text("Watchlist")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundColor(.primary)
                        Spacer()
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                                watchlistManager.searchResults = []
                            }
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                        }
                    }
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search watchlist and contracts...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .autocapitalization(.allCharacters)
                            .onSubmit {
                                performSearch()
                            }
                            .onChange(of: searchText) { newValue in
                                if newValue.isEmpty {
                                    watchlistManager.searchResults = []
                                } else {
                                    // Debounce search for better performance
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        if searchText == newValue && !newValue.isEmpty {
                                            performSearch()
                                        }
                                    }
                                }
                            }
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                watchlistManager.searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
                .background(Color(.systemBackground))
                
                // Content Section
                if searchText.isEmpty {
                    // Default watchlist view
                    if watchlistManager.watchlistItems.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("Your watchlist is empty")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("Use the search bar above to find and add contracts")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(watchlistManager.watchlistItems) { item in
                                WatchlistItemRow(item: item)
                            }
                            .onDelete(perform: removeItem)
                        }
                        .listStyle(PlainListStyle())
                    }
                } else {
                    // Search results view
                    SearchResultsView(searchText: searchText, watchlistManager: watchlistManager)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await watchlistManager.fetchWatchlistItems()
                }
            }
            
            // Error overlay
            if let errorMessage = watchlistManager.errorMessage, !errorMessage.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .foregroundColor(.primary)
                        Spacer()
                        Button("Dismiss") {
                            watchlistManager.errorMessage = nil
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
    }
    
    // Search function
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        Task {
            await watchlistManager.searchContracts(searchText: searchText)
        }
    }
    

    private func removeItem(at offsets: IndexSet) {
        Task {
            await watchlistManager.removeWatchlistItem(at: offsets)
        }
    }
 }
 
 // MARK: - SearchResultsView Component
 struct SearchResultsView: View {
     let searchText: String
     @ObservedObject var watchlistManager: WatchlistManager
     
     private var filteredWatchlistItems: [WatchlistItem] {
         watchlistManager.watchlistItems.filter { item in
             item.name.localizedCaseInsensitiveContains(searchText) ||
             item.description.localizedCaseInsensitiveContains(searchText)
         }
     }
     
     var body: some View {
         if watchlistManager.isLoading {
             VStack(spacing: 16) {
                 Spacer()
                 ProgressView()
                     .scaleEffect(1.2)
                 Text("Searching contracts...")
                     .foregroundColor(.secondary)
                     .font(.subheadline)
                 Spacer()
             }
         } else {
             List {
                 // Watchlist Results Section
                 if !filteredWatchlistItems.isEmpty {
                     Section {
                         ForEach(filteredWatchlistItems) { item in
                             WatchlistItemRow(item: item)
                         }
                     } header: {
                         HStack {
                             Image(systemName: "star.fill")
                                 .foregroundColor(.yellow)
                                 .font(.caption)
                             Text("Your Watchlist")
                                 .font(.subheadline)
                                 .fontWeight(.semibold)
                                 .foregroundColor(.primary)
                             Spacer()
                             Text("\(filteredWatchlistItems.count)")
                                 .font(.caption)
                                 .foregroundColor(.secondary)
                                 .padding(.horizontal, 8)
                                 .padding(.vertical, 2)
                                 .background(Color(.systemGray5))
                                 .cornerRadius(8)
                         }
                         .padding(.vertical, 4)
                     }
                 }
                 
                 // Contract Search Results Section
                 if !watchlistManager.searchResults.isEmpty {
                     Section {
                         ForEach(watchlistManager.searchResults) { item in
                             ContractSearchRow(item: item, watchlistManager: watchlistManager)
                         }
                     } header: {
                         HStack {
                             Image(systemName: "magnifyingglass")
                                 .foregroundColor(.blue)
                                 .font(.caption)
                             Text("Search Results")
                                 .font(.subheadline)
                                 .fontWeight(.semibold)
                                 .foregroundColor(.primary)
                             Spacer()
                             Text("\(watchlistManager.searchResults.count)")
                                 .font(.caption)
                                 .foregroundColor(.secondary)
                                 .padding(.horizontal, 8)
                                 .padding(.vertical, 2)
                                 .background(Color(.systemGray5))
                                 .cornerRadius(8)
                         }
                         .padding(.vertical, 4)
                     }
                 }
                 
                 // No Results State
                 if filteredWatchlistItems.isEmpty && watchlistManager.searchResults.isEmpty && !watchlistManager.isLoading {
                     Section {
                         VStack(spacing: 16) {
                             Image(systemName: "magnifyingglass")
                                 .font(.system(size: 40))
                                 .foregroundColor(.secondary)
                             Text("No results found")
                                 .font(.headline)
                                 .foregroundColor(.primary)
                             Text("No contracts found for '\(searchText)'")
                                 .foregroundColor(.secondary)
                                 .multilineTextAlignment(.center)
                         }
                         .padding(.vertical, 40)
                         .frame(maxWidth: .infinity)
                     }
                 }
             }
             .listStyle(PlainListStyle())
         }
     }
 }
 
 // MARK: - WatchlistItemRow Component
struct WatchlistItemRow: View {
    let item: WatchlistItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tick Size")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text("\(item.tickSize, specifier: "%.3f")")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Tick Value")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text("$\(item.tickValue, specifier: "%.2f")")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}



 
 // MARK: - ContractSearchRow Component
 struct ContractSearchRow: View {
     let item: WatchlistItem
     @ObservedObject var watchlistManager: WatchlistManager
     
     var body: some View {
         HStack(spacing: 12) {
             VStack(alignment: .leading, spacing: 4) {
                 Text(item.name)
                     .font(.headline)
                     .fontWeight(.semibold)
                     .foregroundColor(.primary)
                 Text(item.description)
                     .font(.subheadline)
                     .foregroundColor(.secondary)
                     .lineLimit(2)
             }
             
             Spacer()
             
             Button {
                 Task {
                     if watchlistManager.isItemInWatchlist(item) {
                         // Already in watchlist - could implement remove functionality here
                     } else {
                         await watchlistManager.addWatchlistItem(item)
                     }
                 }
             } label: {
                 HStack(spacing: 6) {
                     Image(systemName: watchlistManager.isItemInWatchlist(item) ? "checkmark.circle.fill" : "plus.circle.fill")
                     Text(watchlistManager.isItemInWatchlist(item) ? "Added" : "Add")
                         .font(.caption)
                         .fontWeight(.medium)
                 }
                 .foregroundColor(watchlistManager.isItemInWatchlist(item) ? .green : .blue)
                 .padding(.horizontal, 12)
                 .padding(.vertical, 6)
                 .background(
                     RoundedRectangle(cornerRadius: 16)
                         .fill(watchlistManager.isItemInWatchlist(item) ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                 )
             }
             .disabled(watchlistManager.isItemInWatchlist(item))
         }
         .padding(.vertical, 8)
         .padding(.horizontal, 16)
         .background(Color(.systemBackground))
         .cornerRadius(12)
         .overlay(
             RoundedRectangle(cornerRadius: 12)
                 .stroke(Color(.systemGray5), lineWidth: 1)
         )
     }
 }
 
 struct WatchlistView_Previews: PreviewProvider {
    static var previews: some View {
        WatchlistView()
    }
}
