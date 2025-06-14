//
//  ChartView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI

struct ChartView: View {
    // Use @StateObject for the ViewModel as this view owns it.
    @StateObject private var viewModel = ChartViewModel()
    @State private var showingIndicatorSheet = false

    var body: some View {
        // Using NavigationView to provide a title bar and toolbar items
        NavigationView {
            VStack(spacing: 0) { // Use 0 spacing if elements should touch
                // Timeframe Picker
                Picker("Timeframe", selection: $viewModel.selectedTimeframe) {
                    ForEach(ChartTimeframe.allCases) { timeframe in
                        Text(timeframe.rawValue.uppercased()).tag(timeframe)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding() // Add some padding around the picker
                .onChange(of: viewModel.selectedTimeframe) { newTimeframe in
                    viewModel.changeTimeframe(to: newTimeframe)
                }

                // Chart Area
                if viewModel.isLoading {
                    ProgressView("Loading Chart...")
                    Spacer() // Push ProgressView to center or top
                } else if viewModel.ohlcData.isEmpty {
                    Text("No chart data available.")
                        .foregroundColor(.gray)
                    Spacer() // Push Text to center or top
                } else {
                    CandleStickChartView(
                        dataPoints: viewModel.ohlcData, 
                        indicatorManager: viewModel.indicatorManager
                    )
                    // The CandleStickChartView will take the remaining space
                }
            }
            .navigationTitle("Trading Chart") // Set a title for the chart view
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingIndicatorSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3") // Icon for managing indicators
                    }
                }
                // Potentially add other toolbar items (e.g., symbol selection, drawing tools)
            }
            .sheet(isPresented: $showingIndicatorSheet) {
                // Present the IndicatorSelectionView as a sheet
                IndicatorSelectionView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Preview

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        ChartView()
            .preferredColorScheme(.dark) // Example: Preview in dark mode
    }
}