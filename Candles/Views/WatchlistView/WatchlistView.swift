//
//  WatchlistView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI

struct WatchlistView: View {
    @State private var searchText = ""
    @State private var searchResults: [Contract] = []
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
                    List(searchResults) { contract in
                        VStack(alignment: .leading) {
                            Text(contract.name).font(.headline) // Assuming 'name' is the symbol-like identifier
                            Text(contract.description).font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Watchlist")
        }
        .searchable(text: $searchText, prompt: "Search Symbols")
    }
    
    
}
