//
//  NWOGIndicator.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI
import CoreGraphics

// Placeholder for NWOG (New Way of Guessing) Indicator
struct NWOGIndicator: Indicator {
    let id = UUID()
    var name: String = "NWOG (Demo)"
    var color: Color = .purple

    init(color: Color = .purple, name: String = "NWOG (Demo)") {
        self.color = color
        self.name = name
    }

    // NWOG calculation logic would be complex and is TBD.
    // For now, it returns an empty array or some dummy data.
    func calculate(ohlcData: [OHLCDataPoint]) -> [Any] {
        // Example: Could return an array of structs or tuples representing signals or zones
        // For demo, let's return a few dummy points that could represent something.
        // This is highly dependent on what NWOG actually plots.
        // If it's just lines, it would be similar to SMA's [Double]
        // If it's shapes or signals, the structure of [Any] would differ.
        
        // For this placeholder, let's assume it might plot some horizontal lines at specific candles
        var nwogPoints: [(index: Int, value: Double, type: String)] = []
        if ohlcData.count > 10 {
            nwogPoints.append((index: 5, value: ohlcData[5].low - 2, type: "support_zone_start"))
            nwogPoints.append((index: 8, value: ohlcData[5].low - 2, type: "support_zone_end"))
        }
        if ohlcData.count > 20 {
            nwogPoints.append((index: 15, value: ohlcData[15].high + 2, type: "resistance_zone_start"))
            nwogPoints.append((index: 18, value: ohlcData[15].high + 2, type: "resistance_zone_end"))
        }
        return nwogPoints // This is just an example structure
    }

    // NWOG drawing logic is TBD.
    // This would depend on the data returned by calculate().
    func draw(context: inout GraphicsContext, geometry: GeometryProxy, ohlcData: [OHLCDataPoint], indicatorData: [Any], priceMin: Double, priceMax: Double) {
        guard let nwogPoints = indicatorData as? [(index: Int, value: Double, type: String)], !nwogPoints.isEmpty else { return }

        let chartHeight = geometry.size.height
        let chartWidth = geometry.size.width
        let priceRange = priceMax - priceMin
        guard priceRange > 0 else { return }
        let stepX = chartWidth / CGFloat(ohlcData.count)

        // Example drawing: Draw horizontal lines for the dummy points
        var currentPath: Path? = nil
        var lastType: String? = nil

        for point in nwogPoints {
            guard point.index < ohlcData.count else { continue }
            
            let x = CGFloat(point.index) * stepX + stepX / 2
            let y = chartHeight * CGFloat(1.0 - (point.value - priceMin) / priceRange)

            if point.type.hasSuffix("_start") {
                if currentPath != nil {
                    // Finalize previous path if type changed or it's a new start
                    if let path = currentPath {
                        context.stroke(path, with: .color(self.color.opacity(0.5)), lineWidth: 2)
                    }
                }
                currentPath = Path()
                currentPath?.move(to: CGPoint(x: x, y: y))
                lastType = String(point.type.dropLast("_start".count))
            } else if point.type.hasSuffix("_end") && String(point.type.dropLast("_end".count)) == lastType {
                currentPath?.addLine(to: CGPoint(x: x, y: y))
                if let path = currentPath {
                    context.stroke(path, with: .color(self.color), style: StrokeStyle(lineWidth: 2, dash: [5]))
                }
                currentPath = nil
                lastType = nil
            } else {
                // Potentially draw individual points or other shapes
                let rect = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: rect), with: .color(self.color))
            }
        }
        
        // If a path was started but not ended (e.g. only a _start point)
        if let path = currentPath {
             context.stroke(path, with: .color(self.color.opacity(0.3)), lineWidth: 2)
        }
    }
}