import Charts  // For Color, Point, etc. if needed directly, or just SwiftUI
import SwiftUI

// Demo NWOG (Next Week Opening Gap - conceptual example) Indicator
// This is a simplified example. Real NWOG logic would be more complex.
struct NWOGIndicator: Indicator {
    let id = UUID()
    let name: String = "NWOG Demo"
    let color: Color = .purple
    // Potentially add parameters here, e.g., lookback period

    init() {}

    func calculate(ohlcData: [OHLCDataPoint]) -> [IndicatorPoint] {
        var points: [IndicatorPoint] = []
        guard ohlcData.count > 5 else {  // Need at least a week of daily data for a simple demo
            return []
        }

        // Simplified demo: Highlight potential gap areas based on previous week's close and current week's open
        // This is highly conceptual and not a real trading indicator logic.
        for i in 5..<ohlcData.count {
            let prevWeekClose = ohlcData[i - 1].close  // Assuming daily data, this is Friday's close
            let currentOpen = ohlcData[i].open  // Monday's open

            // Demo: if there's a significant difference, mark it.
            // We'll just place a marker at the open price for simplicity.
            if abs(currentOpen - prevWeekClose) > (prevWeekClose * 0.01) {  // 1% gap
                points.append(IndicatorPoint(date: ohlcData[i].date, value: currentOpen))
            }
        }
        return points
    }

    func draw(
        context: GraphicsContext, geometry: GeometryProxy, ohlcData: [OHLCDataPoint],
        indicatorData: [IndicatorPoint], priceMin: Double, priceMax: Double
    ) {
        guard !indicatorData.isEmpty else { return }

        let chartHeight = geometry.size.height
        let chartWidth = geometry.size.width
        let priceRange = priceMax - priceMin
        guard priceRange > 0 else { return }

        let xStep = chartWidth / CGFloat(ohlcData.count)  // Approximate width per data point

        for point in indicatorData {
            if let index = ohlcData.firstIndex(where: { $0.date == point.date }) {
                let xPosition = (CGFloat(index) + 0.5) * xStep  // Center on the candle
                guard let pointValue = point.values.first, let actualValue = pointValue else {
                    continue
                }
                let yPosition = chartHeight - ((actualValue - priceMin) / priceRange * chartHeight)

                // Draw a simple marker (e.g., a circle or a small horizontal line)
                let markerSize: CGFloat = 6
                let rect = CGRect(
                    x: xPosition - markerSize / 2, y: CGFloat(yPosition) - markerSize / 2,
                    width: markerSize, height: markerSize)
                context.fill(Path(ellipseIn: rect), with: .color(color))

                // Example: Draw a small text label "NWOG"
                // let textPoint = CGPoint(x: xPosition + markerSize, y: CGFloat(yPosition) - markerSize)
                // context.draw(Text("NWOG").font(.caption2).foregroundColor(color), at: textPoint)
            }
        }
    }
}
