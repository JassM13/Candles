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
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var selectedAccountId: AnyHashable? =
        AccountManager.shared.accounts.first?.id as AnyHashable?  // Default to first account if available, cast to AnyHashable

    @State private var selectedTab: TabItem = .watchlist

    var body: some View {
        VStack(spacing: 0) {  // Use VStack to stack Picker and content
            // Account Picker
            if !accountManager.accounts.isEmpty {
                HStack {
                    Picker("Select Account", selection: $selectedAccountId) {
                        ForEach(accountManager.accounts) { account in
                            Text(account.displayName ?? "Unnamed Account")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .tag(account.id as AnyHashable?)  // Tag as AnyHashable

                            // Display sub-accounts if they exist
                            if let subAccounts = account.subAccounts, !subAccounts.isEmpty {
                                ForEach(subAccounts) { subAccount in
                                    Text("  ↳ " + subAccount.name)
                                        .foregroundColor(.white)  // Ensure sub-account text is also visible
                                        .tag(subAccount.id as AnyHashable?)  // Tag as AnyHashable
                                }
                            }
                        }
                    }
                    .accentColor(.white)  // This sets the picker's text color
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedAccountId) { newValue in
                        // Handle account selection change if needed, e.g., update other views
                        if let uuidValue = newValue as? UUID {
                            print("Selected account ID (UUID): \(uuidValue.uuidString)")
                        } else if let intValue = newValue as? Int {
                            print("Selected account ID (Int): \(intValue)")
                        } else {
                            print("Selected account ID: None or unknown type")
                        }
                    }
                    Spacer()
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? .white : .black)
                        .stroke(colorScheme == .dark ? .white : .black, lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)  // Small padding below picker
            } else {
                Text("No accounts available. Add an account in the Account tab.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }

            ZStack(alignment: .bottom) {
                // Content area with padding and rounded corners
                Group {
                    switch selectedTab {
                    case .watchlist:
                        WatchlistView()
                    case .chart:
                        ChartView()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(2)
                    case .dom:
                        DOMView()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(2)
                    case .account:
                        AccountView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 60)  // Reduced space above tab bar
                .padding(.horizontal, 8)
                .animation(.easeInOut, value: selectedTab)  // Animate content switching

                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)  // Ensure tab bar is not pushed by keyboard
        }
        .onAppear {
            // Ensure selectedAccountId is set if accounts load after view appears
            if selectedAccountId == nil, let firstAccountId = accountManager.accounts.first?.id {
                selectedAccountId = firstAccountId as AnyHashable?
            }
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
                    .padding(.horizontal, 16)
                    .background(selectedTab == tab ? Color.blue.opacity(0.2) : Color.clear)
                    .cornerRadius(12)
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                }
                .buttonStyle(PlainButtonStyle())  // To remove default button styling
                .contentShape(Rectangle())  // Ensure the entire frame is tappable
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)  // Further reduced vertical padding
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: -5)
        )
        .padding(.bottom, 0)  // Minimal bottom padding to get closer to swipe area
    }
}

#Preview {
    MainView()
}
