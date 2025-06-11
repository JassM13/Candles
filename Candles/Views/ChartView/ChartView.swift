//
//  ChartView.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/10/25.
//

import Combine  // Needed for AnyCancellable
import SwiftUI

// MARK: - Data Structures (Mirrors what's in Widgets/Common/ChartData.swift for now)
// Consider moving to a shared location if used by both app and widgets extensively.
struct OHLCDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}

// Enum for Timeframe - can be shared or redefined as needed
enum ChartTimeframe: String, CaseIterable, Identifiable {
    case fiveMin = "5m"
    case fifteenMin = "15m"
    case oneHour = "1h"
    // Add more as needed

    var id: String { self.rawValue }

    func toMinutes() -> Int {
        switch self {
        case .fiveMin: return 5
        case .fifteenMin: return 15
        case .oneHour: return 60
        }
    }
}

// MARK: - Chart View Model

class ChartViewModel: ObservableObject {
    @Published var ohlcData: [OHLCDataPoint] = []
    @Published var selectedTimeframe: ChartTimeframe = .fifteenMin
    @Published var isLoading: Bool = false
    @Published var indicatorManager = IndicatorManager()
    // Add properties for selected symbol, etc.

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadChartData()

        // Observe changes in OHLC data to recalculate indicators
        $ohlcData
            .dropFirst()  // Don't recalculate on initial load if loadChartData handles it
            .receive(on: DispatchQueue.main)  // Ensure updates on main thread
            .sink { [weak self] newData in
                guard let self = self else { return }
                self.indicatorManager.recalculateAllIndicators(ohlcData: newData)
            }
            .store(in: &cancellables)
    }

    func loadChartData() {
        isLoading = true
        // Replace with actual data fetching logic (e.g., from NetworkManager)
        // For now, using dummy data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {  // Simulate network delay
            let newData = self.generateDummyData(for: self.selectedTimeframe)
            self.ohlcData = newData  // This will trigger the sink above for indicator recalculation
            self.isLoading = false
        }
    }

    func changeTimeframe(to timeframe: ChartTimeframe) {
        selectedTimeframe = timeframe
        loadChartData()  // This will trigger ohlcData update and subsequently indicator recalculation
    }

    func addSampleIndicator(type: String = "SMA") {
        if type == "SMA" {
            let sma = MovingAverageIndicator(period: 20, color: .orange)
            indicatorManager.addIndicator(sma, ohlcData: ohlcData)
        } else if type == "NWOG" {
            // Placeholder for NWOG indicator - will be defined later
            let nwog = NWOGIndicator()  // Assuming NWOGIndicator is defined
            indicatorManager.addIndicator(nwog, ohlcData: ohlcData)
        }
        // Potentially add more indicator types or a way to select them
    }

    func removeIndicator(_ indicator: Indicator) {
        indicatorManager.removeIndicator(indicator)
    }

    func listIndicators() -> [Indicator] {
        return indicatorManager.activeIndicators
    }

    // Dummy data generation (adapted from Widgets/Common/ChartData.swift)
    private func generateDummyData(for timeframe: ChartTimeframe) -> [OHLCDataPoint] {
        var dataPoints: [OHLCDataPoint] = []
        let calendar = Calendar.current
        let now = Date()
        let numberOfCandles: Int
        switch timeframe {
        case .fiveMin: numberOfCandles = 96  // Approx 8 hours
        case .fifteenMin: numberOfCandles = 64  // Approx 16 hours
        case .oneHour: numberOfCandles = 48  // Approx 2 days
        }

        var lastClose = Double.random(in: 100...200)

        for i in 0..<numberOfCandles {
            let date = calendar.date(byAdding: .minute, value: -i * timeframe.toMinutes(), to: now)!
            let open = (i == 0) ? lastClose + Double.random(in: -1...1) : lastClose
            let priceMovement = Double.random(in: -5...5)
            let close = open + priceMovement
            let high = max(open, close) + Double.random(in: 0.1...3)
            let low = min(open, close) - Double.random(in: 0.1...3)

            dataPoints.append(
                OHLCDataPoint(date: date, open: open, high: high, low: low, close: close))
            lastClose = close
        }
        return dataPoints.reversed()
    }
}

// MARK: - ChartView

struct ChartView: View {
    @StateObject private var viewModel = ChartViewModel()
    @State private var showingIndicatorSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Timeframe Picker
                Picker("Timeframe", selection: $viewModel.selectedTimeframe) {
                    ForEach(ChartTimeframe.allCases) { timeframe in
                        Text(timeframe.rawValue.uppercased()).tag(timeframe)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: viewModel.selectedTimeframe) { newTimeframe in
                    viewModel.changeTimeframe(to: newTimeframe)
                }

                // Chart Area
                if viewModel.isLoading {
                    ProgressView("Loading Chart...")
                    Spacer()
                } else if viewModel.ohlcData.isEmpty {
                    Text("No chart data available.")
                    Spacer()
                } else {
                    // Pass the indicator manager to the chart view
                    CandleStickChartView(
                        dataPoints: viewModel.ohlcData, indicatorManager: viewModel.indicatorManager
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingIndicatorSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingIndicatorSheet) {
                IndicatorSelectionView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - CandleStick Chart Drawing View

struct CandleStickChartView: View {
    let dataPoints: [OHLCDataPoint]
    @ObservedObject var indicatorManager: IndicatorManager  // Observe the manager for updates
    let candleWidthRatio: CGFloat = 0.8  // Relative width of candle to its allocated space
    let spacingRatio: CGFloat = 0.2  // Relative spacing

    var body: some View {
        GeometryReader { geometry in
            let (minPrice, maxPrice) = calculatePriceRange()
            let chartPriceRange = maxPrice - minPrice
            let totalCandleAndSpaceWidth = geometry.size.width / CGFloat(dataPoints.count)
            let candleWidth = totalCandleAndSpaceWidth * candleWidthRatio
            // let spacing = totalCandleAndSpaceWidth * spacingRatio

            ZStack {
                // Candlestick drawing
                HStack(alignment: .bottom, spacing: totalCandleAndSpaceWidth * spacingRatio) {
                    ForEach(dataPoints) { dataPoint in
                        SingleCandleView(
                            dataPoint: dataPoint,
                            minPrice: minPrice,
                            maxPrice: maxPrice,
                            chartPriceRange: chartPriceRange,
                            availableHeight: geometry.size.height
                        )
                        .frame(width: candleWidth)
                    }
                }
                .padding(.horizontal, totalCandleAndSpaceWidth * spacingRatio / 2)  // Center candles

                // Indicator Drawing Layer
                Canvas { context, size in
                    // Iterate through active indicators and draw them
                    for indicator in indicatorManager.activeIndicators {
                        if let data = indicatorManager.indicatorData[indicator.id] {
                            indicator.draw(
                                context: context, geometry: geometry, ohlcData: dataPoints,
                                indicatorData: data, priceMin: minPrice, priceMax: maxPrice)
                        }
                    }
                }
                // .allowsHitTesting(false) // So it doesn't interfere with chart interactions if any are added
            }
        }
    }

    private func calculatePriceRange() -> (min: Double, max: Double) {
        guard !dataPoints.isEmpty else { return (0, 0) }
        let lows = dataPoints.map { $0.low }
        let highs = dataPoints.map { $0.high }
        return (lows.min() ?? 0, highs.max() ?? 0)
    }
}

// MARK: - Single Candle View

struct SingleCandleView: View {
    let dataPoint: OHLCDataPoint
    let minPrice: Double
    let maxPrice: Double
    let chartPriceRange: Double
    let availableHeight: CGFloat

    private var candleColor: Color {
        dataPoint.open > dataPoint.close ? .red : .green
    }

    var body: some View {
        guard chartPriceRange > 0 else { return AnyView(EmptyView()) }

        let highYRatio = (maxPrice - dataPoint.high) / chartPriceRange
        let lowYRatio = (maxPrice - dataPoint.low) / chartPriceRange
        let openYRatio = (maxPrice - dataPoint.open) / chartPriceRange
        let closeYRatio = (maxPrice - dataPoint.close) / chartPriceRange

        let wickTopY = CGFloat(highYRatio) * availableHeight
        let wickBottomY = CGFloat(lowYRatio) * availableHeight

        let bodyTopYRatio = min(openYRatio, closeYRatio)
        let bodyBottomYRatio = max(openYRatio, closeYRatio)

        let bodyTopPixel = CGFloat(bodyTopYRatio) * availableHeight
        let bodyHeightPixel = CGFloat(bodyBottomYRatio - bodyTopYRatio) * availableHeight

        return AnyView(
            ZStack(alignment: .top) {
                // Wick
                Path { path in
                    path.move(to: CGPoint(x: UIScreen.main.scale / 2, y: wickTopY))
                    path.addLine(to: CGPoint(x: UIScreen.main.scale / 2, y: wickBottomY))
                }
                .stroke(Color.gray, lineWidth: UIScreen.main.scale)  // Use scale for sharp 1px line

                // Body
                Rectangle()
                    .fill(candleColor)
                    .frame(height: max(UIScreen.main.scale, bodyHeightPixel))  // Ensure min height for visibility
                    .offset(y: bodyTopPixel)
            }
        )
    }
}

// MARK: - Preview

// MARK: - Indicator Selection Sheet

struct IndicatorSelectionView: View {
    @ObservedObject var viewModel: ChartViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Available Indicators") {
                    Button("Add SMA (20)") {
                        viewModel.addSampleIndicator(type: "SMA")
                    }
                    Button("Add NWOG (Demo)") {  // Button for NWOG
                        viewModel.addSampleIndicator(type: "NWOG")
                    }
                    // Add more buttons for other predefined indicators or Lua scripts
                }

                Section("Active Indicators") {
                    if viewModel.indicatorManager.activeIndicators.isEmpty {
                        Text("No active indicators.").foregroundColor(.gray)
                    }
                    ForEach(viewModel.indicatorManager.activeIndicators, id: \.id) { indicator in
                        HStack {
                            Text(indicator.name)
                            Spacer()
                            Button {
                                viewModel.removeIndicator(indicator)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage Indicators")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        ChartView()
    }
}
