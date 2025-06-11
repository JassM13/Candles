//
//  NetworkManager.swift
//  Candles
//
//  Created by Trae AI on DATE_STAMP.
//

import Foundation

// MARK: - API Configuration

struct APIConstants {
    static let baseURL = "https://gateway-api-demo.s2f.projectx.com/api"
    static let searchContractEndpoint = "/Contract/search"
}

// MARK: - Request Structures

struct SearchRequestBody: Codable {
    let symbol: String
    // Add other parameters if required by the API, e.g., exchange, type
    // let exchange: String?
    // let type: String?
}

// MARK: - Response Structures (Define based on actual API response)

// Placeholder for the actual response structure.
// You'll need to define this based on the JSON returned by the API.
struct SearchResult: Codable, Identifiable {
    let id = UUID()  // Or use an actual ID from the API response
    let symbol: String
    let name: String
    // Add other relevant fields from the API response
}

struct SearchResponse: Codable {
    let results: [SearchResult]
    // Or whatever the top-level structure of the API response is
}

// MARK: - Network Error Enum

enum NetworkError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingError(Error)
    case noData
}

// MARK: - Network Manager

class NetworkManager {

    static let shared = NetworkManager()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0  // 30 seconds
        config.timeoutIntervalForResource = 60.0  // 1 minute
        self.session = URLSession(configuration: config)
    }

    func searchSymbols(
        searchTerm: String, completion: @escaping (Result<[SearchResult], NetworkError>) -> Void
    ) {
        guard let url = URL(string: APIConstants.baseURL + APIConstants.searchContractEndpoint)
        else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Add any necessary authentication headers here if required by the API
        // request.setValue("Bearer YOUR_API_KEY", forHTTPHeaderField: "Authorization")

        let requestBody = SearchRequestBody(symbol: searchTerm)

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(.decodingError(error)))  // Technically an encoding error here
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
                completion(.failure(.invalidResponse))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                // Assuming the API returns an array of SearchResult directly or nested in a SearchResponse struct
                // Adjust this based on the actual API response format
                // Option 1: If API returns [SearchResult]
                let decodedResponse = try JSONDecoder().decode([SearchResult].self, from: data)
                completion(.success(decodedResponse))

                // Option 2: If API returns SearchResponse { results: [SearchResult] }
                // let decodedResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
                // completion(.success(decodedResponse.results))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }

        task.resume()
    }
}
