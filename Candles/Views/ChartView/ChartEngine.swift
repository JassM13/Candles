//
//  ChartEngine.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/12/25.
//

import Combine
import SwiftUI

class ChartEngine: ObservableObject {
    @Published var chartData: [OHLCDataPoint] = []
    @Published var chartType: ChartType = .candlestick
    @Published var visibleRange: Range<Int> = 0..<50
    @Published var priceRange: ClosedRange<Double> = 0...100
    @Published var zoomLevel: Double = 1.0
    @Published var panOffset: CGFloat = 0

    private var maxVisibleCandles: Int = 50
    private let minZoom: Double = 0.1
    private let maxZoom: Double = 10.0

    var visibleCandleCount: Int {
        return visibleRange.count
    }

    init() {
        // Initialize with dummy data
        updateData(getDummyData(for: .fifteenMin))
    }

    func updateData(_ newData: [OHLCDataPoint]) {
        chartData = newData
        calculateVisibleRange()
        calculatePriceRange()
    }

    func zoomIn() {
        let newZoom = min(zoomLevel * 1.1, maxZoom)
        setZoom(newZoom)
    }

    func zoomOut() {
        let newZoom = max(zoomLevel / 1.1, minZoom)
        setZoom(newZoom)
    }

    func smoothZoom(by factor: CGFloat) {
        let newZoom = max(minZoom, min(maxZoom, zoomLevel * Double(factor)))
        setZoom(newZoom)
    }

    func setZoom(_ zoom: Double) {
        zoomLevel = zoom
        maxVisibleCandles = max(10, Int(50 / zoom))
        calculateVisibleRange()
        calculatePriceRange()
    }

    func pan(by offset: CGFloat) {
        // Improved pan sensitivity and bounds checking
        let sensitivity: CGFloat = 0.5
        panOffset += offset * sensitivity

        // Clamp pan offset to prevent over-scrolling
        let maxPan = CGFloat(chartData.count - maxVisibleCandles) * 10
        panOffset = max(-maxPan, min(0, panOffset))

        calculateVisibleRange()
        calculatePriceRange()
    }

    func resetView() {
        zoomLevel = 1.0
        panOffset = 0
        maxVisibleCandles = 50
        calculateVisibleRange()
        calculatePriceRange()
    }

    func toggleChartType() {
        switch chartType {
        case .candlestick:
            chartType = .line
        case .line:
            chartType = .area
        case .area:
            chartType = .candlestick
        }
    }

    private func calculateVisibleRange() {
        guard !chartData.isEmpty else {
            visibleRange = 0..<0
            return
        }

        let totalCandles = chartData.count
        let candlesToShow = min(maxVisibleCandles, totalCandles)

        // Calculate start index based on pan offset with improved sensitivity
        let panAdjustment = Int(panOffset / 5)  // Increased sensitivity for smoother scrolling

        // Ensure we can scroll through the entire dataset
        let startIndex = max(
            0, min(totalCandles - candlesToShow, totalCandles - candlesToShow - panAdjustment))
        let endIndex = min(totalCandles, startIndex + candlesToShow)

        // Only update if the range has actually changed to avoid unnecessary redraws
        let newRange = startIndex..<endIndex
        if newRange != visibleRange {
            visibleRange = newRange
        }
    }

    private func calculatePriceRange() {
        guard !chartData.isEmpty && !visibleRange.isEmpty else {
            priceRange = 0...100
            return
        }

        let visibleData = Array(chartData[visibleRange])
        let highs = visibleData.map { $0.high }
        let lows = visibleData.map { $0.low }

        guard let minPrice = lows.min(), let maxPrice = highs.max() else {
            priceRange = 0...100
            return
        }

        // Add some padding to the price range
        let padding = (maxPrice - minPrice) * 0.1
        priceRange = (minPrice - padding)...(maxPrice + padding)
    }

    // Helper functions for coordinate conversion
    func xPosition(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        guard visibleRange.contains(index) else { return 0 }

        let relativeIndex = index - visibleRange.lowerBound
        let candleWidth = geometry.size.width / CGFloat(visibleRange.count)
        return CGFloat(relativeIndex) * candleWidth + candleWidth / 2
    }

    func yPosition(for price: Double, in geometry: GeometryProxy) -> CGFloat {
        let priceRangeSize = priceRange.upperBound - priceRange.lowerBound
        let normalizedPrice = (price - priceRange.lowerBound) / priceRangeSize
        return geometry.size.height * (1 - CGFloat(normalizedPrice))
    }

    func priceAt(yPosition: CGFloat, in geometry: GeometryProxy) -> Double {
        let normalizedY = 1 - (yPosition / geometry.size.height)
        let priceRangeSize = priceRange.upperBound - priceRange.lowerBound
        return priceRange.lowerBound + (Double(normalizedY) * priceRangeSize)
    }

    func indexAt(xPosition: CGFloat, in geometry: GeometryProxy) -> Int? {
        guard !visibleRange.isEmpty else { return nil }

        let candleWidth = geometry.size.width / CGFloat(visibleRange.count)
        let relativeIndex = Int(xPosition / candleWidth)
        let actualIndex = visibleRange.lowerBound + relativeIndex

        return visibleRange.contains(actualIndex) ? actualIndex : nil
    }
}

// Extension for drawing helpers
extension ChartEngine {
    func candlestickPath(for dataPoint: OHLCDataPoint, at index: Int, in geometry: GeometryProxy)
        -> Path
    {
        let x = xPosition(for: index, in: geometry)
        let openY = yPosition(for: dataPoint.open, in: geometry)
        let highY = yPosition(for: dataPoint.high, in: geometry)
        let lowY = yPosition(for: dataPoint.low, in: geometry)
        let closeY = yPosition(for: dataPoint.close, in: geometry)

        // Adjust candle width based on zoom level for better visualization
        let baseWidth = geometry.size.width / CGFloat(visibleRange.count)
        let candleWidth = min(baseWidth * 0.8, 15)  // Cap maximum width for aesthetics
        let bodyWidth = max(candleWidth * 0.8, 1)  // Ensure minimum width for visibility

        var path = Path()

        // Wick (high-low line)
        path.move(to: CGPoint(x: x, y: highY))
        path.addLine(to: CGPoint(x: x, y: lowY))

        // Body (open-close rectangle)
        let bodyTop = min(openY, closeY)
        let bodyBottom = max(openY, closeY)

        // Ensure minimum body height for visibility
        let minHeight: CGFloat = 1
        let bodyHeight = max(bodyBottom - bodyTop, minHeight)

        let bodyRect = CGRect(
            x: x - bodyWidth / 2,
            y: bodyTop,
            width: bodyWidth,
            height: bodyHeight
        )
        path.addRect(bodyRect)

        return path
    }

    func linePath(in geometry: GeometryProxy) -> Path {
        guard !chartData.isEmpty && !visibleRange.isEmpty else { return Path() }

        var path = Path()
        let visibleData = Array(chartData[visibleRange])

        for (relativeIndex, dataPoint) in visibleData.enumerated() {
            let actualIndex = visibleRange.lowerBound + relativeIndex
            let x = xPosition(for: actualIndex, in: geometry)
            let y = yPosition(for: dataPoint.close, in: geometry)

            if relativeIndex == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }

    func areaPath(in geometry: GeometryProxy) -> Path {
        guard !chartData.isEmpty && !visibleRange.isEmpty else { return Path() }

        var path = Path()
        let visibleData = Array(chartData[visibleRange])
        let bottomY = geometry.size.height

        // Start from bottom left
        if let firstDataPoint = visibleData.first {
            let firstIndex = visibleRange.lowerBound
            let firstX = xPosition(for: firstIndex, in: geometry)
            path.move(to: CGPoint(x: firstX, y: bottomY))
            path.addLine(
                to: CGPoint(x: firstX, y: yPosition(for: firstDataPoint.close, in: geometry)))
        }

        // Draw the line
        for (relativeIndex, dataPoint) in visibleData.enumerated() {
            let actualIndex = visibleRange.lowerBound + relativeIndex
            let x = xPosition(for: actualIndex, in: geometry)
            let y = yPosition(for: dataPoint.close, in: geometry)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        // Close the area
        if let lastDataPoint = visibleData.last {
            let lastIndex = visibleRange.upperBound - 1
            let lastX = xPosition(for: lastIndex, in: geometry)
            path.addLine(to: CGPoint(x: lastX, y: bottomY))
        }

        return path
    }
}
