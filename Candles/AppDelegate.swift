//
//  AppDelegate.swift
//  Candles
//
//  Created by AI Assistant
//

import UIKit
import WebKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Initialize WebView pool as early as possible to eliminate first-load lag
        DispatchQueue.global(qos: .userInitiated).async {
            _ = WebViewPool.shared
            print("🚀 WebView pool initialized in AppDelegate")
        }

        // Pre-warm WebKit process
        DispatchQueue.main.async {
            WebViewPool.shared.warmUpPool()
        }

        return true
    }

    private func preWarmWebKit() {
        // Create a temporary WebView to pre-warm the WebKit process
        let tempWebView = WKWebView(frame: .zero)
        tempWebView.loadHTMLString("<html><body>Warming up WebKit...</body></html>", baseURL: nil)

        // Remove the temporary WebView after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            tempWebView.removeFromSuperview()
        }
    }
}
