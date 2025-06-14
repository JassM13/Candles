//
//  ChartViewModel.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI
import Combine

class ChartViewModel: ObservableObject {
    @Published var ohlcData: [OHLCDataPoint] = []
    @Published var selectedTimeframe: ChartTimeframe = .fifteenMin
    @Published var isLoading: Bool = false
    @Published var indicatorManager = IndicatorManager()
    // TODO: Add properties for selected symbol, data provider, etc.

    private var cancellables = Set<AnyCancellable>()

    // TODO: Inject a data provider service
    // private let dataProvider: ChartDataProvider

    init(/*dataProvider: ChartDataProvider = DummyDataProvider()*/) {
        // self.dataProvider = dataProvider
        setupSubscriptions()
        loadChartData()
    }

    private func setupSubscriptions() {
        // Observe changes in OHLC data to recalculate indicators
        $ohlcData
            .dropFirst() // Don't recalculate on initial load if loadChartData handles it
            .receive(on: DispatchQueue.main) // Ensure updates on main thread
            .sink { [weak self] newData in
                guard let self = self else { return }
                // Only recalculate if data is not empty, otherwise manager will clear
                if !newData.isEmpty {
                    self.indicatorManager.recalculateAllIndicators(ohlcData: newData)
                } else {
                    self.indicatorManager.recalculateAllIndicators(ohlcData: []) // Clears data
                }
            }
            .store(in: &cancellables)

        // Observe changes from indicatorManager to propagate to views if necessary
        // (Often @Published in IndicatorManager is enough, but explicit observation can be useful)
        indicatorManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func loadChartData() {
        isLoading = true
        // Replace with actual data fetching logic (e.g., from a DataProvider)
        // For now, using dummy data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Simulate network delay
            // let newData = self.dataProvider.fetchData(for: self.selectedSymbol, timeframe: self.selectedTimeframe)
            let newData = self.generateDummyData(for: self.selectedTimeframe)
            self.ohlcData = newData // This will trigger the sink above for indicator recalculation
            self.isLoading = false
        }
    }

    func changeTimeframe(to timeframe: ChartTimeframe) {
        guard selectedTimeframe != timeframe else { return }
        selectedTimeframe = timeframe
        // ohlcData will be cleared first, then new data loaded.
        // This ensures indicators are cleared before new data arrives.
        ohlcData = [] 
        loadChartData() 
    }

    // MARK: - Indicator Management
    func addSampleIndicator(type: String) {
        // This is a simplified way to add indicators. 
        // A more robust solution might involve a factory or a registry.
        let indicator: Indicator?
        switch type.uppercased() {
        case "SMA":
            indicator = MovingAverageIndicator(period: 20, color: .orange)
        case "NWOG":
            indicator = NWOGIndicator(color: .purple)
        // Example: Adding another SMA with different params
        case "SMA_50_RED":
            indicator = MovingAverageIndicator(period: 50, color: .red, name: "SMA(50)")
        default:
            print("Unknown indicator type: \(type)")
            indicator = nil
        }

        if let ind = indicator {
            indicatorManager.addIndicator(ind, ohlcData: ohlcData)
        }
    }

    func removeIndicator(_ indicator: Indicator) {
        indicatorManager.removeIndicator(indicator)
    }

    func listActiveIndicators() -> [Indicator] {
        return indicatorManager.activeIndicators
    }
    
    func updateIndicatorColor(indicatorId: UUID, newColor: Color) {
        indicatorManager.updateIndicatorColor(indicatorId: indicatorId, newColor: newColor)
    }

    // MARK: - Dummy Data Generation (Placeholder)
    // This should ideally be in a separate DataProvider service.
    private func generateDummyData(for timeframe: ChartTimeframe) -> [OHLCDataPoint] {
        var dataPoints: [OHLCDataPoint] = []
        let calendar = Calendar.current
        let now = Date()
        let numberOfCandles: Int
        switch timeframe {
        case .fiveMin: numberOfCandles = 288 // Approx 1 day (24 * 60 / 5)
        case .fifteenMin: numberOfCandles = 192 // Approx 2 days (48 * 60 / 15)
        case .oneHour: numberOfCandles = 168 // Approx 1 week (7 * 24)
        }

        var lastClose = Double.random(in: 100...200)

        for i in 0..<numberOfCandles {
            let date = calendar.date(byAdding: .minute, value: -i * timeframe.toMinutes(), to: now)!
            let open: Double
            // Ensure smooth transition for the first candle based on lastClose
            if i == 0 {
                open = lastClose // Start with the previous close to avoid large gap if we were appending
            } else {
                 // More realistic: open is previous candle's close
                open = dataPoints.last?.close ?? (lastClose + Double.random(in: -0.5...0.5)) 
            }
            
            let priceMovement = Double.random(in: -2...2) * (1 + Double(i % 10) * 0.05) // Add some variance
            var close = open + priceMovement
            // Ensure close is not drastically far from open for a single candle
            close = max(open * 0.95, min(open * 1.05, close))

            let high = max(open, close) + Double.random(in: 0.1...2.5)
            let low = min(open, close) - Double.random(in: 0.1...2.5)
            
            // Ensure high >= max(open, close) and low <= min(open, close)
            let finalHigh = max(high, open, close)
            let finalLow = min(low, open, close)

dataPoints.append(
                OHLCDataPoint(date: date, open: open, high: finalHigh, low: finalLow, close: close)
            )
            lastClose = close // Update lastClose for the next iteration's potential use
        }
        return dataPoints.reversed() // Data should be chronological (oldest first)
    }
}