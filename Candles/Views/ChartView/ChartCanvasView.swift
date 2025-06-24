//
//  ChartCanvasView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/12/25.
//

import SwiftUI

struct ChartCanvasView: View {
    @ObservedObject var chartEngine: ChartEngine
    @ObservedObject var indicatorManager: IndicatorManager
    let geometry: GeometryProxy
    
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragValue: DragGesture.Value?
    @GestureState private var magnification: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Grid Lines
            GridLinesView(chartEngine: chartEngine, geometry: geometry)
            
            // Price Labels
            PriceLabelsView(chartEngine: chartEngine, geometry: geometry)
            
            // Time Labels
            TimeLabelsView(chartEngine: chartEngine, geometry: geometry)
            
            // Main Chart
            HStack(spacing: 0) {
                ChartContentView(chartEngine: chartEngine, geometry: geometry)
                    .clipped()
                Spacer()
                    .frame(width: 60)
            }
            
            // Indicators
            IndicatorOverlayView(indicatorManager: indicatorManager, chartEngine: chartEngine, geometry: geometry)
            
            // Crosshair
            CrosshairView(chartEngine: chartEngine, geometry: geometry)
        }
        .clipped()
        .gesture(
            SimultaneousGesture(
                // Pan Gesture
                DragGesture()
                    .onChanged { value in
                        if let lastValue = lastDragValue {
                            let deltaX = value.translation.width - lastValue.translation.width
                            chartEngine.pan(by: deltaX)
                        }
                        lastDragValue = value
                    }
                    .onEnded { _ in
                        lastDragValue = nil
                    },
                
                // Zoom Gesture
                MagnificationGesture()
                    .updating($magnification) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        if value > 1.1 {
                            chartEngine.zoomIn()
                        } else if value < 0.9 {
                            chartEngine.zoomOut()
                        }
                    }
            )
        )
    }
}

struct GridLinesView: View {
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Horizontal grid lines (price levels)
            ForEach(0..<6, id: \.self) { i in
                let y = geometry.size.height * CGFloat(i) / 5
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            }
            
            // Vertical grid lines (time intervals)
            ForEach(0..<6, id: \.self) { i in
                let x = geometry.size.width * CGFloat(i) / 5
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            }
        }
    }
}

struct PriceLabelsView: View {
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            VStack {
                ForEach(0..<6, id: \.self) { i in
                    let normalizedY = CGFloat(i) / 5
                    let price = chartEngine.priceRange.upperBound - (Double(normalizedY) * (chartEngine.priceRange.upperBound - chartEngine.priceRange.lowerBound))
                    
                    HStack {
                        Spacer()
                        Text(String(format: "%.2f", price))
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1) // Keep it on one line
                            .minimumScaleFactor(0.7) // Allow it to shrink to 70% of its original size if needed
                            .padding(.trailing, 8)
                    }
                    
                    if i < 5 {
                        Spacer()
                    }
                }
            }
            .frame(width: 50)
            .padding(2)
            .background(Color(.gray).opacity(0.2))
            .border(Color.gray.opacity(0.3), width: 1)
        }
    }
}

struct TimeLabelsView: View {
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                ForEach(0..<5, id: \.self) { i in
                    let normalizedX = CGFloat(i) / 4
                    let dataIndex = chartEngine.visibleRange.lowerBound + Int(normalizedX * CGFloat(chartEngine.visibleRange.count - 1))
                    
                    HStack {
                        Group {
                            if chartEngine.visibleRange.contains(dataIndex) && dataIndex < chartEngine.chartData.count {
                                Text(timeLabel(for: dataIndex))
                                    .font(.caption2)
                                    .foregroundColor(Color.gray.opacity(0.3))
                                    //
                                    .padding(.horizontal, 4)
                            } else {
                                Text("")
                            }
                        }
                        
                        if i < 4 {
                            Spacer()
                        }
                    }
                }
            }
            .padding(2)
            .background(Color(.gray).opacity(0.2))
            .border(Color.gray.opacity(0.3), width: 1)
        }
    }
    
    private func timeLabel(for dataIndex: Int) -> String {
        let dataPoint = chartEngine.chartData[dataIndex]
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: dataPoint.date)
    }
}

struct ChartContentView: View {
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            switch chartEngine.chartType {
            case .candlestick:
                CandlestickChartView(chartEngine: chartEngine, geometry: geometry)
            case .line:
                LineChartView(chartEngine: chartEngine, geometry: geometry)
            case .area:
                AreaChartView(chartEngine: chartEngine, geometry: geometry)
            }
        }
    }
}

struct CandlestickChartView: View {
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            ForEach(Array(chartEngine.visibleRange), id: \.self) { index in
                if index < chartEngine.chartData.count {
                    let dataPoint = chartEngine.chartData[index]
                    let isGreen = dataPoint.close > dataPoint.open
                    
                    chartEngine.candlestickPath(for: dataPoint, at: index, in: geometry)
                        .fill(isGreen ? Color.green : Color.red)
                        .overlay(
                            chartEngine.candlestickPath(for: dataPoint, at: index, in: geometry)
                                .stroke(isGreen ? Color.green : Color.red, lineWidth: 1)
                        )
                }
            }
        }
    }
}

struct LineChartView: View {
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy
    
    var body: some View {
        chartEngine.linePath(in: geometry)
            .stroke(Color.blue, lineWidth: 2)
    }
}

struct AreaChartView: View {
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Area fill
            chartEngine.areaPath(in: geometry)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Line on top
            chartEngine.linePath(in: geometry)
                .stroke(Color.blue, lineWidth: 2)
        }
    }
}

struct CrosshairView: View {
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy
    
    @State private var crosshairPosition: CGPoint?
    
    var body: some View {
        ZStack {
            if let position = crosshairPosition {
                // Vertical line
                Path { path in
                    path.move(to: CGPoint(x: position.x, y: 0))
                    path.addLine(to: CGPoint(x: position.x, y: geometry.size.height))
                }
                .stroke(Color.gray.opacity(0.7), lineWidth: 1)
                .allowsHitTesting(false)
                
                // Horizontal line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: position.y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: position.y))
                }
                .stroke(Color.gray.opacity(0.7), lineWidth: 1)
                .allowsHitTesting(false)
                
                // Price label
                let price = chartEngine.priceAt(yPosition: position.y, in: geometry)
                Text(String(format: "%.2f", price))
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .position(x: geometry.size.width - 30, y: position.y)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    crosshairPosition = value.location
                }
                .onEnded { _ in
                    crosshairPosition = nil
                }
        )
    }
}

struct IndicatorOverlayView: View {
    @ObservedObject var indicatorManager: IndicatorManager
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            ForEach(indicatorManager.activeIndicators, id: \.id) { indicator in
                IndicatorView(indicator: indicator, chartEngine: chartEngine, geometry: geometry)
            }
        }
    }
}

struct IndicatorView: View {
    let indicator: ChartIndicator
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            ForEach(Array(indicator.values.enumerated()), id: \.offset) { index, value in
                if chartEngine.visibleRange.contains(index) && !value.isNaN {
                    let x = chartEngine.xPosition(for: index, in: geometry)
                    let y = chartEngine.yPosition(for: value, in: geometry)
                    
                    Circle()
                        .fill(indicator.color)
                        .frame(width: 2, height: 2)
                        .position(x: x, y: y)
                }
            }
            
            // Draw lines connecting the points
            Path { path in
                var firstPoint = true
                for (index, value) in indicator.values.enumerated() {
                    if chartEngine.visibleRange.contains(index) && !value.isNaN {
                        let x = chartEngine.xPosition(for: index, in: geometry)
                        let y = chartEngine.yPosition(for: value, in: geometry)
                        
                        if firstPoint {
                            path.move(to: CGPoint(x: x, y: y))
                            firstPoint = false
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
            }
            .stroke(indicator.color, lineWidth: indicator.lineWidth)
        }
    }
}
