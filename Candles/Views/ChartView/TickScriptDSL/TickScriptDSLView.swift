//
//  TickScriptDSLView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/12/25.
//

import SwiftUI
import WidgetKit

struct TickScriptDSLView: View {
    @Binding var isVisible: Bool
    @ObservedObject var indicatorManager: IndicatorManager
    @State private var selectedTab = 0
    @State private var scriptText = ""
    @State private var scriptName = ""
    @State private var validationResult: (isValid: Bool, error: String?) = (true, nil)
    @State private var testResults: [Double] = []
    @State private var showingSaveAlert = false
    @State private var savedScripts: [SavedTickScript] = []
    
    private let tickScriptEngine = TickScriptEngine()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TickScript DSL")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Close") {
                    isVisible = false
                }
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Tab Selector
            Picker("Tab", selection: $selectedTab) {
                Text("Editor").tag(0)
                Text("Library").tag(1)
                Text("Documentation").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Content
            TabView(selection: $selectedTab) {
                // Editor Tab
                editorView
                    .tag(0)
                
                // Library Tab
                libraryView
                    .tag(1)
                
                // Documentation Tab
                documentationView
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .background(Color(.systemBackground))
        .onAppear {
            loadSavedScripts()
            loadDefaultScript()
        }
    }
    
    // MARK: - Editor View
    private var editorView: some View {
        VStack(spacing: 12) {
            // Script Name Input
            HStack {
                Text("Script Name:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter script name", text: $scriptName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Script Editor
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TickScript Code:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    // Validation Status
                    HStack(spacing: 4) {
                        Image(systemName: validationResult.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(validationResult.isValid ? .green : .red)
                        Text(validationResult.isValid ? "Valid" : "Error")
                            .font(.caption)
                            .foregroundColor(validationResult.isValid ? .green : .red)
                    }
                }
                
                TextEditor(text: $scriptText)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .frame(minHeight: 200)
                    .onChange(of: scriptText) { _ in
                        validateScript()
                    }
                
                // Error Message
                if !validationResult.isValid, let error = validationResult.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Test Script") {
                    testScript()
                }
                .buttonStyle(.bordered)
                .disabled(!validationResult.isValid)
                
                Button("Save Script") {
                    saveScript()
                }
                .buttonStyle(.borderedProminent)
                .disabled(scriptName.isEmpty || !validationResult.isValid)
                
                Button("Apply to Chart") {
                    applyToChart()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!validationResult.isValid)
            }
            .padding(.horizontal)
            
            // Test Results
            if !testResults.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Results:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(testResults.prefix(10).enumerated()), id: \.offset) { index, value in
                                VStack {
                                    Text("\(index)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.2f", value))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color(.systemGray5))
                                .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
    
    // MARK: - Library View
    private var libraryView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Saved Scripts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh") {
                    loadSavedScripts()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            if savedScripts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Saved Scripts")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Create and save scripts in the Editor tab")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(savedScripts) { script in
                        SavedScriptRow(script: script) {
                            loadScript(script)
                        } onDelete: {
                            deleteScript(script)
                        } onApply: {
                            applyScript(script)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
    
    // MARK: - Documentation View
    private var documentationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Introduction
                DocumentationSection(title: "PineScript DSL") {
                    Text("A simplified domain-specific language inspired by TradingView's Pine Script for creating custom technical indicators.")
                }
                
                // Basic Syntax
                DocumentationSection(title: "Basic Syntax") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("**Study Declaration:**")
                            .fontWeight(.semibold)
                        CodeBlock("study(\"My Indicator\", shorttitle=\"MI\", overlay=true)")
                        
                        Text("**Variable Assignment:**")
                            .fontWeight(.semibold)
                        CodeBlock("length = input(\"Length\", 14)\nma_value = sma(close(), length)")
                        
                        Text("**Plot Statement:**")
                            .fontWeight(.semibold)
                        CodeBlock("plot(ma_value)")
                    }
                }
                
                // Built-in Functions
                DocumentationSection(title: "Built-in Functions") {
                    VStack(alignment: .leading, spacing: 12) {
                        FunctionDoc(name: "close()", description: "Returns the closing price series")
                        FunctionDoc(name: "open()", description: "Returns the opening price series")
                        FunctionDoc(name: "high()", description: "Returns the high price series")
                        FunctionDoc(name: "low()", description: "Returns the low price series")
                        FunctionDoc(name: "volume()", description: "Returns the volume series")
                        FunctionDoc(name: "hl2()", description: "Returns (high + low) / 2")
                        FunctionDoc(name: "hlc3()", description: "Returns (high + low + close) / 3")
                        FunctionDoc(name: "ohlc4()", description: "Returns (open + high + low + close) / 4")
                    }
                }
                
                // Technical Indicators
                DocumentationSection(title: "Technical Indicators") {
                    VStack(alignment: .leading, spacing: 12) {
                        FunctionDoc(name: "sma(source, length)", description: "Simple Moving Average")
                        FunctionDoc(name: "ema(source, length)", description: "Exponential Moving Average")
                        FunctionDoc(name: "rsi(source, length)", description: "Relative Strength Index")
                        FunctionDoc(name: "macd(source, fast, slow)", description: "MACD Line")
                        FunctionDoc(name: "stdev(source, length)", description: "Standard Deviation")
                        FunctionDoc(name: "highest(source, length)", description: "Highest value in period")
                        FunctionDoc(name: "lowest(source, length)", description: "Lowest value in period")
                    }
                }
                
                // Examples
                DocumentationSection(title: "Examples") {
                    VStack(alignment: .leading, spacing: 16) {
                        ExampleScript(
                            title: "Simple Moving Average",
                            code: """
                            study("SMA", shorttitle="SMA", overlay=true)
                            length = input("Length", 20)
                            sma_line = sma(close(), length)
                            plot(sma_line)
                            """
                        )
                        
                        ExampleScript(
                            title: "RSI Oscillator",
                            code: """
                            study("RSI", shorttitle="RSI", overlay=false)
                            length = input("Length", 14)
                            rsi_value = rsi(close(), length)
                            plot(rsi_value)
                            """
                        )
                        
                        ExampleScript(
                            title: "Bollinger Bands",
                            code: """
                            study("Bollinger Bands", shorttitle="BB", overlay=true)
                            length = input("Length", 20)
                            mult = input("Multiplier", 2.0)
                            basis = sma(close(), length)
                            dev = stdev(close(), length)
                            upper = basis + dev * mult
                            lower = basis - dev * mult
                            plot(upper)
                            plot(basis)
                            plot(lower)
                            """
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper Methods
    private func loadDefaultScript() {
        scriptText = """
        study("Simple Moving Average", shorttitle="SMA", overlay=true)
        length = input("Length", 20)
        sma_line = sma(close(), length)
        plot(sma_line)
        """
        scriptName = "Simple SMA"
        validateScript()
    }
    
    private func validateScript() {
        validationResult = tickScriptEngine.validateScript(scriptText)
    }
    
    private func testScript() {
        let dummyData = getDummyData(for: .oneHour)
        testResults = tickScriptEngine.executeScript(scriptText, data: dummyData, parameters: ["Length": 20])
    }
    
    private func saveScript() {
        let script = SavedTickScript(
            id: UUID(),
            name: scriptName,
            code: scriptText,
            dateCreated: Date()
        )
        
        savedScripts.append(script)
        saveTickScriptsToUserDefaults()
        showingSaveAlert = true
    }
    
    private func applyToChart() {
        let dummyData = getDummyData(for: .oneHour)
        let results = tickScriptEngine.executeScript(scriptText, data: dummyData, parameters: [:])
        
        let indicator = ChartIndicator(
            name: scriptName.isEmpty ? "Custom Indicator" : scriptName,
            values: results,
            color: .blue,
            lineWidth: 2.0,
            script: scriptText,
            parameters: [:]
        )
        
        indicatorManager.addIndicator(indicator)
        isVisible = false
    }
    
    private func loadScript(_ script: SavedTickScript) {
        scriptText = script.code
        scriptName = script.name
        selectedTab = 0
        validateScript()
    }
    
    private func deleteScript(_ script: SavedTickScript) {
        savedScripts.removeAll { $0.id == script.id }
        saveTickScriptsToUserDefaults()
    }
    
    private func applyScript(_ script: SavedTickScript) {
        loadScript(script)
        applyToChart()
    }
    
    private func loadSavedScripts() {
        savedScripts = loadTickScriptsFromUserDefaults()
    }
    
    private func saveTickScriptsToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(savedScripts) {
            UserDefaults.standard.set(encoded, forKey: "SavedTickScripts")
        }
    }
    
    private func loadTickScriptsFromUserDefaults() -> [SavedTickScript] {
        guard let data = UserDefaults.standard.data(forKey: "SavedTickScripts"),
              let scripts = try? JSONDecoder().decode([SavedTickScript].self, from: data) else {
            return []
        }
        return scripts
    }
}

// MARK: - Supporting Views
struct SavedScriptRow: View {
    let script: SavedTickScript
    let onLoad: () -> Void
    let onDelete: () -> Void
    let onApply: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(script.name)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("Created: \(script.dateCreated, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Load") {
                        onLoad()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    
                    Button("Apply") {
                        onApply()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption)
                    
                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            
            Text(script.code.prefix(100) + (script.code.count > 100 ? "..." : ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct DocumentationSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            content
        }
    }
}

struct CodeBlock: View {
    let code: String
    
    init(_ code: String) {
        self.code = code
    }
    
    var body: some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FunctionDoc: View {
    let name: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ExampleScript: View {
    let title: String
    let code: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Data Models
struct SavedTickScript: Identifiable, Codable {
    let id: UUID
    let name: String
    let code: String
    let dateCreated: Date
}
