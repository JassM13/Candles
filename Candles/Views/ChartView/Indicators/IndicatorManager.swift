//
//  IndicatorManager.swift
//  Candles
//
//  Created by Trae AI on DATE_STAMP.
//

import Combine
import SwiftUI

class IndicatorManager: ObservableObject {
    @Published var activeIndicators: [Indicator] = []
    @Published var indicatorData: [UUID: [IndicatorPoint]] = [:]  // Keyed by Indicator ID

    private var cancellables = Set<AnyCancellable>()

    // Add an indicator to the chart
    func addIndicator(_ indicator: Indicator, ohlcData: [OHLCDataPoint]) {
        if !activeIndicators.contains(where: { $0.id == indicator.id }) {
            activeIndicators.append(indicator)
            recalculateIndicator(indicator, ohlcData: ohlcData)
        }
    }

    // Remove an indicator from the chart
    func removeIndicator(_ indicator: Indicator) {
        activeIndicators.removeAll { $0.id == indicator.id }
        indicatorData.removeValue(forKey: indicator.id)
    }

    // Recalculate a specific indicator
    func recalculateIndicator(_ indicator: Indicator, ohlcData: [OHLCDataPoint]) {
        let data = indicator.calculate(ohlcData: ohlcData)
        DispatchQueue.main.async {
            self.indicatorData[indicator.id] = data
        }
    }

    // Recalculate all active indicators (e.g., when OHLC data changes)
    func recalculateAllIndicators(ohlcData: [OHLCDataPoint]) {
        for indicator in activeIndicators {
            recalculateIndicator(indicator, ohlcData: ohlcData)
        }
    }

    // Clear all indicators and their data
    func clearAllIndicators() {
        activeIndicators.removeAll()
        indicatorData.removeAll()
    }
}
