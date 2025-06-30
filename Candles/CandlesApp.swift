//
//  CandlesApp.swift
//  Candles
//
//  Created by Jaspreet Malak on 4/10/24.
//

import SwiftUI

@main
struct CandlesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
