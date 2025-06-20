//
//  IndicatorPanelView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/12/25.
//

import SwiftUI

struct IndicatorPanelView: View {
    @ObservedObject var indicatorManager: IndicatorManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: IndicatorTab = .active
    @State private var showingBuiltInIndicators = false
    @State private var selectedBuiltInType: BuiltInIndicatorType?
    @State private var builtInParameters: [String: Any] = [:]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                IndicatorTabSelector(selectedTab: $selectedTab)
                
                // Content based on selected tab
                switch selectedTab {
                case .active:
                    ActiveIndicatorsView(
                        indicatorManager: indicatorManager,
                        onAddBuiltIn: { showingBuiltInIndicators = true }
                    )
                    
                case .builtin:
                    BuiltInIndicatorsView(
                        indicatorManager: indicatorManager,
                        selectedType: $selectedBuiltInType,
                        parameters: $builtInParameters,
                        onAdd: addBuiltInIndicator
                    )
                    
                case .saved:
                    SavedIndicatorsView(indicatorManager: indicatorManager)
                }
            }
            .navigationTitle("Indicators")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingBuiltInIndicators) {
            BuiltInIndicatorConfigView(
                selectedType: $selectedBuiltInType,
                parameters: $builtInParameters,
                onAdd: { type, params in
                    addBuiltInIndicator(type: type, parameters: params)
                    showingBuiltInIndicators = false
                }
            )
        }
    }
    
    private func addBuiltInIndicator(type: BuiltInIndicatorType, parameters: [String: Any]) {
        let indicator = ChartIndicator(
            name: "\(type.rawValue)(\(parameters["period"] ?? 14))",
            color: getDefaultColor(for: type),
            parameters: parameters.merging(["type": type.rawValue]) { _, new in new }
        )
        
        indicatorManager.addIndicator(indicator)
    }
    
    private func getDefaultColor(for type: BuiltInIndicatorType) -> Color {
        switch type {
        case .sma: return .blue
        case .ema: return .orange
        case .rsi: return .purple
        case .macd: return .green
        case .bollinger: return .red
        }
    }
}

enum IndicatorTab: String, CaseIterable {
    case active = "Active"
    case builtin = "Built-in"
    case saved = "Saved"
    
    var icon: String {
        switch self {
        case .active: return "chart.line.uptrend.xyaxis"
        case .builtin: return "function"
        case .saved: return "bookmark"
        }
    }
}

struct IndicatorTabSelector: View {
    @Binding var selectedTab: IndicatorTab
    
    var body: some View {
        HStack {
            ForEach(IndicatorTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == tab ? Color.blue : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

struct ActiveIndicatorsView: View {
    @ObservedObject var indicatorManager: IndicatorManager
    let onAddBuiltIn: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Add Button
            HStack {
                Text("Active Indicators")
                    .font(.headline)
                
                Spacer()
                
                Button(action: onAddBuiltIn) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Indicators List
            if indicatorManager.activeIndicators.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Active Indicators")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add indicators to analyze your charts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(indicatorManager.activeIndicators, id: \.id) { indicator in
                        ActiveIndicatorRow(
                            indicator: indicator,
                            onToggleVisibility: {
                                indicatorManager.toggleIndicatorVisibility(indicator)
                            },
                            onRemove: {
                                indicatorManager.removeIndicator(indicator)
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
            
            // Calculation Status
            if indicatorManager.isCalculating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Calculating indicators...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
            }
        }
    }
}

struct ActiveIndicatorRow: View {
    let indicator: ChartIndicator
    let onToggleVisibility: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            // Visibility Toggle
            Button(action: onToggleVisibility) {
                Image(systemName: indicator.isVisible ? "eye" : "eye.slash")
                    .foregroundColor(indicator.isVisible ? .blue : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Indicator Info
            VStack(alignment: .leading, spacing: 4) {
                Text(indicator.name)
                    .font(.headline)
                    .foregroundColor(indicator.isVisible ? .primary : .secondary)
                
                HStack {
                    Circle()
                        .fill(indicator.color)
                        .frame(width: 12, height: 12)
                    
                    Text("Line width: \(String(format: "%.1f", indicator.lineWidth))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if indicator.script != nil {
                        Text("• Custom")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .opacity(indicator.isVisible ? 1.0 : 0.6)
    }
}

struct BuiltInIndicatorsView: View {
    @ObservedObject var indicatorManager: IndicatorManager
    @Binding var selectedType: BuiltInIndicatorType?
    @Binding var parameters: [String: Any]
    let onAdd: (BuiltInIndicatorType, [String: Any]) -> Void
    
    var body: some View {
        List {
            ForEach(BuiltInIndicatorType.allCases, id: \.self) { type in
                BuiltInIndicatorRow(
                    type: type,
                    onAdd: {
                        let defaultParams = getDefaultParameters(for: type)
                        onAdd(type, defaultParams)
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func getDefaultParameters(for type: BuiltInIndicatorType) -> [String: Any] {
        switch type {
        case .sma, .ema:
            return ["period": 20]
        case .rsi:
            return ["period": 14]
        case .macd:
            return ["fast": 12, "slow": 26, "signal": 9]
        case .bollinger:
            return ["period": 20, "deviation": 2.0]
        }
    }
}

struct BuiltInIndicatorRow: View {
    let type: BuiltInIndicatorType
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(type.rawValue)
                    .font(.headline)
                
                Text(type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(getDescription(for: type))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button("Add", action: onAdd)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
    
    private func getDescription(for type: BuiltInIndicatorType) -> String {
        switch type {
        case .sma:
            return "Average price over a specified period"
        case .ema:
            return "Exponentially weighted moving average"
        case .rsi:
            return "Momentum oscillator (0-100 range)"
        case .macd:
            return "Trend-following momentum indicator"
        case .bollinger:
            return "Volatility bands around moving average"
        }
    }
}

struct SavedIndicatorsView: View {
    @ObservedObject var indicatorManager: IndicatorManager
    
    var body: some View {
        VStack(spacing: 0) {
            if indicatorManager.savedIndicators.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Saved Indicators")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Create custom indicators in the Scripting view")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(indicatorManager.savedIndicators, id: \.id) { savedIndicator in
                        SavedIndicatorRowInPanel(
                            indicator: savedIndicator,
                            onLoad: {
                                indicatorManager.loadSavedIndicator(savedIndicator)
                            },
                            onDelete: {
                                indicatorManager.deleteSavedIndicator(savedIndicator)
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

struct SavedIndicatorRowInPanel: View {
    let indicator: SavedIndicator
    let onLoad: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(indicator.name)
                    .font(.headline)
                
                Text("Created: \(indicator.dateCreated, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Circle()
                        .fill(Color(hex: indicator.colorHex) ?? .blue)
                        .frame(width: 12, height: 12)
                    
                    Text("Custom Script")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Button("Load", action: onLoad)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                
                Button("Delete", action: onDelete)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct BuiltInIndicatorConfigView: View {
    @Binding var selectedType: BuiltInIndicatorType?
    @Binding var parameters: [String: Any]
    let onAdd: (BuiltInIndicatorType, [String: Any]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var period: Double = 20
    @State private var fastPeriod: Double = 12
    @State private var slowPeriod: Double = 26
    @State private var signalPeriod: Double = 9
    @State private var deviation: Double = 2.0
    @State private var selectedColor = Color.blue
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let type = selectedType {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(type.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(getDetailedDescription(for: type))
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        // Parameters based on indicator type
                        switch type {
                        case .sma, .ema:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Period: \(Int(period))")
                                    .font(.headline)
                                
                                Slider(value: $period, in: 5...200, step: 1)
                                
                                Text("Number of periods to calculate the average")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                        case .rsi:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Period: \(Int(period))")
                                    .font(.headline)
                                
                                Slider(value: $period, in: 5...50, step: 1)
                                
                                Text("Period for RSI calculation (typically 14)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                        case .macd:
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fast Period: \(Int(fastPeriod))")
                                        .font(.headline)
                                    Slider(value: $fastPeriod, in: 5...50, step: 1)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Slow Period: \(Int(slowPeriod))")
                                        .font(.headline)
                                    Slider(value: $slowPeriod, in: 10...100, step: 1)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Signal Period: \(Int(signalPeriod))")
                                        .font(.headline)
                                    Slider(value: $signalPeriod, in: 5...20, step: 1)
                                }
                            }
                            
                        case .bollinger:
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Period: \(Int(period))")
                                        .font(.headline)
                                    Slider(value: $period, in: 5...50, step: 1)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Standard Deviation: \(String(format: "%.1f", deviation))")
                                        .font(.headline)
                                    Slider(value: $deviation, in: 1.0...3.0, step: 0.1)
                                }
                            }
                        }
                        
                        // Color Picker
                        HStack {
                            Text("Color:")
                                .font(.headline)
                            
                            ColorPicker("Select Color", selection: $selectedColor)
                                .labelsHidden()
                                .frame(width: 50, height: 30)
                            
                            Spacer()
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Add Button
                    Button("Add Indicator") {
                        let params = buildParameters(for: type)
                        onAdd(type, params)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .navigationTitle("Configure Indicator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let type = selectedType {
                setupDefaultValues(for: type)
            }
        }
    }
    
    private func setupDefaultValues(for type: BuiltInIndicatorType) {
        switch type {
        case .sma, .ema, .bollinger:
            period = 20
        case .rsi:
            period = 14
        case .macd:
            fastPeriod = 12
            slowPeriod = 26
            signalPeriod = 9
        }
        
        selectedColor = getDefaultColor(for: type)
    }
    
    private func buildParameters(for type: BuiltInIndicatorType) -> [String: Any] {
        switch type {
        case .sma, .ema, .rsi:
            return ["period": Int(period), "color": selectedColor.toHex()]
        case .macd:
            return [
                "fast": Int(fastPeriod),
                "slow": Int(slowPeriod),
                "signal": Int(signalPeriod),
                "color": selectedColor.toHex()
            ]
        case .bollinger:
            return [
                "period": Int(period),
                "deviation": deviation,
                "color": selectedColor.toHex()
            ]
        }
    }
    
    private func getDefaultColor(for type: BuiltInIndicatorType) -> Color {
        switch type {
        case .sma: return .blue
        case .ema: return .orange
        case .rsi: return .purple
        case .macd: return .green
        case .bollinger: return .red
        }
    }
    
    private func getDetailedDescription(for type: BuiltInIndicatorType) -> String {
        switch type {
        case .sma:
            return "A Simple Moving Average (SMA) calculates the average price over a specified number of periods. It's useful for identifying trends and smoothing out price fluctuations."
        case .ema:
            return "An Exponential Moving Average (EMA) gives more weight to recent prices, making it more responsive to new information than a simple moving average."
        case .rsi:
            return "The Relative Strength Index (RSI) is a momentum oscillator that measures the speed and magnitude of price changes. Values above 70 typically indicate overbought conditions, while values below 30 indicate oversold conditions."
        case .macd:
            return "The Moving Average Convergence Divergence (MACD) is a trend-following momentum indicator that shows the relationship between two moving averages of a security's price."
        case .bollinger:
            return "Bollinger Bands consist of a middle band (moving average) and two outer bands (standard deviations). They help identify overbought and oversold conditions."
        }
    }
}

#Preview {
    IndicatorPanelView(indicatorManager: IndicatorManager())
}