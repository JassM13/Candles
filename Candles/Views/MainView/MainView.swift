//
//  MainView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI

// Enum to represent the different tabs
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

struct MainView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedTab: TabItem = .watchlist

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content area
            Group {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut, value: selectedTab) // Animate content switching

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom) // Ensure tab bar is not pushed by keyboard
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
                    .padding(.horizontal, 16)
                    .background(selectedTab == tab ? Color.blue.opacity(0.2) : Color.clear)
                    .cornerRadius(10)
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                }
                .buttonStyle(PlainButtonStyle())  // To remove default button styling
                .contentShape(Rectangle()) // Ensure the entire frame is tappable
            }
        }
    }
}


#Preview {
    MainView()
}
