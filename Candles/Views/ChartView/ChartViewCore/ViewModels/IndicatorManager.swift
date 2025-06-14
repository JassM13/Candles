//
//  IndicatorManager.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI
import Combine

class IndicatorManager: ObservableObject {
    @Published var activeIndicators: [Indicator] = []
    @Published var indicatorData: [UUID: [Any]] = [:] // Stores calculated data for each indicator

    private var cancellables = Set<AnyCancellable>()

    func addIndicator(_ indicator: Indicator, ohlcData: [OHLCDataPoint]) {
        guard !activeIndicators.contains(where: { $0.id == indicator.id }) else { return }
        activeIndicators.append(indicator)
        recalculateIndicator(indicator, ohlcData: ohlcData)
        objectWillChange.send() // Ensure UI updates
    }

    func removeIndicator(_ indicator: Indicator) {
        activeIndicators.removeAll { $0.id == indicator.id }
        indicatorData.removeValue(forKey: indicator.id)
        objectWillChange.send() // Ensure UI updates
    }

    func recalculateIndicator(_ indicator: Indicator, ohlcData: [OHLCDataPoint]) {
        guard !ohlcData.isEmpty else {
            indicatorData[indicator.id] = []
            return
        }
        let calculatedData = indicator.calculate(ohlcData: ohlcData)
        indicatorData[indicator.id] = calculatedData
    }

    func recalculateAllIndicators(ohlcData: [OHLCDataPoint]) {
        guard !ohlcData.isEmpty else {
            activeIndicators.forEach { indicatorData[$0.id] = [] }
            objectWillChange.send()
            return
        }
        for indicator in activeIndicators {
            recalculateIndicator(indicator, ohlcData: ohlcData)
        }
        objectWillChange.send() // Notify observers after all recalculations
    }
    
    func updateIndicatorColor(indicatorId: UUID, newColor: Color) {
        if let index = activeIndicators.firstIndex(where: { $0.id == indicatorId }) {
            activeIndicators[index].color = newColor
            objectWillChange.send()
        }
    }
}