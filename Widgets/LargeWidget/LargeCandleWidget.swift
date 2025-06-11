//
//  Widgets.swift
//  Widgets
//
//  Created by Jaspreet Malak on 6/10/25.
//

import WidgetKit
import SwiftUI



struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), ohlcData: getDummyData(for: .fifteenMin))
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, ohlcData: getDummyData(for: configuration.selectedTimeframe))
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        // Create a single entry for now, you might want to update this based on real data fetching logic
        let entry = SimpleEntry(date: currentDate, configuration: configuration, ohlcData: getDummyData(for: configuration.selectedTimeframe))
        entries.append(entry)

        // Refresh the timeline every 15 minutes (or based on your data update frequency)
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        return Timeline(entries: entries, policy: .after(nextUpdateDate))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let ohlcData: [OHLCDataPoint]
}

struct CandleStickView: View {
    let dataPoint: OHLCDataPoint
    let candleWidth: CGFloat = 6
    let minPrice: Double // Overall min price for scaling
    let maxPrice: Double // Overall max price for scaling

    var body: some View {
        let chartPriceRange = maxPrice - minPrice
        guard chartPriceRange > 0 else { return AnyView(EmptyView()) } // Avoid division by zero

        // Calculate positions based on the overall chart's minPrice and maxPrice
        let highY = CGFloat((maxPrice - dataPoint.high) / chartPriceRange)
        let lowY = CGFloat((maxPrice - dataPoint.low) / chartPriceRange)
        let openY = CGFloat((maxPrice - dataPoint.open) / chartPriceRange)
        let closeY = CGFloat((maxPrice - dataPoint.close) / chartPriceRange)

        return AnyView(
            GeometryReader { geometry in
                let bodyHeightAbs = abs(openY - closeY) * geometry.size.height
                let bodyYPos = min(openY, closeY) * geometry.size.height

                // Wick
                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width / 2, y: highY * geometry.size.height))
                    path.addLine(to: CGPoint(x: geometry.size.width / 2, y: lowY * geometry.size.height))
                }
                .stroke(Color.gray, lineWidth: 1)

                // Body
                Rectangle()
                    .fill(dataPoint.open > dataPoint.close ? Color.red : Color.green)
                    .frame(width: candleWidth, height: max(1, bodyHeightAbs)) // Ensure minimum height of 1 for visibility
                    .position(x: geometry.size.width / 2, y: bodyYPos + bodyHeightAbs / 2)
            }
        )
    }
}

// Helper View for Timeframe Buttons
struct TimeframeButton: View {
    let label: String
    let timeframe: Timeframe
    let current: Timeframe
    let symbol: String // Pass the current symbol to maintain it on timeframe change

    var body: some View {
        Button(action: {
            let intent = ConfigurationAppIntent()
            intent.selectedSymbol = symbol // Use the passed symbol
            intent.selectedTimeframe = timeframe
            WidgetCenter.shared.reloadTimelines(ofKind: "LargeCandleWidget")
        }) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundColor(current == timeframe ? .white : .gray)
        }
        .buttonStyle(.plain)
    }
}

// Helper View for Price Scale
struct PriceScaleView: View {
    let minPrice: Double
    let maxPrice: Double
    let lastClosePrice: Double?
    let lastUpdateTime: Date?
    let height: CGFloat
    let chartWidth: CGFloat // Width of the main chart area, needed for line
    let numberOfTicks = 5 // Number of labels on the price scale

    var body: some View {
        GeometryReader { priceScaleGeometry in
            ZStack(alignment: .topLeading) {
                // Axis lines removed as per request

                VStack(alignment: .leading, spacing: 0) {
                    // Price Ticks
                    if maxPrice > minPrice && numberOfTicks > 1 {
                        ForEach(0..<numberOfTicks, id: \.self) { i in
                            let price = maxPrice - (maxPrice - minPrice) * (Double(i) / Double(numberOfTicks - 1))
                            Text(String(format: "%.2f", price))
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(.leading, 5)
                            if i < numberOfTicks - 1 {
                                Spacer()
                            }
                        }
                    } else if maxPrice == minPrice && maxPrice != 0 {
                         Text(String(format: "%.2f", maxPrice))
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.leading, 5)
                    } else {
                        Text("--.--")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.leading, 5)
                    }
                }
                .frame(height: height) // Height for the price ticks area (main chart height)

                // Last Price Box
                if let lastClose = lastClosePrice, let lastUpdate = lastUpdateTime {
                    let priceRange = maxPrice - minPrice
                    let yPositionRatio = priceRange > 0 ? (maxPrice - lastClose) / priceRange : 0.5
                    let yOffset = CGFloat(yPositionRatio) * height // Position relative to main chart height

                    // Line from chart edge to box (simplified)
                    Path { path in
                        path.move(to: CGPoint(x: -chartWidth, y: yOffset)) // Start from left edge of chart
                        path.addLine(to: CGPoint(x: 0, y: yOffset)) // End at the start of price scale view
                    }
                    .stroke(Color.gray.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))

                    VStack(spacing: 4) { // Changed to HStack for inline display
                        Text(String(format: "%.2f", lastClose))
                            .font(.system(size: 12))
                            .minimumScaleFactor(0.01)
                            .lineLimit(1)
                            .foregroundColor(.black)
                        Text(lastUpdate, style: .time)
                            .font(.system(size: 12))
                            .minimumScaleFactor(0.01)
                            .lineLimit(1)
                            .foregroundColor(.black) // Removed opacity from text
                    }
                    .padding(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                    .background(Color.green) // No background opacity
                    .cornerRadius(3)
                    .offset(x: 5, y: yOffset - 10) // Adjust -10 to center box on line
                }
            }
        }
        .padding(.trailing, 4)
    }
}

struct WidgetsEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Bar: Symbol and Timeframe buttons
            HStack {
                Text(entry.configuration.selectedSymbol)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                // Pill-shaped Timeframe Buttons
                HStack(spacing: 0) {
                    TimeframeButton(label: "5m", timeframe: .fiveMin, current: entry.configuration.selectedTimeframe, symbol: entry.configuration.selectedSymbol)
                    Divider().frame(height: 15).background(Color.gray.opacity(0.5))
                    TimeframeButton(label: "15m", timeframe: .fifteenMin, current: entry.configuration.selectedTimeframe, symbol: entry.configuration.selectedSymbol)
                    Divider().frame(height: 15).background(Color.gray.opacity(0.5))
                    TimeframeButton(label: "1h", timeframe: .oneHour, current: entry.configuration.selectedTimeframe, symbol: entry.configuration.selectedSymbol)
                }
                .background(Capsule().fill(Color.gray.opacity(0.2)))
                .frame(height: 28)
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 5)

            // Chart View, Price Scale, and Time Axis
            GeometryReader { geometry in
                if entry.ohlcData.isEmpty {
                    Text("No data available")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundColor(.gray)
                } else {
                    let allPrices = entry.ohlcData.flatMap { [$0.low, $0.high] }
                    let minPrice = allPrices.min() ?? 0
                    let maxPrice = allPrices.max() ?? 1
                    
                    HStack(spacing: 0) {
                    // Main Chart Area
                    ZStack(alignment: .bottomLeading) {
                        // Axis lines removed

                        VStack(spacing: 0) { // Use VStack to manage chart and time axis separately
                            HStack(spacing: 2) {
                                ForEach(entry.ohlcData) { dataPoint in
                                    CandleStickView(dataPoint: dataPoint, minPrice: minPrice, maxPrice: maxPrice)
                                }
                            }
                            .frame(height: geometry.size.height * 0.9) // Candles take 90% of height

                            // Time Axis Labels (Bottom)
                            HStack {
                                if !entry.ohlcData.isEmpty {
                                    Text(entry.ohlcData.first!.date, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(entry.ohlcData.last!.date, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 5)
                            .frame(height: geometry.size.height * 0.1) // Time axis takes 10% of height
                        }
                        .frame(height: geometry.size.height) // Ensure VStack takes full ZStack height
                    }
                    .frame(width: geometry.size.width * 0.85) // Chart area takes 85% of width

                        // Price Scale (Right Axis)
                        PriceScaleView(minPrice: minPrice, maxPrice: maxPrice, lastClosePrice: entry.ohlcData.last?.close, lastUpdateTime: entry.date, height: geometry.size.height * 0.9, chartWidth: geometry.size.width * 0.85) // Use 90% of height to align with chart
                            .frame(width: geometry.size.width * 0.15, height: geometry.size.height * 0.9) // Explicitly set frame height for PriceScaleView
                            .offset(y: -geometry.size.height * 0.05) // Offset to align with the chart's new bottom (since chart is 90% and time axis is 10%)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure VStack takes full space
    }
}

struct LargeCandleWidget: Widget {
    let kind: String = "LargeCandleWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            WidgetsEntryView(entry: entry)
                .containerBackground(.black, for: .widget) // Changed background for better visibility
        }
        .configurationDisplayName("Candle Chart")
        .description("Displays a candlestick chart for a selected symbol and timeframe.")
        .supportedFamilies([.systemLarge])
    }
}


func timeAxisLabel(for timeframe: Timeframe, at position: TimeAxisPosition, data: [OHLCDataPoint]) -> String {
    guard !data.isEmpty else { return "" }
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HH:mm"

    let firstDate = data.first!.date
    let lastDate = data.last!.date

    switch position {
    case .start:
        return dateFormatter.string(from: firstDate)
    case .middle:
        let middleIndex = data.count / 2
        return dateFormatter.string(from: data[middleIndex].date)
    case .end:
        return dateFormatter.string(from: lastDate)
    }
}

enum TimeAxisPosition {
    case start, middle, end
}

#Preview(as: .systemExtraLarge) { // Changed preview size for better chart visibility
    LargeCandleWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: { let intent = ConfigurationAppIntent(); intent.selectedSymbol = "AAPL"; intent.selectedTimeframe = .fifteenMin; return intent }(), ohlcData: getDummyData(for: .fifteenMin))
    SimpleEntry(date: .now, configuration: { let intent = ConfigurationAppIntent(); intent.selectedSymbol = "TSLA"; intent.selectedTimeframe = .oneHour; return intent }(), ohlcData: getDummyData(for: .oneHour))
}
