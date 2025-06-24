//
//  ChartControlsView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/12/25.
//

import SwiftUI


struct ChartControlsView: View {
    @Binding var selectedTimeframe: Timeframe
    @Binding var chartType: ChartType
    @ObservedObject var chartEngine: ChartEngine
    
    @State private var showingTimeframeSelector = false
    @State private var showingChartSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Controls Row
            HStack(spacing: 12) {
                // Timeframe Selector
                TimeframeSelectorView(
                    selectedTimeframe: $selectedTimeframe,
                    showingSelector: $showingTimeframeSelector
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Extended Timeframe Options (when expanded)
            if showingTimeframeSelector {
                ExtendedTimeframeView(
                    selectedTimeframe: $selectedTimeframe,
                    onSelection: {
                        showingTimeframeSelector = false
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
        .sheet(isPresented: $showingChartSettings) {
            ChartSettingsView(chartEngine: chartEngine)
        }
    }
}

struct TimeframeSelectorView: View {
    @Binding var selectedTimeframe: Timeframe
    @Binding var showingSelector: Bool
    
    private let quickTimeframes: [Timeframe] = [.fiveMin, .fifteenMin, .oneHour]
    
    var body: some View {
        HStack(spacing: 8) {
            // Quick timeframe buttons
            ForEach(quickTimeframes, id: \.self) { timeframe in
                Button(action: {
                    selectedTimeframe = timeframe
                }) {
                    Text(timeframe.shortName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(selectedTimeframe == timeframe ? .white : .primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedTimeframe == timeframe ? Color.blue : Color(.systemGray5))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // More button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingSelector.toggle()
                }
            }) {
                Image(systemName: showingSelector ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color(.systemGray5))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct ExtendedTimeframeView: View {
    @Binding var selectedTimeframe: Timeframe
    let onSelection: () -> Void
    
    private let allTimeframes = Timeframe.allCases
    private let columns = Array(repeating: GridItem(.flexible()), count: 4)
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Select Timeframe")
                .font(.headline)
                .padding(.top)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(allTimeframes, id: \.self) { timeframe in
                    Button(action: {
                        selectedTimeframe = timeframe
                        onSelection()
                    }) {
                        VStack(spacing: 4) {
                            Text(timeframe.shortName)
                                .font(.system(size: 14, weight: .semibold))
                            
                            Text(timeframe.rawValue)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(selectedTimeframe == timeframe ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTimeframe == timeframe ? Color.blue : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemGray6))
    }
}

struct ZoomControlsView: View {
    @ObservedObject var chartEngine: ChartEngine
    
    var body: some View {
        HStack(spacing: 8) {
            // Zoom Out
            Button(action: {
                chartEngine.zoomOut()
            }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color(.systemGray5))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!chartEngine.canZoomOut)
            
            // Zoom Level Indicator
            Text("\(Int(chartEngine.zoomLevel * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40)
            
            // Zoom In
            Button(action: {
                chartEngine.zoomIn()
            }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color(.systemGray5))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!chartEngine.canZoomIn)
            
            // Reset Zoom
            Button(action: {
                chartEngine.resetZoom()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color(.systemGray5))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct ChartSettingsView: View {
    @ObservedObject var chartEngine: ChartEngine
    @Environment(\.dismiss) private var dismiss
    
    @State private var showGrid = true
    @State private var showVolume = true
    @State private var showCrosshair = true
    @State private var candleWidth: Double = 8.0
    @State private var lineWidth: Double = 2.0
    
    var body: some View {
        NavigationView {
            Form {
                Section("Display Options") {
                    Toggle("Show Grid Lines", isOn: $showGrid)
                    Toggle("Show Volume", isOn: $showVolume)
                    Toggle("Show Crosshair", isOn: $showCrosshair)
                }
                
                Section("Chart Appearance") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Candle Width: \(Int(candleWidth))px")
                            .font(.headline)
                        
                        Slider(value: $candleWidth, in: 4...20, step: 1)
                        
                        Text("Adjust the width of candlesticks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Line Width: \(String(format: "%.1f", lineWidth))px")
                            .font(.headline)
                        
                        Slider(value: $lineWidth, in: 1.0...5.0, step: 0.5)
                        
                        Text("Adjust the width of chart lines")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Chart Colors") {
                    ChartColorSettings()
                }
                
                Section("Performance") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visible Candles: \(chartEngine.visibleCandleCount)")
                            .font(.headline)
                        
                        Text("Zoom Level: \(String(format: "%.1f", chartEngine.zoomLevel))x")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Pan Offset: \(String(format: "%.1f", chartEngine.panOffset))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Chart Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        applySettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        // Load current settings from chartEngine
        showGrid = true // chartEngine.showGrid
        showVolume = true // chartEngine.showVolume
        showCrosshair = true // chartEngine.showCrosshair
        candleWidth = 8.0 // chartEngine.candleWidth
        lineWidth = 2.0 // chartEngine.lineWidth
    }
    
    private func applySettings() {
        // Apply settings to chartEngine
        // chartEngine.showGrid = showGrid
        // chartEngine.showVolume = showVolume
        // chartEngine.showCrosshair = showCrosshair
        // chartEngine.candleWidth = candleWidth
        // chartEngine.lineWidth = lineWidth
    }
    
    private func resetToDefaults() {
        showGrid = true
        showVolume = true
        showCrosshair = true
        candleWidth = 8.0
        lineWidth = 2.0
    }
}

struct ChartColorSettings: View {
    @State private var bullishColor = Color.green
    @State private var bearishColor = Color.red
    @State private var gridColor = Color.gray
    @State private var backgroundColor = Color.black
    
    var body: some View {
        VStack(spacing: 16) {
            ColorSettingRow(title: "Bullish Candles", color: $bullishColor)
            ColorSettingRow(title: "Bearish Candles", color: $bearishColor)
            ColorSettingRow(title: "Grid Lines", color: $gridColor)
            ColorSettingRow(title: "Background", color: $backgroundColor)
        }
    }
}

struct ColorSettingRow: View {
    let title: String
    @Binding var color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            
            Spacer()
            
            ColorPicker("Select Color", selection: $color)
                .labelsHidden()
                .frame(width: 50, height: 30)
        }
    }
}

// MARK: - Extensions
extension Timeframe {
    var shortName: String {
        switch self {
        case .fiveMin: return "5m"
        case .fifteenMin: return "15m"
        case .oneHour: return "1h"
        }
    }
}

extension ChartEngine {
    var canZoomIn: Bool {
        zoomLevel < 5.0
    }
    
    var canZoomOut: Bool {
        zoomLevel > 0.1
    }
    
    func resetZoom() {
        zoomLevel = 1.0
        panOffset = 0.0
    }
}

#Preview {
    ChartControlsView(
        selectedTimeframe: .constant(.oneHour),
        chartType: .constant(.candlestick),
        chartEngine: ChartEngine()
    )
}
