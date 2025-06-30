//
//  WebViewPool.swift
//  Candles
//
//  Created by AI Assistant
//

import Foundation
import UIKit
import WebKit

class WebViewPool: ObservableObject {
    static let shared = WebViewPool()

    private var availableWebViews: [WKWebView] = []
    private var inUseWebViews: Set<WKWebView> = []
    private let poolSize = 2  // Keep 2 pre-initialized WebViews
    private let queue = DispatchQueue(label: "webview.pool", qos: .userInitiated)

    private init() {
        // Initialize the pool on app launch
        initializePool()
    }

    private func initializePool() {
        // WebViews must be created on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            for _ in 0..<self.poolSize {
                let webView = self.createPreConfiguredWebView()
                self.queue.async {
                    self.availableWebViews.append(webView)
                }
            }

            print("🏊‍♂️ WebView pool initialized with \(self.poolSize) WebViews")
        }
    }

    private func createPreConfiguredWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        configuration.userContentController = userContentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false

        // Pre-load the actual chart HTML file if available
        if let chartUrl = Bundle.main.url(forResource: "chart", withExtension: "html") {
            webView.loadFileURL(
                chartUrl, allowingReadAccessTo: chartUrl.deletingLastPathComponent())
            print("📊 Pre-loaded chart.html in WebView pool")
        } else {
            // Fallback to minimal HTML for pre-warming
            let warmupHTML = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <script src="https://unpkg.com/lightweight-charts/dist/lightweight-charts.standalone.production.js"></script>
                </head>
                <body>
                    <div id="chart" style="width: 100%; height: 100vh;"></div>
                    <script>
                        // Pre-warm JavaScript engine and chart library
                        console.log('WebView and chart library pre-warmed');
                        const chart = LightweightCharts.createChart(document.getElementById('chart'));
                    </script>
                </body>
                </html>
                """

            webView.loadHTMLString(warmupHTML, baseURL: nil)
            print("🔥 Pre-warmed WebView with chart library")
        }

        return webView
    }

    func getWebView() -> WKWebView {
        if Thread.isMainThread {
            return queue.sync {
                if let webView = availableWebViews.popLast() {
                    inUseWebViews.insert(webView)
                    print("🎯 Retrieved WebView from pool (\(availableWebViews.count) remaining)")
                    return webView
                } else {
                    print("⚠️ Pool empty, creating new WebView")
                    let webView = createPreConfiguredWebView()
                    inUseWebViews.insert(webView)
                    return webView
                }
            }
        } else {
            return DispatchQueue.main.sync {
                return self.getWebView()
            }
        }
    }

    func returnWebView(_ webView: WKWebView) {
        // WebView operations must happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Reset the WebView for reuse on main thread
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.configuration.userContentController.removeAllUserScripts()

            // Remove all message handlers
            let messageHandlers = ["log", "error", "chartReady", "dataRequest", "timeframeChanged"]
            for handler in messageHandlers {
                webView.configuration.userContentController.removeScriptMessageHandler(
                    forName: handler)
            }

            // Update pool state on background queue
            self.queue.async {
                self.inUseWebViews.remove(webView)

                if self.availableWebViews.count < self.poolSize {
                    self.availableWebViews.append(webView)
                    print("🔄 WebView returned to pool (\(self.availableWebViews.count) available)")
                } else {
                    print("🗑️ Pool full, discarding WebView")
                }
            }
        }
    }

    func warmUpPool() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.queue.async {
                let currentCount = self.availableWebViews.count
                let neededCount = self.poolSize - currentCount

                if neededCount > 0 {
                    DispatchQueue.main.async {
                        for _ in 0..<neededCount {
                            let webView = self.createPreConfiguredWebView()
                            self.queue.async {
                                self.availableWebViews.append(webView)
                            }
                        }
                        print("🔥 WebView pool warmed up (added \(neededCount) WebViews)")
                    }
                }
            }
        }
    }
}
