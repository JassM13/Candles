//
//  ContentView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI

// Tab enum is now removed, using TabItem from CustomTabBar.swift

struct ContentView: View {
    // Use TabItem from CustomTabBar.swift
    @State private var selectedTab: TabItem = .watchlist

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            ZStack {
                switch selectedTab {
                case .watchlist:
                    WatchlistView()
                case .chart:
                    ChartView()
                case .dom:
                    DOMView()
                case .account:
                    AccountView()
                }
            }
            .animation(.easeInOut, value: selectedTab)  // Animate content switching

            Divider()

            // Custom Tab Bar
            // Ensure CustomTabBar is correctly using the @Binding for TabItem
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)  // Ensure tab bar is not pushed by keyboard
    }
}

#Preview {
    ContentView()
}
