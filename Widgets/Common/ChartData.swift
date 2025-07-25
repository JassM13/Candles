//
//  ChartData.swift
//  Widgets
//
//  Created by Jaspreet Malak on 6/12/25.
//

import Foundation
import WidgetKit // For Timeframe enum if it's not moved elsewhere

struct OHLCDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}

// Dummy data for the chart
func getDummyData(for timeframe: Timeframe) -> [OHLCDataPoint] {
    var dataPoints: [OHLCDataPoint] = []
    let calendar = Calendar.current
    let now = Date()
    let numberOfCandles: Int
    switch timeframe {
    case .fiveMin: numberOfCandles = 48 // 4 hours of 5 min candles (doubled)
    case .fifteenMin: numberOfCandles = 32 // 8 hours of 15 min candles (doubled)
    case .oneHour: numberOfCandles = 24 // 24 hours of 1 hour candles (doubled)
    }

    var lastClose = Double.random(in: 100...200) // Start with a random base price

    for i in 0..<numberOfCandles {
        let date = calendar.date(byAdding: .minute, value: -i * timeframeValue(timeframe), to: now)!
        
        let open: Double
        if i == 0 { // For the most recent candle, open can be different from previous close
            open = lastClose + Double.random(in: -1...1) // Slight variation for the first open
        } else {
            open = lastClose // Subsequent candles open at the previous close
        }
        
        let priceMovement = Double.random(in: -5...5) // Max movement for this candle
        let close = open + priceMovement
        
        // Ensure high is above open/close and low is below open/close
        let high = max(open, close) + Double.random(in: 0.1...3) // Add some wick, ensure high > open/close
        let low = min(open, close) - Double.random(in: 0.1...3)  // Add some wick, ensure low < open/close

        dataPoints.append(OHLCDataPoint(date: date, open: open, high: high, low: low, close: close))
        lastClose = close // Update lastClose for the next iteration
    }
    return dataPoints.reversed() // Reverse to have oldest data first, newest last
}

func timeframeValue(_ timeframe: Timeframe) -> Int {
    switch timeframe {
    case .fiveMin: return 5
    case .fifteenMin: return 15
    case .oneHour: return 60
    }
}
