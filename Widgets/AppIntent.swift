//
//  AppIntent.swift
//  Widgets
//
//  Created by Jaspreet Malak on 6/10/25.
//

import WidgetKit
import AppIntents

enum Timeframe: String, AppEnum {
    case fiveMin = "5m"
    case fifteenMin = "15m"
    case oneHour = "1h"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Timeframe"
    static var caseDisplayRepresentations: [Timeframe: DisplayRepresentation] = [
        .fiveMin: "5m",
        .fifteenMin: "15m",
        .oneHour: "1h"
    ]
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Candle Chart Configuration" }
    static var description: IntentDescription { "Configure your candlestick chart widget." }

    @Parameter(title: "Symbol", default: "AAPL")
    var selectedSymbol: String

    @Parameter(title: "Timeframe", default: .fifteenMin)
    var selectedTimeframe: Timeframe
}
