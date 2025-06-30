import SwiftUI
import WebKit

struct ChartView: View, UIViewRepresentable {
    @StateObject private var viewModel = ChartViewModel()
    var onCoordinatorReady: ((ChartCoordinator) -> Void)? = nil
    
    // Expose the viewModel for external access if needed
    var chartViewModel: ChartViewModel {
        return viewModel
    }

    func makeUIView(context: Context) -> WKWebView {
        // Get a pre-initialized WebView from the pool
        let webView = WebViewPool.shared.getWebView()

        // Configure the WebView for this specific use
        let userContentController = webView.configuration.userContentController

        // Add all message handlers
        userContentController.add(context.coordinator, name: "log")
        userContentController.add(context.coordinator, name: "error")
        userContentController.add(context.coordinator, name: "chartReady")
        userContentController.add(context.coordinator, name: "dataRequest")
        userContentController.add(context.coordinator, name: "timeframeChanged")

        webView.navigationDelegate = context.coordinator

        // Store webView reference in coordinator
        context.coordinator.webView = webView

        // Initialize the webview only once during creation
        context.coordinator.initializeWebView(htmlFileName: "chart")

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Check if the chart is ready and send data if it has changed or if this is the first time
        let newDataHash = viewModel.chartData.hashValue
        if context.coordinator.isChartReady && (newDataHash != context.coordinator.lastDataHash || context.coordinator.lastDataHash == 0) {
            print("📊 Chart data changed, sending update...")
            context.coordinator.lastDataHash = newDataHash
            context.coordinator.sendChartData(data: viewModel.chartData)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: ChartCoordinator) {
        // Clean up the WebView before returning to pool
        coordinator.cleanupWebView()
    }

    func makeCoordinator() -> ChartCoordinator {
         let coordinator = ChartCoordinator()
         onCoordinatorReady?(coordinator)
         return coordinator
     }
 }
 
 // New struct that accepts an external viewModel
 struct ChartViewWithViewModel: View, UIViewRepresentable {
     @ObservedObject var viewModel: ChartViewModel
     var onCoordinatorReady: ((ChartCoordinator) -> Void)? = nil

    func makeUIView(context: Context) -> WKWebView {
        // Get a pre-initialized WebView from the pool
        let webView = WebViewPool.shared.getWebView()

        // Configure the WebView for this specific use
        let userContentController = webView.configuration.userContentController

        // Add all message handlers
        userContentController.add(context.coordinator, name: "log")
        userContentController.add(context.coordinator, name: "error")
        userContentController.add(context.coordinator, name: "chartReady")
        userContentController.add(context.coordinator, name: "dataRequest")
        userContentController.add(context.coordinator, name: "timeframeChanged")

        webView.navigationDelegate = context.coordinator

        // Store webView reference in coordinator
        context.coordinator.webView = webView

        // Initialize the webview only once during creation
        context.coordinator.initializeWebView(htmlFileName: "chart")

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Check if the chart is ready and send data if it has changed or if this is the first time
        let newDataHash = viewModel.chartData.hashValue
        if context.coordinator.isChartReady && (newDataHash != context.coordinator.lastDataHash || context.coordinator.lastDataHash == 0) {
            print("📊 Chart data changed, sending update...")
            context.coordinator.lastDataHash = newDataHash
            context.coordinator.sendChartData(data: viewModel.chartData)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: ChartCoordinator) {
        // Clean up the WebView before returning to pool
        coordinator.cleanupWebView()
    }

    func makeCoordinator() -> ChartCoordinator {
        let coordinator = ChartCoordinator()
        onCoordinatorReady?(coordinator)
        return coordinator
    }
 }

 class ChartCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        private var isWebViewInitialized = false
        var isChartReady = false
        var lastDataHash = 0


        deinit {
            // Clean up and return the WebView to the pool when the coordinator is deallocated
            cleanupWebView()
        }

        func cleanupWebView() {
            guard let webView = webView else { return }

            // Reset state
            isWebViewInitialized = false
            isChartReady = false
            lastDataHash = 0

            // Return the WebView to the pool
            WebViewPool.shared.returnWebView(webView)
            self.webView = nil
        }

        func initializeWebView(htmlFileName: String) {
            guard !isWebViewInitialized, let webView = webView else { return }

            // Clean the filename - remove .html extension if present
            let cleanFileName = htmlFileName.replacingOccurrences(of: ".html", with: "")

            // Check if the WebView already has the correct content loaded (from pool)
            if cleanFileName == "chart" && webView.url?.lastPathComponent.contains("chart") == true
            {
                print("📊 Chart HTML already loaded from pool, skipping reload")
                isWebViewInitialized = true
                return
            }

            if let fallbackUrl = Bundle.main.url(forResource: cleanFileName, withExtension: "html")
            {
                print("📁 Loading HTML file: \(fallbackUrl.path)")
                webView.loadFileURL(
                    fallbackUrl, allowingReadAccessTo: fallbackUrl.deletingLastPathComponent())
                isWebViewInitialized = true
            } else {
                print("❌ HTML file not found anywhere in bundle")
            }
        }



        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "log":
                if let log = message.body as? String {
                    print("📊 Chart JS: \(log)")
                }
            case "error":
                if let error = message.body as? String {
                    print("❌ Chart Error: \(error)")
                }
            case "chartReady":
                print("✅ Chart initialized successfully")
                isChartReady = true
                // Trigger updateUIView to send initial data by resetting lastDataHash
                lastDataHash = 0
            case "dataRequest":
                print("📈 Chart requesting data")
                // The updateUIView logic will handle sending the data
            case "timeframeChanged":
                if let timeframe = message.body as? String {
                    print("⏰ Timeframe changed to: \(timeframe)")
                    // Here you can handle the timeframe change
                    // For example, fetch new data for the selected timeframe
                }
            default:
                print("🔍 Unknown message from JS: \(message.name) - \(message.body)")
            }
        }

        func sendChartData(data: [CandleData]) {
            guard let webView = webView else { return }

            do {
                let jsonData = try JSONEncoder().encode(data)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

                let script =
                    "if (typeof updateChartData === 'function') { updateChartData(\(jsonString)); }"

                webView.evaluateJavaScript(script) { result, error in
                    if let error = error {
                        print("❌ Error sending data to chart: \(error.localizedDescription)")
                    } else {
                        print(
                            "✅ Chart data sent successfully (\(data.count) candles)"
                        )
                    }
                }
            } catch {
                print("❌ Error encoding chart data: \(error.localizedDescription)")
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("🌐 WebView finished loading")
        }

        func webView(
            _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
        ) {
            print("❌ WebView failed to load: \(error.localizedDescription)")
        }
    }

