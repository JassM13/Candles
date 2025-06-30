import Foundation

class ChartViewModel: ObservableObject {
    @Published var chartData: [CandleData] = []

    init() {
        generateDummyData()
    }




    private func generateDummyData() {
        let calendar = Calendar.current
        let now = Date()
        var data: [CandleData] = []
        var currentPrice = 100.0

        for i in 0..<50 {
            let date = calendar.date(byAdding: .day, value: -i, to: now) ?? now

            // Generate realistic price movement
            let change = Double.random(in: -2.0...2.0)
            currentPrice += change

            let open = currentPrice
            let volatility = Double.random(in: 0.5...3.0)
            let high = open + Double.random(in: 0...volatility)
            let low = open - Double.random(in: 0...volatility)
            let close = Double.random(in: low...high)

            currentPrice = close

            let candle = CandleData(
                time: date.timeIntervalSince1970 * 1000,  // Convert to milliseconds
                open: open,
                high: high,
                low: low,
                close: close
            )

            data.insert(candle, at: 0)  // Insert at beginning to maintain chronological order
        }

        DispatchQueue.main.async {
            self.chartData = data
            print("📊 Swift: Generated \(data.count) candles")
            print(
                "📊 Swift: First candle - Open: \(data.first?.open ?? 0), Close: \(data.first?.close ?? 0)"
            )
        }
    }
    
    // Method to update chart data from external sources
    func updateChartData(_ newData: [CandleData]) {
        DispatchQueue.main.async {
            self.chartData = newData
            print("📊 Swift: Chart data updated with \(newData.count) candles")
        }
    }
    
    // Method to add new candle data
    func addCandle(_ candle: CandleData) {
        DispatchQueue.main.async {
            self.chartData.append(candle)
            print("📊 Swift: Added new candle at time \(candle.time)")
        }
    }
    
    // Method to refresh/regenerate dummy data
    func refreshData() {
        generateDummyData()
    }
    
    // Method to simulate real-time data updates for testing
    func simulateDataUpdate() {
        guard !chartData.isEmpty else { return }
        
        DispatchQueue.main.async {
            // Update the last candle with new values
            var updatedData = self.chartData
            if let lastCandle = updatedData.last {
                let newClose = lastCandle.close + Double.random(in: -2.0...2.0)
                let newHigh = max(lastCandle.high, newClose)
                let newLow = min(lastCandle.low, newClose)
                
                let updatedCandle = CandleData(
                    time: lastCandle.time,
                    open: lastCandle.open,
                    high: newHigh,
                    low: newLow,
                    close: newClose
                )
                
                updatedData[updatedData.count - 1] = updatedCandle
                self.chartData = updatedData
                print("📊 Swift: Simulated data update - new close: \(newClose)")
            }
        }
    }
}
