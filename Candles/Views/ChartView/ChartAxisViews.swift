//
//  ChartAxisViews.swift
//  Candles
//
//  Created by Assistant on Chart Improvement
//

import SwiftUI

struct PriceAxisView: View {
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { i in
                let normalizedY = CGFloat(i) / 5
                let price =
                    chartEngine.priceRange.upperBound
                    - (Double(normalizedY)
                        * (chartEngine.priceRange.upperBound - chartEngine.priceRange.lowerBound))

                HStack {
                    Spacer()
                    Text(String(format: "%.2f", price))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.trailing, 8)
                }

                if i < 5 {
                    Spacer()
                }
            }
        }
        .background(Color.black.opacity(0.05))
        .border(Color.gray.opacity(0.3), width: 0.5)
    }
}

struct TimeAxisView: View {
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                let normalizedX = CGFloat(i) / 4
                let dataIndex =
                    chartEngine.visibleRange.lowerBound
                    + Int(normalizedX * CGFloat(chartEngine.visibleRange.count - 1))

                HStack {
                    Group {
                        if chartEngine.visibleRange.contains(dataIndex)
                            && dataIndex < chartEngine.chartData.count
                        {
                            Text(timeLabel(for: dataIndex))
                                .font(.caption2)
                                .foregroundColor(.gray)
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
    }

    private func timeLabel(for dataIndex: Int) -> String {
        let dataPoint = chartEngine.chartData[dataIndex]
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: dataPoint.date)
    }
}

struct ChartGridLinesView: View {
    @ObservedObject var chartEngine: ChartEngine
    let geometry: GeometryProxy

    var body: some View {
        ZStack {
            // Horizontal grid lines (price levels)
            ForEach(0..<6, id: \.self) { i in
                let y = geometry.size.height * CGFloat(i) / 5
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width - 60, y: y))  // Exclude price axis area
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            }

            // Vertical grid lines (time intervals)
            ForEach(0..<6, id: \.self) { i in
                let x = (geometry.size.width - 60) * CGFloat(i) / 5  // Adjust for price axis
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height - 30))  // Exclude time axis area
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            }
        }
    }
}
