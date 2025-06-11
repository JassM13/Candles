//
//  Widgets.swift
//  Widgets
//
//  Created by Jaspreet Malak on 6/10/25.
//

import WidgetKit
import SwiftUI

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
    case .fiveMin: numberOfCandles = 24 // 2 hours of 5 min candles
    case .fifteenMin: numberOfCandles = 16 // 4 hours of 15 min candles
    case .oneHour: numberOfCandles = 12 // 12 hours of 1 hour candles
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
            WidgetCenter.shared.reloadTimelines(ofKind: "CandleStickWidget")
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
    let height: CGFloat
    let numberOfTicks = 5 // Number of labels on the price scale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if maxPrice > minPrice && numberOfTicks > 1 {
                ForEach(0..<numberOfTicks, id: \.self) { i in
                    // Calculate price for each tick, ensuring the last tick is maxPrice
                    let price = minPrice + (maxPrice - minPrice) * (Double(i) / Double(numberOfTicks - 1))
                    Text(String(format: "%.2f", price))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if i < numberOfTicks - 1 {
                        Spacer() // Distribute ticks evenly
                    }
                }
            } else if maxPrice == minPrice { // Handle case where all prices are the same
                 Text(String(format: "%.2f", maxPrice))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("--.--") // Placeholder if data is invalid
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .frame(height: height) // Ensure this VStack takes the allocated height
        .padding(.leading, 4) // Padding from the chart candles
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
                        // Candles Area
                        VStack(spacing: 0) {
                            HStack(alignment: .bottom, spacing: 1) {
                                ForEach(entry.ohlcData) { dataPoint in
                                    CandleStickView(dataPoint: dataPoint, minPrice: minPrice, maxPrice: maxPrice)
                                }
                            }
                            .frame(height: geometry.size.height * 0.85) // Main chart area

                            // Time Axis Labels
                            HStack {
                                Text(timeAxisLabel(for: entry.configuration.selectedTimeframe, at: .start, data: entry.ohlcData))
                                    .font(.caption2).foregroundColor(.gray)
                                Spacer()
                                Text(timeAxisLabel(for: entry.configuration.selectedTimeframe, at: .middle, data: entry.ohlcData))
                                    .font(.caption2).foregroundColor(.gray)
                                Spacer()
                                Text(timeAxisLabel(for: entry.configuration.selectedTimeframe, at: .end, data: entry.ohlcData))
                                    .font(.caption2).foregroundColor(.gray)
                            }
                            .frame(height: geometry.size.height * 0.10) // Time axis area
                            .padding(.horizontal, 2)
                        }
                        .frame(width: geometry.size.width * 0.85) // Allocate space for candles and time axis

                        // Price Scale (Right Axis)
                        PriceScaleView(minPrice: minPrice, maxPrice: maxPrice, height: geometry.size.height * 0.85) // Align height with candles
                            .frame(width: geometry.size.width * 0.15) // Allocate space for price scale
                    }
                }
            }
            .frame(maxHeight: .infinity)
            
            // Bottom Bar: Last Price and Update Time
            if let lastDataPoint = entry.ohlcData.last {
                HStack {
                    Text("Last: \(String(format: "%.2f", lastDataPoint.close))")
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                    Text("Updated: \(entry.date, style: .time)")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .padding(.top, 5)
            } else {
                 HStack {
                    Text("Last: --")
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                    Text("Updated: --:--")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .padding(.top, 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure VStack takes full space
    }
}

struct Widgets: Widget {
    let kind: String = "CandleStickWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            WidgetsEntryView(entry: entry)
                .containerBackground(.black, for: .widget) // Changed background for better visibility
        }
        .configurationDisplayName("Candle Chart")
        .description("Displays a candlestick chart for a selected symbol and timeframe.")
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
    Widgets()
} timeline: {
    SimpleEntry(date: .now, configuration: { let intent = ConfigurationAppIntent(); intent.selectedSymbol = "AAPL"; intent.selectedTimeframe = .fifteenMin; return intent }(), ohlcData: getDummyData(for: .fifteenMin))
    SimpleEntry(date: .now, configuration: { let intent = ConfigurationAppIntent(); intent.selectedSymbol = "TSLA"; intent.selectedTimeframe = .oneHour; return intent }(), ohlcData: getDummyData(for: .oneHour))
}
