//
//  AuthenticationRoutes.swift
//  PlayGround
//
//  Created by Jaspreet Malak on 4/24/24.
//

import Foundation

enum Broker: String, CaseIterable, Codable {
    case alphaticks = "alphaticks"
    case blueguardian = "blueguardianfutures"
    case topstepx = "topstepx"
    case fxifyfutures = "fxifyfutures"

    var baseURLString: String {
        switch self {
        case .alphaticks:
            return "https://api.alphaticks.projectx.com"
        case .blueguardian:
            return "https://api.blueguardianfutures.projectx.com"
        case .topstepx:
            return "https://api.topstepx.com"
        case .fxifyfutures:
            return "https://api.fxifyfutures.projectx.com"
        }
    }

    var loginPath: String {
        return "/api/Auth/loginKey"
    }
}

struct AuthRequest: Codable {
    let userName: String
    let apiKey: String
}




struct AuthResponse: Codable {
    let token: String?
    let success: Bool
    let errorCode: Int
    let errorMessage: String?
}

class AuthenticationRoutes {
    func signIn(userName: String, apiKey: String, broker: Broker) async throws -> AuthResponse? {
        print("[AuthenticationRoutes] Attempting to sign in user: \(userName) for broker: \(broker.rawValue)")
        print("[AuthenticationRoutes] Base URL: \(broker.baseURLString), Path: \(broker.loginPath)")
        guard let url = URL(string: broker.baseURLString)?.appendingPathComponent(broker.loginPath) else {
            // Handle invalid URL error, perhaps throw a custom error
            print("Invalid URL for broker: \(broker.rawValue)")
            return nil // Or throw an error
        }
        print("[AuthenticationRoutes] Constructed URL: \(url.absoluteString)")

        let authCredentials = AuthRequest(userName: userName, apiKey: apiKey)
        // let authRequestBody = LoginApiKeyRequestPayload(request: authCredentials) // No longer wrapping
        
        print("[AuthenticationRoutes] Auth Request Body: \(authCredentials)")
        guard let httpBody = try? JSONEncoder().encode(authCredentials) else {
            print("Failed to encode request body")
            return nil // Or throw an error
        }

        let requestBuilder = RequestBuilder()
        let request = await requestBuilder
            .with(url: url)
            .with(httpMethod: .post)
            .with(headers: ["accept": "application/json", "User-Agent": "CandlesApp/1.0", "Content-Type": "application/json"]) // Explicitly set Content-Type here
            .with(bodyData: httpBody) // Use the new method for pre-encoded Data
            .build()
        print("[AuthenticationRoutes] Built Request: \(String(describing: request))")
        
        guard let builtRequest = request else {
            print("Failed to build request")
            return nil // Or throw an error
        }

        do {
            print("[AuthenticationRoutes] Executing request...")
            let data = try await RequestExecutor().execute(builtRequest)
            print("[AuthenticationRoutes] Received data: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
            let decoder = JSONDecoder()
            let response = try decoder.decode(AuthResponse.self, from: data)
            print("[AuthenticationRoutes] Decoded response: \(response)")
            return response
        } catch let networkError as NetworkError {
            // Handle specific NetworkErrors
            print("[AuthenticationRoutes] Sign in failed with NetworkError: \(networkError)")
            // Depending on the error, you might want to set a specific user-facing message
            // For now, just rethrow or wrap it if necessary
            throw networkError // Or a custom domain-specific error
        } catch {
            // Handle other errors (e.g., decoding errors from AuthResponse)
            print("[AuthenticationRoutes] Sign in failed with error: \(error)")
            throw error
        }
    }
}

 
