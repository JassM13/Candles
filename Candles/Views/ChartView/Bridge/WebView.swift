import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let htmlFileName: String
    let chartData: [CandleData]

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        // Add all message handlers
        userContentController.add(context.coordinator, name: "log")
        userContentController.add(context.coordinator, name: "error")
        userContentController.add(context.coordinator, name: "chartReady")
        userContentController.add(context.coordinator, name: "dataRequest")
        userContentController.add(context.coordinator, name: "timeframeChanged")

        configuration.userContentController = userContentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false

        // Store webView reference in coordinator
        context.coordinator.webView = webView
        
        // Initialize the webview only once during creation
        context.coordinator.initializeWebView(htmlFileName: htmlFileName)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Update coordinator's parent reference to get latest chartData
        context.coordinator.parent = self
        
        // Only send data updates, don't reload the webview
        context.coordinator.updateChartDataIfNeeded()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        weak var webView: WKWebView?
        private var isWebViewInitialized = false
        private var isChartReady = false
        private var lastDataCount = 0

        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func initializeWebView(htmlFileName: String) {
            guard !isWebViewInitialized, let webView = webView else { return }
            
            // Clean the filename - remove .html extension if present
            let cleanFileName = htmlFileName.replacingOccurrences(of: ".html", with: "")
            
            if let fallbackUrl = Bundle.main.url(forResource: cleanFileName, withExtension: "html") {
                print("📁 Found HTML file in main bundle: \(fallbackUrl.path)")
                webView.loadFileURL(
                    fallbackUrl, allowingReadAccessTo: fallbackUrl.deletingLastPathComponent())
                isWebViewInitialized = true
            } else {
                print("❌ HTML file not found anywhere in bundle")
            }
        }
        
        func updateChartDataIfNeeded() {
            // Only update if chart is ready and data has changed
            guard isChartReady, 
                  !parent.chartData.isEmpty,
                  parent.chartData.count != lastDataCount else { return }
            
            lastDataCount = parent.chartData.count
            sendChartData()
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
                // Send initial data if available
                if !parent.chartData.isEmpty {
                    lastDataCount = parent.chartData.count
                    sendChartData()
                }
            case "dataRequest":
                print("📈 Chart requesting data")
                if !parent.chartData.isEmpty {
                    lastDataCount = parent.chartData.count
                    sendChartData()
                }
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

        func sendChartData() {
            guard let webView = webView else { return }

            do {
                let jsonData = try JSONEncoder().encode(parent.chartData)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

                let script =
                    "if (typeof updateChartData === 'function') { updateChartData(\(jsonString)); }"

                webView.evaluateJavaScript(script) { result, error in
                    if let error = error {
                        print("❌ Error sending data to chart: \(error.localizedDescription)")
                    } else {
                        print(
                            "✅ Chart data sent successfully (\(self.parent.chartData.count) candles)"
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
}
