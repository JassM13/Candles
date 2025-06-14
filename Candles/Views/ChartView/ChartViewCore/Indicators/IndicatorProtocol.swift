//
//  IndicatorProtocol.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI
import CoreGraphics // For CGFloat, CGPoint etc.

// Protocol defining the requirements for an indicator
protocol Indicator: Identifiable {
    var id: UUID { get }
    var name: String { get }
    var color: Color { get set } // Allow color customization

    // Calculates the indicator data based on OHLC data
    // Returns an array of Any, as different indicators might produce different data types (e.g., single line, multiple lines, shapes)
    func calculate(ohlcData: [OHLCDataPoint]) -> [Any]

    // Draws the indicator on the chart
    // context: The graphics context for drawing
    // geometry: Provides size information of the drawing area
    // ohlcData: The original OHLC data for reference (e.g., to align with candles)
    // indicatorData: The pre-calculated data from the `calculate` method
    // priceMin: The minimum price in the current view range for scaling
    // priceMax: The maximum price in the current view range for scaling
    func draw(context: inout GraphicsContext, geometry: GeometryProxy, ohlcData: [OHLCDataPoint], indicatorData: [Any], priceMin: Double, priceMax: Double)
}

// Optional: A base class or struct for common indicator properties if needed
// struct BaseIndicatorSettings {
//     var period: Int
//     var color: Color
// }