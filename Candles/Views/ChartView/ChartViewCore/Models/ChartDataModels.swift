//
//  ChartDataModels.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import Foundation

// MARK: - Data Structures
struct OHLCDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}

// Enum for Timeframe
enum ChartTimeframe: String, CaseIterable, Identifiable {
    case fiveMin = "5m"
    case fifteenMin = "15m"
    case oneHour = "1h"
    // Add more as needed

    var id: String { self.rawValue }

    func toMinutes() -> Int {
        switch self {
        case .fiveMin: return 5
        case .fifteenMin: return 15
        case .oneHour: return 60
        }
    }
}