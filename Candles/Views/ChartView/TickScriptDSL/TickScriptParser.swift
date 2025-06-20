//
//  TickScriptParser.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/12/25.
//

import Foundation

// MARK: - TickScript Parser
class TickScriptParser {
    private var tokens: [Token] = []
    private var current = 0

    func parse(_ script: String) throws -> [DSLStatement] {
        let lexer = TickScriptLexer()
        tokens = try lexer.tokenize(script)
        current = 0

        var statements: [DSLStatement] = []

        while !isAtEnd() {
            if let statement = try parseStatement() {
                statements.append(statement)
            }
        }

        return statements
    }

    private func parseStatement() throws -> DSLStatement? {
        // Skip empty lines and comments
        if check(.newline) || check(.comment) {
            advance()
            return nil
        }

        // Parse study declaration
        if match(.identifier) && previous().lexeme == "study" {
            return try parseStudyDeclaration()
        }

        // Parse variable/series declaration
        if check(.identifier) {
            let name = advance().lexeme

            if match(.equal) {
                let expression = try parseExpression()
                consumeNewlineOrEOF()

                // Determine if it's a series or variable based on the expression
                if isSeriesExpression(expression) {
                    return .seriesDeclaration(name, expression)
                } else {
                    return .variableDeclaration(name, expression)
                }
            } else {
                throw DSLError.syntaxError("Expected '=' after variable name")
            }
        }

        // Parse plot statement
        if match(.identifier) && previous().lexeme == "plot" {
            try consume(.leftParen, "Expected '(' after 'plot'")
            let expression = try parseExpression()
            try consume(.rightParen, "Expected ')' after plot expression")
            consumeNewlineOrEOF()
            return .plotStatement(expression)
        }

        throw DSLError.syntaxError("Unexpected token: \(peek().lexeme)")
    }

    private func parseStudyDeclaration() throws -> DSLStatement {
        try consume(.leftParen, "Expected '(' after 'study'")

        var title = ""
        var shortTitle = ""
        var overlay = false

        // Parse title
        if check(.string) {
            title = advance().lexeme
            title = String(title.dropFirst().dropLast())  // Remove quotes
        }

        // Parse optional parameters
        while match(.comma) {
            if match(.identifier) {
                let paramName = previous().lexeme
                try consume(.equal, "Expected '=' after parameter name")

                switch paramName {
                case "shorttitle":
                    if check(.string) {
                        shortTitle = advance().lexeme
                        shortTitle = String(shortTitle.dropFirst().dropLast())
                    }
                case "overlay":
                    if check(.boolean) {
                        overlay = advance().lexeme == "true"
                    }
                default:
                    // Skip unknown parameters
                    _ = try parseExpression()
                }
            }
        }

        try consume(.rightParen, "Expected ')' after study parameters")
        consumeNewlineOrEOF()

        return .studyDeclaration(title: title, shortTitle: shortTitle, overlay: overlay)
    }

    private func parseExpression() throws -> DSLExpression {
        return try parseLogicalOr()
    }

    private func parseLogicalOr() throws -> DSLExpression {
        var expr = try parseLogicalAnd()

        while match(.or) {
            let op = previous().lexeme
            let right = try parseLogicalAnd()
            expr = DSLExpression.binaryOperation(expr, op, right)
        }

        return expr
    }

    private func parseLogicalAnd() throws -> DSLExpression {
        var expr = try parseEquality()

        while match(.and) {
            let op = previous().lexeme
            let right = try parseEquality()
            expr = DSLExpression.binaryOperation(expr, op, right)
        }

        return expr
    }

    private func parseEquality() throws -> DSLExpression {
        var expr = try parseComparison()

        while match(.bangEqual, .equalEqual) {
            let op = previous().lexeme
            let right = try parseComparison()
            expr = DSLExpression.binaryOperation(expr, op, right)
        }

        return expr
    }

    private func parseComparison() throws -> DSLExpression {
        var expr = try parseTerm()

        while match(.greater, .greaterEqual, .less, .lessEqual) {
            let op = previous().lexeme
            let right = try parseTerm()
            expr = DSLExpression.binaryOperation(expr, op, right)
        }

        return expr
    }

    private func parseTerm() throws -> DSLExpression {
        var expr = try parseFactor()

        while match(.minus, .plus) {
            let op = previous().lexeme
            let right = try parseFactor()
            expr = DSLExpression.binaryOperation(expr, op, right)
        }

        return expr
    }

    private func parseFactor() throws -> DSLExpression {
        var expr = try parseUnary()

        while match(.slash, .star) {
            let op = previous().lexeme
            let right = try parseUnary()
            expr = DSLExpression.binaryOperation(expr, op, right)
        }

        return expr
    }

    private func parseUnary() throws -> DSLExpression {
        if match(.bang, .minus) {
            let op = previous().lexeme
            let right = try parseUnary()
            return DSLExpression.binaryOperation(DSLExpression.number(0), op, right)
        }

        return try parseCall()
    }

    private func parseCall() throws -> DSLExpression {
        var expr = try parsePrimary()

        while true {
            if match(.leftParen) {
                expr = try finishCall(expr)
            } else if match(.leftBracket) {
                let index = try parseExpression()
                try consume(.rightBracket, "Expected ']' after array index")
                if case .variable(let name) = expr.kind {
                    expr = DSLExpression.seriesAccess(name, index)
                } else {
                    throw DSLError.syntaxError("Invalid series access")
                }
            } else {
                break
            }
        }

        return expr
    }

    private func finishCall(_ callee: DSLExpression) throws -> DSLExpression {
        var arguments: [DSLExpression] = []

        if !check(.rightParen) {
            repeat {
                arguments.append(try parseExpression())
            } while match(.comma)
        }

        try consume(.rightParen, "Expected ')' after arguments")

        if case .variable(let name) = callee.kind {
            return DSLExpression.functionCall(name, arguments)
        } else {
            throw DSLError.syntaxError("Invalid function call")
        }
    }

    private func parsePrimary() throws -> DSLExpression {
        if match(.boolean) {
            return DSLExpression.boolean(previous().lexeme == "true")
        }

        if match(.number) {
            return DSLExpression.number(Double(previous().lexeme) ?? 0.0)
        }

        if match(.string) {
            let value = previous().lexeme
            return DSLExpression.string(String(value.dropFirst().dropLast()))  // Remove quotes
        }

        if match(.identifier) {
            return DSLExpression.variable(previous().lexeme)
        }

        if match(.leftParen) {
            let expr = try parseExpression()
            try consume(.rightParen, "Expected ')' after expression")
            return expr
        }

        throw DSLError.syntaxError("Unexpected token: \(peek().lexeme)")
    }

    private func isSeriesExpression(_ expression: DSLExpression) -> Bool {
        switch expression.kind {
        case .functionCall(let name, _):
            return [
                "close", "open", "high", "low", "volume", "hl2", "hlc3", "ohlc4",
                "sma", "ema", "rsi", "macd", "stdev", "highest", "lowest",
            ].contains(name)
        case .binaryOperation(let left, _, _):
            return isSeriesExpression(left)
        case .variable(let name):
            // Assume variables ending with certain patterns are series
            return name.hasSuffix("_series") || name.hasSuffix("_data")
        default:
            return false
        }
    }

    // MARK: - Helper Methods
    private func match(_ types: TokenType...) -> Bool {
        for type in types {
            if check(type) {
                advance()
                return true
            }
        }
        return false
    }

    private func check(_ type: TokenType) -> Bool {
        if isAtEnd() { return false }
        return peek().type == type
    }

    @discardableResult
    private func advance() -> Token {
        if !isAtEnd() { current += 1 }
        return previous()
    }

    private func isAtEnd() -> Bool {
        return peek().type == .eof
    }

    private func peek() -> Token {
        return tokens[current]
    }

    private func previous() -> Token {
        return tokens[current - 1]
    }

    private func consume(_ type: TokenType, _ message: String) throws {
        if check(type) {
            advance()
            return
        }

        throw DSLError.syntaxError(message)
    }

    private func consumeNewlineOrEOF() {
        if check(.newline) || check(.eof) {
            advance()
        }
    }
}

// MARK: - Lexer
class TickScriptLexer {
    private var source: String = ""
    private var tokens: [Token] = []
    private var start = 0
    private var current = 0
    private var line = 1

    func tokenize(_ source: String) throws -> [Token] {
        self.source = source
        tokens = []
        start = 0
        current = 0
        line = 1

        while !isAtEnd() {
            start = current
            try scanToken()
        }

        tokens.append(Token(.eof, "", line))
        return tokens
    }

    private func scanToken() throws {
        let c = advance()

        switch c {
        case " ", "\r", "\t":
            // Ignore whitespace
            break
        case "\n":
            addToken(.newline)
            line += 1
        case "(":
            addToken(.leftParen)
        case ")":
            addToken(.rightParen)
        case "[":
            addToken(.leftBracket)
        case "]":
            addToken(.rightBracket)
        case ",":
            addToken(.comma)
        case "+":
            addToken(.plus)
        case "-":
            addToken(.minus)
        case "*":
            addToken(.star)
        case "/":
            if match("/") {
                // Line comment
                while peek() != "\n" && !isAtEnd() {
                    advance()
                }
                addToken(.comment)
            } else {
                addToken(.slash)
            }
        case "!":
            addToken(match("=") ? .bangEqual : .bang)
        case "=":
            addToken(match("=") ? .equalEqual : .equal)
        case "<":
            addToken(match("=") ? .lessEqual : .less)
        case ">":
            addToken(match("=") ? .greaterEqual : .greater)
        case "&":
            if match("&") {
                addToken(.and)
            } else {
                throw DSLError.syntaxError("Unexpected character: &")
            }
        case "|":
            if match("|") {
                addToken(.or)
            } else {
                throw DSLError.syntaxError("Unexpected character: |")
            }
        case "\"":
            try string()
        default:
            if c.isNumber {
                try number()
            } else if c.isLetter || c == "_" {
                identifier()
            } else {
                throw DSLError.syntaxError("Unexpected character: \(c)")
            }
        }
    }

    private func string() throws {
        while peek() != "\"" && !isAtEnd() {
            if peek() == "\n" { line += 1 }
            advance()
        }

        if isAtEnd() {
            throw DSLError.syntaxError("Unterminated string")
        }

        // Consume closing "
        advance()

        addToken(.string)
    }

    private func number() throws {
        while peek().isNumber {
            advance()
        }

        // Look for decimal part
        if peek() == "." && peekNext().isNumber {
            advance()  // Consume "."

            while peek().isNumber {
                advance()
            }
        }

        addToken(.number)
    }

    private func identifier() {
        while peek().isAlphanumeric || peek() == "_" {
            advance()
        }

        let text = String(
            source[
                source.index(
                    source.startIndex, offsetBy: start)..<source.index(
                        source.startIndex, offsetBy: current)])

        let type: TokenType
        switch text {
        case "true", "false":
            type = .boolean
        case "and":
            type = .and
        case "or":
            type = .or
        default:
            type = .identifier
        }

        addToken(type)
    }

    // MARK: - Helper Methods
    private func isAtEnd() -> Bool {
        return current >= source.count
    }

    @discardableResult
    private func advance() -> Character {
        let index = source.index(source.startIndex, offsetBy: current)
        current += 1
        return source[index]
    }

    private func match(_ expected: Character) -> Bool {
        if isAtEnd() { return false }
        let index = source.index(source.startIndex, offsetBy: current)
        if source[index] != expected { return false }

        current += 1
        return true
    }

    private func peek() -> Character {
        if isAtEnd() { return "\0" }
        let index = source.index(source.startIndex, offsetBy: current)
        return source[index]
    }

    private func peekNext() -> Character {
        if current + 1 >= source.count { return "\0" }
        let index = source.index(source.startIndex, offsetBy: current + 1)
        return source[index]
    }

    private func addToken(_ type: TokenType) {
        let text = String(
            source[
                source.index(
                    source.startIndex, offsetBy: start)..<source.index(
                        source.startIndex, offsetBy: current)])
        tokens.append(Token(type, text, line))
    }
}

// MARK: - Token
struct Token {
    let type: TokenType
    let lexeme: String
    let line: Int

    init(_ type: TokenType, _ lexeme: String, _ line: Int) {
        self.type = type
        self.lexeme = lexeme
        self.line = line
    }
}

enum TokenType {
    // Single-character tokens
    case leftParen, rightParen, leftBracket, rightBracket
    case comma, minus, plus, slash, star

    // One or two character tokens
    case bang, bangEqual
    case equal, equalEqual
    case greater, greaterEqual
    case less, lessEqual

    // Literals
    case identifier, string, number, boolean

    // Keywords
    case and, or

    // Special
    case newline, comment, eof
}

// MARK: - Character Extensions
extension Character {
    var isNumber: Bool {
        return self >= "0" && self <= "9"
    }

    var isLetter: Bool {
        return (self >= "a" && self <= "z") || (self >= "A" && self <= "Z")
    }

    var isAlphanumeric: Bool {
        return isLetter || isNumber
    }
}
