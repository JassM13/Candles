//
//  ChartView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/12/25.
//

import SwiftUI
import Combine

struct ChartView: View {
    @StateObject private var chartEngine = ChartEngine()
    @StateObject private var indicatorManager = IndicatorManager()
    @State private var selectedTimeframe: Timeframe = .fifteenMin
    @State private var selectedSymbol: String = "AAPL"
    @State private var chartType: ChartType = .candlestick
    @State private var showScriptingView = false
    @State private var showIndicatorPanel = false

      var body: some View {
        VStack(spacing: 0) {

            
            // Main Chart Area
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color.black.opacity(0.05)
                    
                    // Chart Canvas
                    ChartCanvasView(
                        chartEngine: chartEngine,
                        indicatorManager: indicatorManager,
                        geometry: geometry
                    )
                }
            }
            
            // Chart Controls
            ChartControlsView(
                selectedTimeframe: $selectedTimeframe,
                chartType: $chartType,
                chartEngine: chartEngine
            )
        }
        .onAppear {
            loadChartData()
        }
        .onChange(of: selectedSymbol) { _ in
            loadChartData()
        }
        .onChange(of: selectedTimeframe) { _ in
            loadChartData()
        }
        .sheet(isPresented: $showScriptingView) {
            TickScriptDSLView(
                isVisible: $showScriptingView,
                indicatorManager: indicatorManager
            )
        }
        .sheet(isPresented: $showIndicatorPanel) {
            IndicatorPanelView(indicatorManager: indicatorManager)
        }
    }
    
    private func loadChartData() {
        // Load chart data based on symbol and timeframe
        let dummyData = getDummyData(for: selectedTimeframe)
        chartEngine.updateData(dummyData)
    }
}