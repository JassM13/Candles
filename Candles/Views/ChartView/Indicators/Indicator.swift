//
//  Indicator.swift
//  Candles
//
//  Created by Trae AI on DATE_STAMP.
//

import SwiftUI

// Protocol for chart indicators
protocol Indicator {
    var id: UUID { get }
    var name: String { get }

    // Function to calculate indicator values based on OHLC data
    // Returns an array of `IndicatorPoint` which can be generic or specific
    func calculate(ohlcData: [OHLCDataPoint]) -> [IndicatorPoint]

    // Function to draw the indicator on the chart
    // `context` would be a drawing context (e.g., GraphicsContext)
    // `geometry` provides size information
    // `ohlcData` and `indicatorData` are for reference
    // `priceMin`, `priceMax` for scaling
    func draw(
        context: GraphicsContext, geometry: GeometryProxy, ohlcData: [OHLCDataPoint],
        indicatorData: [IndicatorPoint], priceMin: Double, priceMax: Double)
}

// Represents a single data point for an indicator (can be simple value or multiple lines)
struct IndicatorPoint: Identifiable {
    let id = UUID()
    let date: Date  // To align with OHLC data
    let values: [Double?]  // Allows for multi-line indicators or indicators with optional values

    init(date: Date, values: [Double?]) {
        self.date = date
        self.values = values
    }

    // Convenience for single value indicators
    init(date: Date, value: Double?) {
        self.date = date
        self.values = [value]
    }
}

// Example: A simple Moving Average Indicator conforming to the protocol
struct MovingAverageIndicator: Indicator {
    let id = UUID()
    let name: String
    let period: Int
    let color: Color

    init(name: String = "SMA", period: Int = 20, color: Color = .blue) {
        self.name = "\(name)(\(period))"
        self.period = period
        self.color = color
    }

    func calculate(ohlcData: [OHLCDataPoint]) -> [IndicatorPoint] {
        guard ohlcData.count >= period else { return [] }
        var results: [IndicatorPoint] = []
        for i in (period - 1)..<ohlcData.count {
            let slice = ohlcData[(i - period + 1)...i]
            let sum = slice.reduce(0) { $0 + $1.close }  // Calculate SMA on close price
            let average = sum / Double(period)
            results.append(IndicatorPoint(date: ohlcData[i].date, value: average))
        }
        return results
    }

    func draw(
        context: GraphicsContext, geometry: GeometryProxy, ohlcData: [OHLCDataPoint],
        indicatorData: [IndicatorPoint], priceMin: Double, priceMax: Double
    ) {
        guard !indicatorData.isEmpty, priceMax > priceMin else { return }

        let chartHeight = geometry.size.height
        let chartWidth = geometry.size.width
        let dataCount = CGFloat(ohlcData.count)  // Use ohlcData for x-axis alignment
        let stepX = chartWidth / max(1, dataCount - 1)

        var path = Path()
        var firstPoint = true

        for (index, point) in indicatorData.enumerated() {
            // Find corresponding ohlcData index to align x-position
            guard let ohlcIndex = ohlcData.firstIndex(where: { $0.date == point.date }) else {
                continue
            }
            guard let value = point.values.first, let actualValue = value else { continue }  // Ensure value exists

            let yPosition =
                chartHeight * CGFloat(1.0 - (actualValue - priceMin) / (priceMax - priceMin))
            let xPosition = CGFloat(ohlcIndex) * stepX

            if firstPoint {
                path.move(to: CGPoint(x: xPosition, y: yPosition))
                firstPoint = false
            } else {
                path.addLine(to: CGPoint(x: xPosition, y: yPosition))
            }
        }
        context.stroke(path, with: .color(color), lineWidth: 2)
    }
}
