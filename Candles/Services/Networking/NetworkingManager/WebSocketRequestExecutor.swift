//
//  WebSocketExecutor.swift
//  PlayGround
//
//  Created by Jaspreet Malak on 5/14/24.
//

import Foundation
import Combine
#if os(iOS)
import UIKit
#endif

class WebSocketRequestExecutor {
    private let urlSession: URLSession
    public var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false {
        didSet {
            print("WebSocket connection state changed to: \(isConnected)")
        }
    }
    private var cancellables = Set<AnyCancellable>()
    private var appStateObserver: AnyCancellable?
    private var currentContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    private let reconnectDelay: TimeInterval = 3.0
    private var request: URLRequest?
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        urlSession = URLSession(configuration: configuration)
        
#if os(iOS)
        setupAppStateObserver()
#endif
        
        setupNetworkObserver()
    }
    
    private func setupNetworkObserver() {
        NetworkManager.shared.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.reconnectIfNeeded()
                } else {
                    self?.isConnected = false
                }
            }
            .store(in: &cancellables)
    }
    
    func connect(_ request: URLRequest) -> AsyncThrowingStream<Data, Error> {
        self.request = request
        return AsyncThrowingStream { continuation in
            self.currentContinuation = continuation
            self.connectWebSocket(request)
        }
    }
    
    private func connectWebSocket(_ request: URLRequest) {
        self.webSocketTask?.cancel(with: .goingAway, reason: "Reconnecting".data(using: .utf8))
        
        let webSocketTask = urlSession.webSocketTask(with: request)
        self.webSocketTask = webSocketTask
        
        webSocketTask.receive { [weak self] result in
            guard let self = self else { return }
            self.handleReceive(result)
        }
        webSocketTask.resume()
        self.isConnected = true
    }
    
#if os(iOS)
    private func setupAppStateObserver() {
        appStateObserver = NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.reconnectIfNeeded()
            }
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
#endif
    
    @objc private func applicationDidEnterBackground() {
        isConnected = false
        webSocketTask?.cancel(with: .goingAway, reason: "Backgrounded the App".data(using: .utf8))
    }
    
    private func reconnectIfNeeded() {
        guard !isConnected, let request = self.request else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self = self else { return }
            self.connectWebSocket(request)
        }
    }
    
    func send(_ message: String) async throws {
        guard let webSocketTask = webSocketTask, isConnected else {
            throw NetworkError.webSocketNotConnected
        }
        
        do {
            try await webSocketTask.send(.string(message))
        } catch {
            print("Error sending message: \(error)")
            ErrorHandler.shared.storeError(error)
            handleSendError(error)
            throw error
        }
    }
    
    func send(_ data: Data) async throws {
        guard let webSocketTask = webSocketTask, isConnected else {
            throw NetworkError.webSocketNotConnected
        }
        
        do {
            try await webSocketTask.send(.data(data))
        } catch {
            print("Error sending data: \(error)")
            ErrorHandler.shared.storeError(error)
            handleSendError(error)
            throw error
        }
    }
    
    private func handleReceive(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case .success(let message):
            Task {
                do {
                    try await handleMessage(message)
                } catch {
                    handleReceiveError(error)
                }
            }
        case .failure(let error):
            print("WebSocket receive error: \(error)")
            handleReceiveError(error)
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async throws {
        switch message {
        case .data(let data):
            currentContinuation?.yield(data)
        case .string(let string):
            if let data = string.data(using: .utf8) {
                print("WebSocket Data Size: \(data.count)")
                currentContinuation?.yield(data)
            } else {
                throw NetworkError.webSocketStringConversionFailed
            }
        @unknown default:
            throw NetworkError.webSocketUnknownMessageType
        }
        
        try await self.receiveNextMessage()
    }
    
    private func receiveNextMessage() async throws {
        guard let webSocketTask = self.webSocketTask, isConnected else {
            throw NetworkError.webSocketNotConnected
        }
        
        webSocketTask.receive { [weak self] result in
            guard let self = self else { return }
            self.handleReceive(result)
        }
    }
    
    private func handleSendError(_ error: Error) {
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            isConnected = false
            retryConnection()
        }
    }
    
    private func handleReceiveError(_ error: Error) {
        if error is URLError {
            isConnected = false
            retryConnection()
        } else {
            
        }
    }
    
    private func retryConnection() {
        guard let request = self.request else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self = self else { return }
            self.connectWebSocket(request)
        }
    }
}
