//
//  TickScriptEngine.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/12/25.
//

import Foundation
import SwiftUI


// MARK: - DSL Context
struct DSLContext {
    var data: [OHLCDataPoint] = []
    var parameters: [String: Any] = [:]
    var variables: [String: Any] = [:]
    var series: [String: [Double]] = [:]
    var studyTitle: String = ""
    var studyShortTitle: String = ""
    var isOverlay: Bool = false
}

// MARK: - DSL AST
enum DSLStatement {
    case variableDeclaration(String, DSLExpression)
    case seriesDeclaration(String, DSLExpression)
    case plotStatement(DSLExpression)
    case studyDeclaration(title: String, shortTitle: String, overlay: Bool)
}

class DSLExpression {
    enum Kind {
        case number(Double)
        case string(String)
        case boolean(Bool)
        case variable(String)
        case functionCall(String, [DSLExpression])
        case binaryOperation(DSLExpression, String, DSLExpression)
        case seriesAccess(String, DSLExpression)
    }
    
    let kind: Kind
    
    init(_ kind: Kind) {
        self.kind = kind
    }
    
    static func number(_ value: Double) -> DSLExpression {
        return DSLExpression(.number(value))
    }
    
    static func string(_ value: String) -> DSLExpression {
        return DSLExpression(.string(value))
    }
    
    static func boolean(_ value: Bool) -> DSLExpression {
        return DSLExpression(.boolean(value))
    }
    
    static func variable(_ name: String) -> DSLExpression {
        return DSLExpression(.variable(name))
    }
    
    static func functionCall(_ name: String, _ args: [DSLExpression]) -> DSLExpression {
        return DSLExpression(.functionCall(name, args))
    }
    
    static func binaryOperation(_ left: DSLExpression, _ op: String, _ right: DSLExpression) -> DSLExpression {
        return DSLExpression(.binaryOperation(left, op, right))
    }
    
    static func seriesAccess(_ name: String, _ index: DSLExpression) -> DSLExpression {
        return DSLExpression(.seriesAccess(name, index))
    }
}

// MARK: - DSL Errors
enum DSLError: Error {
    case syntaxError(String)
    case undefinedVariable(String)
    case undefinedFunction(String)
    case undefinedSeries(String)
    case invalidArguments
    case invalidOperands
    case divisionByZero
    case unknownOperator(String)
    case indexOutOfBounds
    
    var localizedDescription: String {
        switch self {
        case .syntaxError(let msg): return "Syntax error: \(msg)"
        case .undefinedVariable(let name): return "Undefined variable: \(name)"
        case .undefinedFunction(let name): return "Undefined function: \(name)"
        case .undefinedSeries(let name): return "Undefined series: \(name)"
        case .invalidArguments: return "Invalid function arguments"
        case .invalidOperands: return "Invalid operands for operation"
        case .divisionByZero: return "Division by zero"
        case .unknownOperator(let op): return "Unknown operator: \(op)"
        case .indexOutOfBounds: return "Index out of bounds"
        }
    }
}

// MARK: - TickScript DSL Engine
class TickScriptEngine {
    private var context: DSLContext = DSLContext()
    
    func executeScript(_ script: String, data: [OHLCDataPoint], parameters: [String: Any] = [:]) -> [Double] {
        context = DSLContext()
        context.data = data
        context.parameters = parameters
        
        do {
            let parser = TickScriptParser()
            let statements = try parser.parse(script)
            return try executeStatements(statements)
        } catch {
            print("TickScript execution error: \(error)")
            return []
        }
    }
    
    func validateScript(_ script: String) -> (isValid: Bool, error: String?) {
        do {
            let parser = TickScriptParser()
            _ = try parser.parse(script)
            return (true, nil)
        } catch let error as DSLError {
            return (false, error.localizedDescription)
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    private func executeStatements(_ statements: [DSLStatement]) throws -> [Double] {
        var results: [Double] = []
        
        for statement in statements {
            switch statement {
            case .variableDeclaration(let name, let expression):
                let value = try evaluateExpression(expression)
                context.variables[name] = value
                
            case .seriesDeclaration(let name, let expression):
                let series = try evaluateSeriesExpression(expression)
                context.series[name] = series
                
            case .plotStatement(let expression):
                let plotSeries = try evaluateSeriesExpression(expression)
                results = plotSeries
                
            case .studyDeclaration(let title, let shortTitle, let overlay):
                context.studyTitle = title
                context.studyShortTitle = shortTitle
                context.isOverlay = overlay
            }
        }
        
        return results
    }
    
    private func evaluateExpression(_ expression: DSLExpression) throws -> Any {
        switch expression.kind {
        case .number(let value):
            return value
            
        case .string(let value):
            return value
            
        case .boolean(let value):
            return value
            
        case .variable(let name):
            if let value = context.variables[name] {
                return value
            } else if let param = context.parameters[name] {
                return param
            } else {
                throw DSLError.undefinedVariable(name)
            }
            
        case .functionCall(let name, let args):
            return try evaluateFunctionCall(name, args)
            
        case .binaryOperation(let left, let op, let right):
            return try evaluateBinaryOperation(left, op, right)
            
        case .seriesAccess(let seriesName, let indexExpr):
            guard let series = context.series[seriesName] else {
                throw DSLError.undefinedSeries(seriesName)
            }
            
            let indexValue = try evaluateExpression(indexExpr)
            guard let index = indexValue as? Double else {
                throw DSLError.invalidOperands
            }
            
            let intIndex = Int(index)
            guard intIndex >= 0 && intIndex < series.count else {
                throw DSLError.indexOutOfBounds
            }
            
            return series[intIndex]
        }
    }
    
    private func evaluateSeriesExpression(_ expression: DSLExpression) throws -> [Double] {
        switch expression.kind {
        case .variable(let name):
            if let series = context.series[name] {
                return series
            } else {
                throw DSLError.undefinedSeries(name)
            }
            
        case .functionCall(let name, let args):
            return try evaluateSeriesFunctionCall(name, args)
            
        case .binaryOperation(let left, let op, let right):
            let leftSeries = try evaluateSeriesExpression(left)
            let rightSeries = try evaluateSeriesExpression(right)
            
            guard leftSeries.count == rightSeries.count else {
                throw DSLError.invalidOperands
            }
            
            return try zip(leftSeries, rightSeries).map { l, r in
                switch op {
                case "+": return l + r
                case "-": return l - r
                case "*": return l * r
                case "/":
                    guard r != 0 else { throw DSLError.divisionByZero }
                    return l / r
                default: throw DSLError.unknownOperator(op)
                }
            }
            
        default:
            throw DSLError.invalidOperands
        }
    }
    
    private func evaluateFunctionCall(_ name: String, _ args: [DSLExpression]) throws -> Any {
        switch name {
        case "abs":
            guard args.count == 1 else { throw DSLError.invalidArguments }
            let value = try evaluateExpression(args[0])
            guard let num = value as? Double else { throw DSLError.invalidOperands }
            return abs(num)
            
        case "max":
            guard args.count == 2 else { throw DSLError.invalidArguments }
            let val1 = try evaluateExpression(args[0])
            let val2 = try evaluateExpression(args[1])
            guard let num1 = val1 as? Double, let num2 = val2 as? Double else {
                throw DSLError.invalidOperands
            }
            return max(num1, num2)
            
        case "min":
            guard args.count == 2 else { throw DSLError.invalidArguments }
            let val1 = try evaluateExpression(args[0])
            let val2 = try evaluateExpression(args[1])
            guard let num1 = val1 as? Double, let num2 = val2 as? Double else {
                throw DSLError.invalidOperands
            }
            return min(num1, num2)
            
        default:
            throw DSLError.undefinedFunction(name)
        }
    }
    
    private func evaluateSeriesFunctionCall(_ name: String, _ args: [DSLExpression]) throws -> [Double] {
        switch name {
        case "close":
            return context.data.map { $0.close }
            
        case "open":
            return context.data.map { $0.open }
            
        case "high":
            return context.data.map { $0.high }
            
        case "low":
            return context.data.map { $0.low }
            
        case "volume":
            return context.data.map { $0.volume }
            
        case "sma":
            guard args.count == 2 else { throw DSLError.invalidArguments }
            let series = try evaluateSeriesExpression(args[0])
            let lengthValue = try evaluateExpression(args[1])
            guard let length = lengthValue as? Double else { throw DSLError.invalidOperands }
            return calculateSMA(series, period: Int(length))
            
        case "ema":
            guard args.count == 2 else { throw DSLError.invalidArguments }
            let series = try evaluateSeriesExpression(args[0])
            let lengthValue = try evaluateExpression(args[1])
            guard let length = lengthValue as? Double else { throw DSLError.invalidOperands }
            return calculateEMA(series, period: Int(length))
            
        case "rsi":
            guard args.count == 2 else { throw DSLError.invalidArguments }
            let series = try evaluateSeriesExpression(args[0])
            let lengthValue = try evaluateExpression(args[1])
            guard let length = lengthValue as? Double else { throw DSLError.invalidOperands }
            return calculateRSI(series, period: Int(length))
            
        case "bb_upper", "bb_lower", "bb_middle":
            guard args.count == 3 else { throw DSLError.invalidArguments }
            let series = try evaluateSeriesExpression(args[0])
            let lengthValue = try evaluateExpression(args[1])
            let stdDevValue = try evaluateExpression(args[2])
            guard let length = lengthValue as? Double, let stdDev = stdDevValue as? Double else {
                throw DSLError.invalidOperands
            }
            let bb = calculateBollingerBands(series, period: Int(length), stdDev: stdDev)
            switch name {
            case "bb_upper": return bb.upper
            case "bb_lower": return bb.lower
            case "bb_middle": return bb.middle
            default: throw DSLError.undefinedFunction(name)
            }
            
        case "macd_line", "macd_signal", "macd_histogram":
            guard args.count == 3 else { throw DSLError.invalidArguments }
            let series = try evaluateSeriesExpression(args[0])
            let fastValue = try evaluateExpression(args[1])
            let slowValue = try evaluateExpression(args[2])
            guard let fast = fastValue as? Double, let slow = slowValue as? Double else {
                throw DSLError.invalidOperands
            }
            let macd = calculateMACD(series, fastPeriod: Int(fast), slowPeriod: Int(slow))
            switch name {
            case "macd_line": return macd.line
            case "macd_signal": return macd.signal
            case "macd_histogram": return macd.histogram
            default: throw DSLError.undefinedFunction(name)
            }
            
        default:
            throw DSLError.undefinedFunction(name)
        }
    }
    
    private func evaluateBinaryOperation(_ left: DSLExpression, _ op: String, _ right: DSLExpression) throws -> Any {
        let leftValue = try evaluateExpression(left)
        let rightValue = try evaluateExpression(right)
        
        guard let leftNum = leftValue as? Double, let rightNum = rightValue as? Double else {
            throw DSLError.invalidOperands
        }
        
        switch op {
        case "+": return leftNum + rightNum
        case "-": return leftNum - rightNum
        case "*": return leftNum * rightNum
        case "/":
            guard rightNum != 0 else { throw DSLError.divisionByZero }
            return leftNum / rightNum
        case ">": return leftNum > rightNum
        case "<": return leftNum < rightNum
        case ">=": return leftNum >= rightNum
        case "<=": return leftNum <= rightNum
        case "==": return leftNum == rightNum
        case "!=": return leftNum != rightNum
        case "and": return (leftNum != 0) && (rightNum != 0)
        case "or": return (leftNum != 0) || (rightNum != 0)
        default: throw DSLError.unknownOperator(op)
        }
    }
    
    // MARK: - Technical Analysis Functions
    
    private func calculateSMA(_ data: [Double], period: Int) -> [Double] {
        guard period > 0 && period <= data.count else { return [] }
        
        var result: [Double] = []
        
        for i in 0..<data.count {
            if i < period - 1 {
                result.append(0) // or NaN
            } else {
                let sum = data[(i - period + 1)...i].reduce(0, +)
                result.append(sum / Double(period))
            }
        }
        
        return result
    }
    
    private func calculateEMA(_ data: [Double], period: Int) -> [Double] {
        guard period > 0 && !data.isEmpty else { return [] }
        
        let multiplier = 2.0 / Double(period + 1)
        var result: [Double] = []
        
        // First value is just the first data point
        result.append(data[0])
        
        for i in 1..<data.count {
            let ema = (data[i] * multiplier) + (result[i-1] * (1 - multiplier))
            result.append(ema)
        }
        
        return result
    }
    
    private func calculateRSI(_ data: [Double], period: Int) -> [Double] {
        guard period > 0 && data.count > period else { return [] }
        
        var gains: [Double] = []
        var losses: [Double] = []
        
        // Calculate price changes
        for i in 1..<data.count {
            let change = data[i] - data[i-1]
            gains.append(max(change, 0))
            losses.append(max(-change, 0))
        }
        
        var result: [Double] = Array(repeating: 0, count: period)
        
        // Calculate initial average gain and loss
        let initialAvgGain = gains[0..<period].reduce(0, +) / Double(period)
        let initialAvgLoss = losses[0..<period].reduce(0, +) / Double(period)
        
        var avgGain = initialAvgGain
        var avgLoss = initialAvgLoss
        
        for i in period..<gains.count {
            avgGain = ((avgGain * Double(period - 1)) + gains[i]) / Double(period)
            avgLoss = ((avgLoss * Double(period - 1)) + losses[i]) / Double(period)
            
            let rs = avgLoss == 0 ? 100 : avgGain / avgLoss
            let rsi = 100 - (100 / (1 + rs))
            result.append(rsi)
        }
        
        return result
    }
    
    private func calculateBollingerBands(_ data: [Double], period: Int, stdDev: Double) -> (upper: [Double], middle: [Double], lower: [Double]) {
        let sma = calculateSMA(data, period: period)
        var upper: [Double] = []
        var lower: [Double] = []
        
        for i in 0..<data.count {
            if i < period - 1 {
                upper.append(0)
                lower.append(0)
            } else {
                let slice = Array(data[(i - period + 1)...i])
                let mean = sma[i]
                let variance = slice.map { pow($0 - mean, 2) }.reduce(0, +) / Double(period)
                let standardDeviation = sqrt(variance)
                
                upper.append(mean + (standardDeviation * stdDev))
                lower.append(mean - (standardDeviation * stdDev))
            }
        }
        
        return (upper: upper, middle: sma, lower: lower)
    }
    
    private func calculateMACD(_ data: [Double], fastPeriod: Int, slowPeriod: Int) -> (line: [Double], signal: [Double], histogram: [Double]) {
        let fastEMA = calculateEMA(data, period: fastPeriod)
        let slowEMA = calculateEMA(data, period: slowPeriod)
        
        var macdLine: [Double] = []
        for i in 0..<min(fastEMA.count, slowEMA.count) {
            macdLine.append(fastEMA[i] - slowEMA[i])
        }
        
        let signalLine = calculateEMA(macdLine, period: 9)
        
        var histogram: [Double] = []
        for i in 0..<min(macdLine.count, signalLine.count) {
            histogram.append(macdLine[i] - signalLine[i])
        }
        
        return (line: macdLine, signal: signalLine, histogram: histogram)
    }
}
