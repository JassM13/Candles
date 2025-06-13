//
//  RequestBuilder.swift
//  PlayGround
//
//  Created by Jaspreet Malak on 4/11/24.
//

import Foundation

enum RequestType {
    case http
    case webSocket
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

class RequestBuilder {
    private var url: URL?
    private var requestType: RequestType = .http
    private var httpMethod: HTTPMethod = .get
    private var headers: [String: String] = [:]
    private var body: Encodable?
    private var bodyData: Data? // New property for pre-encoded Data
    private var queryParameters: [String: Any] = [:]
    private var cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    private var webSocketProtocols: [String] = []
    
    func with(url: URL) -> RequestBuilder {
        print("[RequestBuilder] Setting URL: \(url.absoluteString)")
        self.url = url
        return self
    }
    
    func with(requestType: RequestType) -> RequestBuilder {
        self.requestType = requestType
        return self
    }
    
    func with(httpMethod: HTTPMethod) -> RequestBuilder {
        print("[RequestBuilder] Setting HTTP Method: \(httpMethod.rawValue)")
        self.httpMethod = httpMethod
        return self
    }
    
    func with(headers: [String: String]) -> RequestBuilder {
        print("[RequestBuilder] Adding headers: \(headers)")
        self.headers.merge(headers, uniquingKeysWith: { (_, new) in new })
        return self
    }
    
    func with(body: Encodable?) -> RequestBuilder {
        print("[RequestBuilder] Setting body: \(String(describing: body))")
        self.body = body
        self.bodyData = nil // Ensure only one body type is used
        return self
    }
    
    func with(bodyData: Data?) -> RequestBuilder {
        print("[RequestBuilder] Setting bodyData: \(String(describing: bodyData?.count)) bytes")
        self.bodyData = bodyData
        self.body = nil // Ensure only one body type is used
        return self
    }
    
    func with(queryParameters: [String: Any]) -> RequestBuilder {
        self.queryParameters = queryParameters
        return self
    }
    
    func with(cachePolicy: URLRequest.CachePolicy) -> RequestBuilder {
        self.cachePolicy = cachePolicy
        return self
    }
    
    func with(webSocketProtocols: [String]) -> RequestBuilder {
        self.webSocketProtocols = webSocketProtocols
        return self
    }
    
    func build() -> URLRequest? {
        print("[RequestBuilder] Building request...")
        guard let url = url else {
            fatalError("URL must be set")
        }

        var urlString = url.absoluteString
        if !queryParameters.isEmpty {
            let queryItems = queryParameters.compactMap { key, value in
                let escaped = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "\(key)=\(escaped)"
            }
            urlString += "?\(queryItems.joined(separator: "&"))"
        }

        guard let finalURL = URL(string: urlString) else {
            fatalError("Failed to build URL with query parameters")
        }
        
        var request = URLRequest(url: finalURL)
        print("[RequestBuilder] Initialized URLRequest with URL: \(finalURL.absoluteString)")
        
        if requestType == .http {
            request.httpMethod = httpMethod.rawValue
            print("[RequestBuilder] Set HTTP method on request: \(httpMethod.rawValue)")
            
            if let bodyData = bodyData {
                request.httpBody = bodyData
                print("[RequestBuilder] Set bodyData on request. Body data size: \(bodyData.count) bytes")
                // Assuming Content-Type is set by the caller or in headers if using pre-encoded data
                // If this bodyData is always JSON, we can set it here:
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            } else if let body = body {
                let encodedBody = try? JSONEncoder().encode(body)
                request.httpBody = encodedBody
                print("[RequestBuilder] Set body on request. Encoded body: \(String(data: encodedBody ?? Data(), encoding: .utf8) ?? "Invalid body data")")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            request.cachePolicy = cachePolicy
        } else {
            if !webSocketProtocols.isEmpty {
                request.setValue(webSocketProtocols.joined(separator: ","), forHTTPHeaderField: "Sec-WebSocket-Protocol")
            }
        }
        
        print("[RequestBuilder] Final headers for request: \(headers)")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        print("[RequestBuilder] Final built request: \(request)")
        print("[RequestBuilder] All HTTP header fields: \(String(describing: request.allHTTPHeaderFields))")
        if let httpBody = request.httpBody {
            print("[RequestBuilder] HTTP Body: \(String(data: httpBody, encoding: .utf8) ?? "Could not decode body")")
        }
        return request
    }
    
    func perform(completion: @escaping (Result<Data, Error>) -> Void) {
        guard let request = build() else {
            completion(.failure(NetworkError.invalidRequest))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else if let data = data {
                    completion(.success(data))
                } else {
                    completion(.failure(NetworkError.unknownError))
                }
            }
        }
        task.resume()
    }
}
