//
//  LuaIndicator.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import SwiftUI
import CoreGraphics

struct LuaIndicator: Indicator {
    let id = UUID()
    var name: String
    var color: Color
    private let scriptContent: String
    private let luaRunner: LuaScriptRunner // Manages Lua state and execution

    init(name: String, scriptContent: String, color: Color = .green) {
        self.name = name
        self.scriptContent = scriptContent
        self.color = color
        self.luaRunner = LuaScriptRunner(scriptContent: scriptContent)
        print("LuaIndicator '\(name)' initialized.")
    }

    func calculate(ohlcData: [OHLCDataPoint]) -> [Any] {
        print("LuaIndicator '\(name)' calculating...")
        // Delegate calculation to the LuaRunner
        let result = luaRunner.calculate(ohlcData: ohlcData)
        print("LuaIndicator '\(name)' calculation returned \(result.count) items.")
        return result
    }

    func draw(context: inout GraphicsContext, geometry: GeometryProxy, ohlcData: [OHLCDataPoint], indicatorData: [Any], priceMin: Double, priceMax: Double) {
        print("LuaIndicator '\(name)' drawing with \(indicatorData.count) data items.")
        // Option 1: Lua script provides raw data (e.g., array of Doubles), Swift handles drawing logic.
        // This is simpler if Lua scripts primarily focus on calculation.
        if let values = indicatorData as? [Double], !values.isEmpty {
            drawSimpleLine(values: values, context: &context, geometry: geometry, ohlcData: ohlcData, priceMin: priceMin, priceMax: priceMax)
        }
        // Option 2: Lua script provides specific drawing commands.
        // This is more flexible but requires a more complex contract between Swift and Lua.
        /*
        else {
            let drawingCommands = luaRunner.getDrawingInstructions(
                indicatorData: indicatorData, 
                priceMin: priceMin, 
                priceMax: priceMax, 
                geometry: (width: geometry.size.width, height: geometry.size.height)
            )
            executeDrawingCommands(commands: drawingCommands, context: &context)
        }
        */
        // For now, sticking to Option 1 for simplicity with the simulated LuaRunner.
    }

    // Helper function to draw a simple line if indicatorData is [Double]
    // This is similar to how MovingAverageIndicator draws.
    private func drawSimpleLine(values: [Double], context: inout GraphicsContext, geometry: GeometryProxy, ohlcData: [OHLCDataPoint], priceMin: Double, priceMax: Double) {
        guard !values.isEmpty, !ohlcData.isEmpty else { return }

        let chartHeight = geometry.size.height
        let chartWidth = geometry.size.width
        let priceRange = priceMax - priceMin
        guard priceRange > 0 else { return }

        // Determine the X-axis step. This assumes indicator values align with OHLC data points.
        // Lua script would need to ensure this or provide its own X-coordinates.
        // For this example, we assume the Lua script returns values that align with the end of OHLC data, similar to SMA.
        // The number of `values` might be less than `ohlcData.count` (e.g. if it needs a warmup period)
        
        let ohlcCount = CGFloat(ohlcData.count)
        let stepX = chartWidth / ohlcCount
        
        // Find the starting index in ohlcData that corresponds to the first value in `values`.
        // This is a simplification. A robust Lua indicator might need to return (index, value) pairs.
        let dataStartIndex = ohlcData.count - values.count
        guard dataStartIndex >= 0 else {
            print("LuaIndicator '\(name)': Warning - more indicator values than OHLC points. Cannot draw.")
            return
        }

        var path = Path()
        var firstPoint = true

        for (i, value) in values.enumerated() {
            let ohlcIndex = dataStartIndex + i // Corresponding index in ohlcData
            let x = CGFloat(ohlcIndex) * stepX + stepX / 2 // Center of the candle
            let y = chartHeight * CGFloat(1.0 - (value - priceMin) / priceRange)
            
            if y.isFinite {
                if firstPoint {
                    path.move(to: CGPoint(x: x, y: y))
                    firstPoint = false
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }

        if !firstPoint { // Path has points
            context.stroke(path, with: .color(color), lineWidth: 1.5)
            print("LuaIndicator '\(name)' drew a line with \(values.count) points.")
        } else {
            print("LuaIndicator '\(name)': No valid points to draw.")
        }
    }
    
    // Placeholder for executing more complex drawing commands from Lua (Option 2)
    private func executeDrawingCommands(commands: [DrawingCommand], context: inout GraphicsContext) {
        for command in commands {
            switch command {
            case .path(let points):
                if !points.isEmpty {
                    var p = Path()
                    p.move(to: points.first!)
                    for i in 1..<points.count {
                        p.addLine(to: points[i])
                    }
                    context.stroke(p, with: .color(color), lineWidth: 1.5)
                }
            case .line(let start, let end):
                var p = Path()
                p.move(to: start)
                p.addLine(to: end)
                context.stroke(p, with: .color(color), lineWidth: 1.0)
            case .rectangle(let rect):
                context.fill(Path(rect), with: .color(color.opacity(0.3)))
                context.stroke(Path(rect), with: .color(color), lineWidth: 1.0)
            case .text(let str, let pos):
                context.draw(Text(str).foregroundColor(color), at: pos)
            }
        }
    }
}