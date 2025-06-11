//
//  WatchlistView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI

struct WatchlistView: View {
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    // Using a simple instance here. For more complex apps, consider dependency injection.
    private let networkManager = NetworkManager.shared

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Searching...")
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if searchResults.isEmpty && !searchText.isEmpty && !isLoading {
                    Text("No results found for \"\(searchText)\".")
                        .foregroundColor(.gray)
                } else {
                    List(searchResults) { result in
                        VStack(alignment: .leading) {
                            Text(result.symbol).font(.headline)
                            Text(result.name).font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Watchlist")
        }
        .searchable(text: $searchText, prompt: "Search Symbols")
        .onSubmit(of: .search) {
            performSearch()
        }
        // Optional: Trigger search as user types
        // .onChange(of: searchText) { newValue in
        //     if !newValue.isEmpty {
        //         performSearch(searchTerm: newValue)
        //     } else {
        //         searchResults = []
        //         errorMessage = nil
        //     }
        // }
    }

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        networkManager.searchSymbols(searchTerm: searchText) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let symbols):
                    self.searchResults = symbols
                    if symbols.isEmpty {
                        self.errorMessage = "No symbols found matching your query."
                    }
                case .failure(let error):
                    self.searchResults = []
                    self.errorMessage = "Failed to fetch symbols: \(error.localizedDescription)"
                    // More specific error handling can be added here based on NetworkError cases
                    switch error {
                    case .invalidURL:
                        self.errorMessage = "There was an issue with the API URL."
                    case .requestFailed(let underlyingError):
                        self.errorMessage =
                            "Network request failed: \(underlyingError.localizedDescription)"
                    case .invalidResponse:
                        self.errorMessage = "Received an invalid response from the server."
                    case .decodingError(let underlyingError):
                        self.errorMessage =
                            "Failed to decode the server response: \(underlyingError.localizedDescription)"
                    case .noData:
                        self.errorMessage = "No data received from the server."
                    }
                }
            }
        }
    }
}

struct WatchlistView_Previews: PreviewProvider {
    static var previews: some View {
        WatchlistView()
    }
}
