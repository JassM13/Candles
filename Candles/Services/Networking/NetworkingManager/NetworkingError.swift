//
//  NetworkingError.swift
//  PlayGround
//
//  Created by Jaspreet Malak on 4/11/24.
//

import Foundation

enum NetworkError: Error {
    // Common errors
    case connectionFailed(Error)
    case invalidURL
    case invalidResponse
    case invalidRequest
    case requestTimedOut
    case serverUnavailable
    case unknownError
    
    // HTTP-specific errors
    case serverError(Error, Int? = nil)
    case decodingError(Error)
    case authorizationError(Error)
    case unsupportedHTTPMethod
    case unexpectedDataResponse(Data)
    
    // WebSocket-specific errors
    case webSocketConnectionFailed
    case webSocketDataError
    case webSocketStringConversionFailed
    case webSocketUnknownMessageType
    case webSocketCancelled
    case webSocketNoActiveTask
    case webSocketNoOriginalRequest
    case webSocketNotConnected
}

extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        // Common errors
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from the server"
        case .invalidRequest:
            return "Invalid request"
        case .requestTimedOut:
            return "Request timed out"
        case .serverUnavailable:
            return "Server is currently unavailable"
        case .unknownError:
            return "An unknown error occurred"
        
        // HTTP-specific errors
        case .serverError(let error, let int):
            return error.localizedDescription
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .authorizationError(let error):
            return "Authorization error: \(error.localizedDescription)"
        case .unsupportedHTTPMethod:
            return "Unsupported HTTP method"
        case .unexpectedDataResponse(let data):
            return "Unexpected data response: \(data)"
        
        // WebSocket-specific errors
        case .webSocketConnectionFailed:
            return "WebSocket connection failed"
        case .webSocketDataError:
            return "WebSocket data error"
        case .webSocketStringConversionFailed:
            return "WebSocket string conversion failed"
        case .webSocketUnknownMessageType:
            return "Unknown WebSocket message type"
        case .webSocketCancelled:
            return "WebSocket connection cancelled"
        case .webSocketNoActiveTask:
            return "No active WebSocket task"
        case .webSocketNoOriginalRequest:
            return "No original WebSocket request found"
        case .webSocketNotConnected:
            return "WebSocket is not connected"
        }
    }
}
