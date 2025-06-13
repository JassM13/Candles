//
//  RequestExecutor.swift
//  PlayGround
//
//  Created by Jaspreet Malak on 4/11/24.
//

import Foundation

class RequestExecutor {
    private let urlSession: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        // Consider making timeout configurable or longer for general requests
        configuration.timeoutIntervalForRequest = 10.0  // Increased timeout
        urlSession = URLSession(configuration: configuration)
    }

    func execute(_ request: URLRequest) async throws -> Data {
        print("[RequestExecutor] Executing request: \(request)")
        if let allHeaders = request.allHTTPHeaderFields {
            print("[RequestExecutor] Request Headers: \(allHeaders)")
        }
        if let httpBody = request.httpBody {
            print("[RequestExecutor] Request Body: \(String(data: httpBody, encoding: .utf8) ?? "Could not decode body")")
        }
        return try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.dataTask(with: request) { (data, response, error) in
                print("[RequestExecutor] Data task completion handler. URL: \(request.url?.absoluteString ?? "N/A")")
                if let error = error {
                    print("[RequestExecutor] Error received: \(error.localizedDescription)")
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .cannotConnectToHost, .networkConnectionLost, .cannotFindHost:
                            print("[RequestExecutor] URLError: Server Unavailable")
                            continuation.resume(throwing: NetworkError.serverUnavailable)
                            return
                        case .timedOut:
                            print("[RequestExecutor] URLError: Request Timed Out")
                            continuation.resume(throwing: NetworkError.requestTimedOut)
                            return
                        default:
                            print("[RequestExecutor] URLError: Connection Failed - \(urlError.localizedDescription)")
                            continuation.resume(throwing: NetworkError.connectionFailed(urlError))
                            return
                        }
                    } else {
                        // For non-URLError types, wrap it in connectionFailed
                        print("[RequestExecutor] Non-URLError: Connection Failed - \(error.localizedDescription)")
                        continuation.resume(throwing: NetworkError.connectionFailed(error))
                        return
                    }
                }

                print("[RequestExecutor] Raw response object: \(String(describing: response))")
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[RequestExecutor] Failed to cast response to HTTPURLResponse")
                    continuation.resume(throwing: NetworkError.invalidResponse)
                    return
                }

                print("[RequestExecutor] HTTP Status Code: \(httpResponse.statusCode)")
                print("[RequestExecutor] HTTP Response Headers: \(httpResponse.allHeaderFields)")
                guard (200...299).contains(httpResponse.statusCode) else {
                    let statusError = HTTPStatusError(statusCode: httpResponse.statusCode, data: data)
                    print("[RequestExecutor] Server error. Status: \(httpResponse.statusCode). Data: \(String(data: data ?? Data(), encoding: .utf8) ?? "No data or invalid data")")
                    continuation.resume(
                        throwing: NetworkError.serverError(statusError, httpResponse.statusCode)
                    )
                    return
                }

                print("[RequestExecutor] Received data (pre-guard): \(String(data: data ?? Data(), encoding: .utf8) ?? "No data or invalid data")")
                guard let data = data else {
                    // This case might be redundant if HTTP status check is done correctly
                    // and server always sends data with error statuses.
                    print("[RequestExecutor] No data received, but status was 2xx (or guard was bypassed). This shouldn't happen if status check is correct.")
                    continuation.resume(throwing: NetworkError.invalidResponse)  // Or a more specific error like .noData
                    return
                }

                // The responsibility of decoding the data is moved to the caller (e.g., AuthenticationRoutes)
                // This keeps RequestExecutor generic.
                print("[RequestExecutor] Successfully received data: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
                continuation.resume(returning: data)
            }
            task.resume()
        }
    }
}

struct HTTPStatusError: Error, LocalizedError {
    let statusCode: Int
    let data: Data?

    var errorDescription: String? {
        var message = "Server error with status code: \(statusCode)."
        if let data = data, let dataString = String(data: data, encoding: .utf8) {
            message += " Response: \(dataString)"
        }
        return message
    }
}
