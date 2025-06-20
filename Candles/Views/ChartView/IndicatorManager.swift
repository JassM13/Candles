//
//  IndicatorManager.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/12/25.
//

import SwiftUI
import Combine


struct ChartIndicator: Identifiable {
    let id = UUID()
    var name: String
    var values: [Double]
    var color: Color
    var lineWidth: CGFloat
    var isVisible: Bool
    var script: String?
    var parameters: [String: Any]
    
    init(name: String, values: [Double] = [], color: Color = .blue, lineWidth: CGFloat = 1.5, script: String? = nil, parameters: [String: Any] = [:]) {
        self.name = name
        self.values = values
        self.color = color
        self.lineWidth = lineWidth
        self.isVisible = true
        self.script = script
        self.parameters = parameters
    }
}

struct SavedIndicator: Codable, Identifiable {
    let id = UUID()
    let name: String
    let script: String
    let parameters: [String: String] // Simplified for JSON serialization
    let colorHex: String
    let lineWidth: Double
    let dateCreated: Date
    
    init(from indicator: ChartIndicator) {
        self.name = indicator.name
        self.script = indicator.script ?? ""
        self.parameters = indicator.parameters.mapValues { "\($0)" }
        self.colorHex = indicator.color.toHex()
        self.lineWidth = Double(indicator.lineWidth)
        self.dateCreated = Date()
    }
    
    func toChartIndicator() -> ChartIndicator {
        let color = Color(hex: colorHex) ?? .blue
        let params = parameters.mapValues { $0 as Any }
        return ChartIndicator(
            name: name,
            color: color,
            lineWidth: CGFloat(lineWidth),
            script: script,
            parameters: params
        )
    }
}

class IndicatorManager: ObservableObject {
    @Published var activeIndicators: [ChartIndicator] = []
    @Published var savedIndicators: [SavedIndicator] = []
    @Published var isCalculating = false
    
    private let tickScriptEngine = TickScriptEngine()
    private let userDefaults = UserDefaults.standard
    private let savedIndicatorsKey = "SavedIndicators"
    
    init() {
        loadSavedIndicators()
        setupBuiltInIndicators()
    }
    
    // MARK: - Built-in Indicators
    
    private func setupBuiltInIndicators() {
        // Add some common built-in indicators
        addBuiltInIndicator("SMA(20)", type: .sma, period: 20, color: .blue)
        addBuiltInIndicator("EMA(12)", type: .ema, period: 12, color: .orange)
        addBuiltInIndicator("RSI(14)", type: .rsi, period: 14, color: .purple)
    }
    
    private func addBuiltInIndicator(_ name: String, type: BuiltInIndicatorType, period: Int, color: Color) {
        let indicator = ChartIndicator(
            name: name,
            color: color,
            parameters: ["period": period, "type": type.rawValue]
        )
        // Don't add to active indicators by default
    }
    
    // MARK: - Indicator Management
    
    func addIndicator(_ indicator: ChartIndicator) {
        activeIndicators.append(indicator)
    }
    
    func removeIndicator(_ indicator: ChartIndicator) {
        activeIndicators.removeAll { $0.id == indicator.id }
    }
    
    func toggleIndicatorVisibility(_ indicator: ChartIndicator) {
        if let index = activeIndicators.firstIndex(where: { $0.id == indicator.id }) {
            activeIndicators[index].isVisible.toggle()
        }
    }
    
    func calculateIndicators(for chartData: [OHLCDataPoint]) {
        isCalculating = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            for i in 0..<self.activeIndicators.count {
                var indicator = self.activeIndicators[i]
                
                if let script = indicator.script {
                    // Custom Lua script
                    indicator.values = self.calculateCustomIndicator(script: script, data: chartData, parameters: indicator.parameters)
                } else {
                    // Built-in indicator
                    indicator.values = self.calculateBuiltInIndicator(indicator: indicator, data: chartData)
                }
                
                DispatchQueue.main.async {
                    self.activeIndicators[i] = indicator
                }
            }
            
            DispatchQueue.main.async {
                self.isCalculating = false
            }
        }
    }
    
    private func calculateCustomIndicator(script: String, data: [OHLCDataPoint], parameters: [String: Any]) -> [Double] {
        return tickScriptEngine.executeScript(script, data: data, parameters: parameters)
    }
    
    private func calculateBuiltInIndicator(indicator: ChartIndicator, data: [OHLCDataPoint]) -> [Double] {
        guard let typeString = indicator.parameters["type"] as? String,
              let type = BuiltInIndicatorType(rawValue: typeString),
              let period = indicator.parameters["period"] as? Int else {
            return []
        }
        
        switch type {
        case .sma:
            return calculateSMA(data: data, period: period)
        case .ema:
            return calculateEMA(data: data, period: period)
        case .rsi:
            return calculateRSI(data: data, period: period)
        case .macd:
            return calculateMACD(data: data)
        case .bollinger:
            return calculateBollingerBands(data: data, period: period).middle
        }
    }
    
    // MARK: - Saved Indicators
    
    func saveIndicator(_ indicator: ChartIndicator) {
        let savedIndicator = SavedIndicator(from: indicator)
        savedIndicators.append(savedIndicator)
        saveToDisk()
    }
    
    func loadSavedIndicator(_ savedIndicator: SavedIndicator) {
        let indicator = savedIndicator.toChartIndicator()
        addIndicator(indicator)
    }
    
    func deleteSavedIndicator(_ savedIndicator: SavedIndicator) {
        savedIndicators.removeAll { $0.id == savedIndicator.id }
        saveToDisk()
    }
    
    private func loadSavedIndicators() {
        if let data = userDefaults.data(forKey: savedIndicatorsKey),
           let indicators = try? JSONDecoder().decode([SavedIndicator].self, from: data) {
            savedIndicators = indicators
        }
    }
    
    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(savedIndicators) {
            userDefaults.set(data, forKey: savedIndicatorsKey)
        }
    }
    
    // MARK: - Script Validation
    
    func validateScript(_ script: String) -> (isValid: Bool, error: String?) {
        return tickScriptEngine.validateScript(script)
    }
    
    func testScript(_ script: String, with sampleData: [OHLCDataPoint]) -> [Double] {
        return tickScriptEngine.executeScript(script, data: sampleData, parameters: [:])
    }
}

// MARK: - Built-in Indicator Types

enum BuiltInIndicatorType: String, CaseIterable {
    case sma = "SMA"
    case ema = "EMA"
    case rsi = "RSI"
    case macd = "MACD"
    case bollinger = "Bollinger"
    
    var displayName: String {
        switch self {
        case .sma: return "Simple Moving Average"
        case .ema: return "Exponential Moving Average"
        case .rsi: return "Relative Strength Index"
        case .macd: return "MACD"
        case .bollinger: return "Bollinger Bands"
        }
    }
}

// MARK: - Built-in Indicator Calculations

extension IndicatorManager {
    private func calculateSMA(data: [OHLCDataPoint], period: Int) -> [Double] {
        var result: [Double] = []
        
        for i in 0..<data.count {
            if i < period - 1 {
                result.append(Double.nan)
            } else {
                let sum = data[(i - period + 1)...i].reduce(0) { $0 + $1.close }
                result.append(sum / Double(period))
            }
        }
        
        return result
    }
    
    private func calculateEMA(data: [OHLCDataPoint], period: Int) -> [Double] {
        var result: [Double] = []
        let multiplier = 2.0 / Double(period + 1)
        
        for i in 0..<data.count {
            if i == 0 {
                result.append(data[i].close)
            } else {
                let ema = (data[i].close * multiplier) + (result[i - 1] * (1 - multiplier))
                result.append(ema)
            }
        }
        
        return result
    }
    
    private func calculateRSI(data: [OHLCDataPoint], period: Int) -> [Double] {
        var result: [Double] = []
        var gains: [Double] = []
        var losses: [Double] = []
        
        for i in 1..<data.count {
            let change = data[i].close - data[i - 1].close
            gains.append(max(change, 0))
            losses.append(max(-change, 0))
        }
        
        for i in 0..<data.count {
            if i < period {
                result.append(Double.nan)
            } else {
                let avgGain = gains[(i - period)..<i].reduce(0, +) / Double(period)
                let avgLoss = losses[(i - period)..<i].reduce(0, +) / Double(period)
                
                if avgLoss == 0 {
                    result.append(100)
                } else {
                    let rs = avgGain / avgLoss
                    let rsi = 100 - (100 / (1 + rs))
                    result.append(rsi)
                }
            }
        }
        
        return result
    }
    
    private func calculateMACD(data: [OHLCDataPoint]) -> [Double] {
        let ema12 = calculateEMA(data: data, period: 12)
        let ema26 = calculateEMA(data: data, period: 26)
        
        var macd: [Double] = []
        for i in 0..<data.count {
            macd.append(ema12[i] - ema26[i])
        }
        
        return macd
    }
    
    private func calculateBollingerBands(data: [OHLCDataPoint], period: Int) -> (upper: [Double], middle: [Double], lower: [Double]) {
        let sma = calculateSMA(data: data, period: period)
        var upper: [Double] = []
        var lower: [Double] = []
        
        for i in 0..<data.count {
            if i < period - 1 {
                upper.append(Double.nan)
                lower.append(Double.nan)
            } else {
                let prices = data[(i - period + 1)...i].map { $0.close }
                let mean = sma[i]
                let variance = prices.reduce(0) { $0 + pow($1 - mean, 2) } / Double(period)
                let stdDev = sqrt(variance)
                
                upper.append(mean + (2 * stdDev))
                lower.append(mean - (2 * stdDev))
            }
        }
        
        return (upper: upper, middle: sma, lower: lower)
    }
}

// MARK: - Color Extensions

extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(format: "#%02X%02X%02X",
                     Int(red * 255),
                     Int(green * 255),
                     Int(blue * 255))
    }
    
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
