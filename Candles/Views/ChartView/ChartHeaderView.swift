//
//  ChartHeaderView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/12/25.
//

import SwiftUI
import WidgetKit

struct ChartHeaderView: View {
    let selectedSymbol: String
    let selectedTimeframe: Timeframe
    let currentPrice: Double?
    let priceChange: Double?
    let percentChange: Double?
    let volume: Double?
    let high24h: Double?
    let low24h: Double?
    
    @Binding var showingIndicators: Bool
    @Binding var showingScripting: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Top Row: Symbol and Controls
            HStack {
                // Symbol and Timeframe
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedSymbol)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(selectedTimeframe.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // Control Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        showingIndicators.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "function")
                            Text("Indicators")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(showingIndicators ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(showingIndicators ? Color.blue : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showingScripting.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                            Text("Script")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(showingScripting ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(showingScripting ? Color.blue : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Price Information Row
            if let currentPrice = currentPrice {
                HStack(spacing: 20) {
                    // Current Price
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Price")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(formatPrice(currentPrice))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(getPriceColor())
                    }
                    
                    // Price Change
                    if let priceChange = priceChange, let percentChange = percentChange {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Change")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: priceChange >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption)
                                
                                Text("\(formatPrice(abs(priceChange))) (\(formatPercent(abs(percentChange))))")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(priceChange >= 0 ? .green : .red)
                        }
                    }
                    
                    Spacer()
                    
                    // 24h High/Low
                    if let high24h = high24h, let low24h = low24h {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("24h Range")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .trailing, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text("H:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatPrice(high24h))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                HStack(spacing: 4) {
                                    Text("L:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(formatPrice(low24h))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                    
                    // Volume
                    if let volume = volume {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Volume")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(formatVolume(volume))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    private func getPriceColor() -> Color {
        guard let priceChange = priceChange else { return .primary }
        return priceChange >= 0 ? .green : .red
    }
    
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "$%.2f", price)
        } else if price >= 1 {
            return String(format: "$%.4f", price)
        } else {
            return String(format: "$%.6f", price)
        }
    }
    
    private func formatPercent(_ percent: Double) -> String {
        return String(format: "%.2f%%", percent)
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000_000 {
            return String(format: "%.1fB", volume / 1_000_000_000)
        } else if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.1fK", volume / 1_000)
        } else {
            return String(format: "%.0f", volume)
        }
    }
}

// MARK: - Chart Stats View
struct ChartStatsView: View {
    let data: [OHLCDataPoint]
    let visibleRange: Range<Int>
    
    var body: some View {
        if !data.isEmpty && !visibleRange.isEmpty {
            let visibleData = Array(data[visibleRange])
            let stats = calculateStats(from: visibleData)
            
            HStack(spacing: 16) {
                StatItem(title: "Open", value: formatPrice(stats.open), color: .primary)
                StatItem(title: "High", value: formatPrice(stats.high), color: .green)
                StatItem(title: "Low", value: formatPrice(stats.low), color: .red)
                StatItem(title: "Close", value: formatPrice(stats.close), color: .primary)
                StatItem(title: "Volume", value: formatVolume(stats.volume), color: .secondary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
        }
    }
    
    private func calculateStats(from data: [OHLCDataPoint]) -> (open: Double, high: Double, low: Double, close: Double, volume: Double) {
        guard !data.isEmpty else {
            return (0, 0, 0, 0, 0)
        }
        
        let open = data.first?.open ?? 0
        let close = data.last?.close ?? 0
        let high = data.map { $0.high }.max() ?? 0
        let low = data.map { $0.low }.min() ?? 0
        let volume = data.map { $0.volume }.reduce(0, +)
        
        return (open, high, low, close, volume)
    }
    
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "$%.2f", price)
        } else if price >= 1 {
            return String(format: "$%.4f", price)
        } else {
            return String(format: "$%.6f", price)
        }
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000_000 {
            return String(format: "%.1fB", volume / 1_000_000_000)
        } else if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.1fK", volume / 1_000)
        } else {
            return String(format: "%.0f", volume)
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Chart Type Selector
struct ChartTypeSelector: View {
    @Binding var chartType: ChartType
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ChartType.allCases, id: \.self) { type in
                Button(action: {
                    chartType = type
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                        Text(type.rawValue)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(chartType == type ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(chartType == type ? Color.blue : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}



#Preview {
    VStack {
        ChartHeaderView(
            selectedSymbol: "BTCUSDT",
            selectedTimeframe: .oneHour,
            currentPrice: 45250.75,
            priceChange: 1250.25,
            percentChange: 2.84,
            volume: 125_000_000,
            high24h: 46100.00,
            low24h: 43800.50,
            showingIndicators: .constant(false),
            showingScripting: .constant(false)
        )
        
        Spacer()
    }
}