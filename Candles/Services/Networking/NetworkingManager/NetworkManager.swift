//
//  NetworkManager.swift
//  PlayGround
//
//  Created by Jaspreet Malak on 7/22/24.
//

import Network
import Foundation
import Combine

class NetworkManager: ObservableObject {
    private let requestBuilder = RequestBuilder()
    private let requestExecutor = RequestExecutor()
    static let shared = NetworkManager()
    
    private let monitor: NWPathMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published private(set) var isConnected: Bool = true
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}
