//
//  CandleStickChartView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI

struct CandleStickChartView: View {
    let dataPoints: [OHLCDataPoint]
    @ObservedObject var indicatorManager: IndicatorManager

    // Configuration for candle appearance
    let candleWidthRatio: CGFloat = 0.8  // Relative width of candle body to its allocated space
    let spacingRatio: CGFloat = 0.2  // Relative spacing between candles

    var body: AnyView {
        return AnyView(GeometryReader { geometry in
            if dataPoints.isEmpty {
                Text("No data to display.")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                let (minPrice, maxPrice) = calculatePriceRangeWithIndicators()
                let chartPriceRange = maxPrice - minPrice

                let totalCandleSlots = CGFloat(dataPoints.count)
                // totalCandleSlots is guaranteed to be > 0 here.

                let slotWidth = geometry.size.width / totalCandleSlots
                let candleWidth = slotWidth * candleWidthRatio
                let spacing = slotWidth * spacingRatio

                ZStack {
                    // Candlestick drawing
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(dataPoints.indices, id: \.self) { index in
                            SingleCandleView(
                                dataPoint: dataPoints[index],
                                minPrice: minPrice,
                                maxPrice: maxPrice,
                                chartPriceRange: chartPriceRange,
                                availableHeight: geometry.size.height
                            )
                            .frame(width: candleWidth)
                        }
                    }
                    // Adjust horizontal padding to center the candles within the view
                    // The first candle starts after half a spacing, last ends before half a spacing
                    .padding(.horizontal, spacing / 2)

                    // Indicator Drawing Layer
                    Canvas { context, size in
                        // Iterate through active indicators and draw them
                        for indicator in indicatorManager.activeIndicators {
                            if let data = indicatorManager.indicatorData[indicator.id] {
                                indicator.draw(
                                    context: &context,
                                    geometry: geometry,
                                    ohlcData: dataPoints,
                                    indicatorData: data,
                                    priceMin: minPrice,
                                    priceMax: maxPrice
                                )
                            }
                        }
                    }
                    // .allowsHitTesting(false) // Uncomment if interactions on indicators are not needed
                }
            }
        })

        func calculatePriceRange() -> (min: Double, max: Double) {
            guard !dataPoints.isEmpty else { return (0, 100) }  // Default range if no data
            let lows = dataPoints.map { $0.low }
            let highs = dataPoints.map { $0.high }
            let minVal = lows.min() ?? 0
            let maxVal = highs.max() ?? 100
            // Add some padding to the price range
            let padding = (maxVal - minVal) * 0.05  // 5% padding
            return (minVal - padding, maxVal + padding)
        }

        func calculatePriceRangeWithIndicators() -> (min: Double, max: Double) {
            guard !dataPoints.isEmpty else { return (0, 100) }  // Default if no OHLC data

            var allLows = dataPoints.map { $0.low }
            var allHighs = dataPoints.map { $0.high }

            for indicator in indicatorManager.activeIndicators {
                if let dataValues = indicatorManager.indicatorData[indicator.id] {
                    // Try to extract Double values if the indicator data is an array of Doubles (like SMA)
                    if let doubleValues = dataValues as? [Double] {
                        allLows.append(
                            contentsOf: doubleValues.filter { !$0.isNaN && !$0.isInfinite })
                        allHighs.append(
                            contentsOf: doubleValues.filter { !$0.isNaN && !$0.isInfinite })
                    }
                    // Add more sophisticated extraction if indicatorData contains other types (e.g., tuples, custom structs)
                    // For NWOG example, it returns [(index: Int, value: Double, type: String)]
                    if let nwogPoints = dataValues as? [(index: Int, value: Double, type: String)] {
                        let nwogValues = nwogPoints.map { $0.value }.filter {
                            !$0.isNaN && !$0.isInfinite
                        }
                        allLows.append(contentsOf: nwogValues)
                        allHighs.append(contentsOf: nwogValues)
                    }
                }
            }

            let minVal = allLows.min() ?? dataPoints.map { $0.low }.min() ?? 0
            let maxVal = allHighs.max() ?? dataPoints.map { $0.high }.max() ?? 100

            if minVal == maxVal {  // Avoid division by zero if all values are the same
                return (minVal - 1, maxVal + 1)  // Provide a small default range
            }

            let padding = (maxVal - minVal) * 0.05  // 5% padding on each side
            return (minVal - padding, maxVal + padding)
        }
    }  // Closing brace for CandleStickChartView
}

// MARK: - Single Candle View

// MARK: - Single Candle View

struct SingleCandleView: View {
    let dataPoint: OHLCDataPoint
    let minPrice: Double
    let maxPrice: Double
    let chartPriceRange: Double
    let availableHeight: CGFloat

    var candleColor: Color {
        dataPoint.close > dataPoint.open ? .green : .red
    }

    @ViewBuilder
    var body: some View {
        if chartPriceRange > 0 && availableHeight > 0 {
            // Calculate Y positions for high, low, open, close
            // Y is inverted in SwiftUI (0 at top, max at bottom)
            let highYRatio = (maxPrice - dataPoint.high) / chartPriceRange
            let lowYRatio = (maxPrice - dataPoint.low) / chartPriceRange
            let openYRatio = (maxPrice - dataPoint.open) / chartPriceRange
            let closeYRatio = (maxPrice - dataPoint.close) / chartPriceRange

            let wickTopY = CGFloat(highYRatio) * availableHeight
            let wickBottomY = CGFloat(lowYRatio) * availableHeight

            // Determine the top and bottom of the candle body
            let bodyTopYRatio = min(openYRatio, closeYRatio)
            let bodyBottomYRatio = max(openYRatio, closeYRatio)

            let bodyTopPixel = CGFloat(bodyTopYRatio) * availableHeight
            // Ensure bodyHeightPixel is at least 1 pixel for visibility, even for doji candles
            let bodyHeightPixel = max(
                1.0, CGFloat(bodyBottomYRatio - bodyTopYRatio) * availableHeight)

            // Ensure wick line width is at least 1 pixel
            let wickLineWidth = max(1.0, UIScreen.main.scale / UIScreen.main.scale)  // Effectively 1 logical pixel

            ZStack(alignment: .top) {
                // Wick (the full range from high to low)
                Path { path in
                    // Center the wick horizontally within the candle's allocated width
                    path.move(to: CGPoint(x: wickLineWidth / 2, y: wickTopY))
                    path.addLine(to: CGPoint(x: wickLineWidth / 2, y: wickBottomY))
                }
                .stroke(Color.gray, lineWidth: wickLineWidth)

                // Body of the candle
                Rectangle()
                    .fill(candleColor)
                    .frame(height: bodyHeightPixel)
                    .offset(y: bodyTopPixel)
            }
        } else {
            EmptyView().frame(width: 1)
        }
    }
}