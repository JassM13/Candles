//
//  CustomTabBar.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI

// Enum to represent the different tabs, mirroring ContentView's Tab enum
// This could be refactored to a shared location if used in more places.
enum TabItem: String, CaseIterable, Identifiable {
    case watchlist = "Watchlist"
    case chart = "Chart"
    case dom = "DOM"
    case account = "Account"

    var id: String { self.rawValue }

    var systemImageName: String {
        switch self {
        case .watchlist: return "list.star"
        case .chart: return "chart.bar.xaxis"
        case .dom: return "tablecells"
        case .account: return "person.crop.circle"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    var tabs: [TabItem] = TabItem.allCases

    var body: some View {
        HStack {
            ForEach(tabs) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.systemImageName)
                            .font(.system(size: 20))

                        if selectedTab == tab {
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                // Changed transition for smoother appearance and to avoid sliding over the icon
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .trailing).combined(with: .opacity)
                                    ))
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(selectedTab == tab ? Color.blue.opacity(0.2) : Color.clear)
                    .cornerRadius(10)
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                }
                .buttonStyle(PlainButtonStyle())  // To remove default button styling
                if tab != tabs.last {
                    Spacer()
                }
            }
        }
        .padding()
        .padding(.horizontal)
    }
}

// Moved PreviewWrapper outside of the previews computed property
struct PreviewWrapper: View {
    @State private var currentTab: TabItem = .watchlist
    var body: some View {
        VStack {
            Spacer()
            // Placeholder for content based on currentTab
            Text("Selected View: \(currentTab.rawValue)")
            Spacer()
            CustomTabBar(selectedTab: $currentTab)
        }
    }
}

struct CustomTabBar_Previews: PreviewProvider {
    static var previews: some View {
        // Example of how to use CustomTabBar in a preview
        // You'll need a @State variable in a parent view to hold the selectedTab
        PreviewWrapper()
    }
}
