import SwiftUI

struct ChartView: View {
    @State private var chartData: [CandleData] = []

    var body: some View {
        WebView(htmlFileName: "chart", chartData: chartData)
            .ignoresSafeArea()
            .onAppear {
                generateDummyData()
            }
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

        self.chartData = data
        print("📊 Swift: Generated \(data.count) candles")
        print(
            "📊 Swift: First candle - Open: \(data.first?.open ?? 0), Close: \(data.first?.close ?? 0)"
        )
    }
}

struct CandleData: Codable {
    let time: Double
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        ChartView()
    }
}
