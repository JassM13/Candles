//
//  SmallMediumCandleWidget.swift
//  Widgets
//
//  Created by Jaspreet Malak on 6/12/25.
//

import WidgetKit
import SwiftUI

// Using existing OHLCDataPoint and getDummyData from Common or a new simplified one if needed
// For now, let's assume we can reuse or adapt them.

struct SmallMediumProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SmallMediumEntry {
        SmallMediumEntry(date: Date(), configuration: ConfigurationAppIntent(), ohlcData: getDummyData(for: .fifteenMin))
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SmallMediumEntry {
        SmallMediumEntry(date: Date(), configuration: configuration, ohlcData: getDummyData(for: configuration.selectedTimeframe))
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SmallMediumEntry> {
        var entries: [SmallMediumEntry] = []
        let currentDate = Date()
        let entry = SmallMediumEntry(date: currentDate, configuration: configuration, ohlcData: getDummyData(for: configuration.selectedTimeframe))
        entries.append(entry)

        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        return Timeline(entries: entries, policy: .after(nextUpdateDate))
    }
}

struct SmallMediumEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let ohlcData: [OHLCDataPoint] // Reusing OHLCDataPoint for simplicity
}

struct SmallMediumCandleWidgetView : View {
    var entry: SmallMediumProvider.Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.configuration.selectedSymbol)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Spacer()
                Text(entry.configuration.selectedTimeframe.rawValue)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            SimpleLineChartView(dataPoints: entry.ohlcData)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .widgetBackground(Color.black.opacity(0.8))
    }
}

struct SimpleLineChartView: View {
    let dataPoints: [OHLCDataPoint]
    private var closePrices: [Double] { dataPoints.map { $0.close } }
    private var minPrice: Double { closePrices.min() ?? 0 }
    private var maxPrice: Double { closePrices.max() ?? 0 }

    var body: some View {
        GeometryReader { geometry in
            let priceRange = maxPrice - minPrice
            let hasValidData = !dataPoints.isEmpty && priceRange > 0

            ZStack(alignment: .leading) {
                // Sleek Axis Lines
                // Y-Axis Line (Price)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                }
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)

                // X-Axis Line (Time)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                }
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                
                // Price Labels (Simplified)
                if hasValidData {
                    VStack {
                        Text(String(format: "%.2f", maxPrice))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(String(format: "%.2f", minPrice))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .frame(height: geometry.size.height)
                    .offset(x: -25) // Adjust to not overlap with chart line
                }

                // Line Chart Path
                if hasValidData {
                    Path { path in
                        for (index, dataPoint) in dataPoints.enumerated() {
                            let xPosition = geometry.size.width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                            let yPosition = (1 - CGFloat((dataPoint.close - minPrice) / priceRange)) * geometry.size.height
                            if index == 0 {
                                path.move(to: CGPoint(x: xPosition, y: yPosition))
                            } else {
                                path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                            }
                        }
                    }
                    .stroke(Color.green, lineWidth: 2)
                } else {
                    Text("No data")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

struct SmallMediumCandleWidget: Widget {
    let kind: String = "SmallMediumCandleWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: SmallMediumProvider()) {
            entry in
            SmallMediumCandleWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Chart")
        .description("A compact view of the candle chart.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled() // To allow full bleed background
    }
}

// Helper to provide a background for the widget, common for iOS 17+
extension View {
    func widgetBackground(_ background: some View) -> some View {
        if #available(iOS 17.0, *) {
            return containerBackground(for: .widget) { // Corrected API usage
                background
            }
        } else {
            return self.background(background)
        }
    }
}