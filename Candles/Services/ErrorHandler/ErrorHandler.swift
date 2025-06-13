//
//  ErrorHandler.swift
//  PlayGround
//
//  Created by Jaspreet Malak on 6/14/24.
//

import Foundation
import Combine

class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    @Published private(set) var latestError: Error?

    private init() {}

    func storeError(_ error: Error) {
        DispatchQueue.main.async {
            self.latestError = error
        }
    }

    func clearError() {
        DispatchQueue.main.async {
            self.latestError = nil
        }
    }
}