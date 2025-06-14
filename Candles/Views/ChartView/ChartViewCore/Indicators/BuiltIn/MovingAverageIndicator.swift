//
//  MovingAverageIndicator.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI
import CoreGraphics

struct MovingAverageIndicator: Indicator {
    let id = UUID()
    var name: String
    var color: Color
    let period: Int

    init(period: Int, color: Color = .blue, name: String? = nil) {
        self.period = period
        self.color = color
        self.name = name ?? "SMA(\(period))"
    }

    func calculate(ohlcData: [OHLCDataPoint]) -> [Any] {
        guard ohlcData.count >= period else { return [] }
        var smaValues: [Double] = []
        for i in (period - 1)..<ohlcData.count {
            let sum = ohlcData[(i - period + 1)...i].reduce(0) { $0 + $1.close }
            smaValues.append(sum / Double(period))
        }
        // The SMA values correspond to the ohlcData points starting from index `period - 1`
        // To align with the chart, we might need to pad the beginning or handle offsets during drawing.
        // For simplicity here, the returned array is shorter than ohlcData.
        return smaValues
    }

    func draw(context: inout GraphicsContext, geometry: GeometryProxy, ohlcData: [OHLCDataPoint], indicatorData: [Any], priceMin: Double, priceMax: Double) {
        guard let smaValues = indicatorData as? [Double], !smaValues.isEmpty, ohlcData.count >= period else { return }

        let chartHeight = geometry.size.height
        let chartWidth = geometry.size.width
        let priceRange = priceMax - priceMin
        guard priceRange > 0 else { return }

        let stepX = chartWidth / CGFloat(ohlcData.count)

        var path = Path()

        // Start drawing from the first point where SMA is available
        let firstSmaIndex = period - 1
        guard firstSmaIndex < ohlcData.count else { return } 

        let firstX = CGFloat(firstSmaIndex) * stepX + stepX / 2 // Center of the candle
        let firstYValue = smaValues[0]
        let firstY = chartHeight * CGFloat(1.0 - (firstYValue - priceMin) / priceRange)
        path.move(to: CGPoint(x: firstX, y: firstY))

        for (index, value) in smaValues.enumerated() {
            // The SMA value at smaValues[index] corresponds to ohlcData[firstSmaIndex + index]
            let x = CGFloat(firstSmaIndex + index) * stepX + stepX / 2
            let y = chartHeight * CGFloat(1.0 - (value - priceMin) / priceRange)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }
}