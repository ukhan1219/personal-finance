import Foundation

class APIService {
    // TODO: Replace with your actual deployed backend URL or load from config
    // Temporarily pointing to local backend for testing
    private let baseURL = "http://localhost:8080/api/v1" // Using v1 base path

    // Use dependency injection to get the AuthViewModel for fetching the token
    private weak var authViewModel: AuthViewModel?

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }

    // MARK: - User Status

    func fetchUserStatus(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/me/status") else {
            completion(.failure(APIError.invalidURL))
            return
        }

        // Fetch the ID Token asynchronously
        authViewModel?.getIDToken { idToken in
            guard let idToken = idToken else {
                completion(.failure(APIError.notAuthenticated))
                return
            }

            // Construct the request after getting the token
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept") // Expect JSON response

            print("APIService: Fetching user status...")

            // Perform the data task
            URLSession.shared.dataTask(with: request) { data, response, error in
                // Handle network error
                if let error = error {
                    print("APIService: Network error fetching status - \(error.localizedDescription)")
                    completion(.failure(APIError.unknown(error)))
                    return
                }

                // Check HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("APIService: Invalid response received.")
                    completion(.failure(APIError.requestFailed(statusCode: 0, response: "Invalid response type")))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    var responseString: String?
                    if let data = data {
                        responseString = String(data: data, encoding: .utf8)
                    }
                    print("APIService: Status request failed with status code \(httpResponse.statusCode). Response: \(responseString ?? "N/A")")
                    completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode, response: responseString)))
                    return
                }

                // Check for data
                guard let data = data else {
                    print("APIService: No data received for status.")
                    completion(.failure(APIError.noData))
                    return
                }

                // Decode the response
                do {
                    let decodedResponse = try JSONDecoder().decode(UserStatusResponse.self, from: data)
                    print("APIService: Successfully fetched status - hasConnectedBankAccount: \(decodedResponse.hasConnectedBankAccount)")
                    completion(.success(decodedResponse.hasConnectedBankAccount))
                } catch let decodingError {
                    print("APIService: Error decoding status response - \(decodingError)")
                    completion(.failure(APIError.decodingError(decodingError)))
                }
            }.resume() // Don't forget to start the task!
        }
    }

    // --- Plaid Functions ---

    /// Fetches a Plaid Link token from the backend.
    func createLinkToken(completion: @escaping (Result<String, APIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/plaid/create_link_token") else {
            completion(.failure(.invalidURL))
            return
        }

        // Fetch the ID Token asynchronously
        authViewModel?.getIDToken { idToken in
            guard let idToken = idToken else {
                completion(.failure(.notAuthenticated))
                return
            }

            // Construct the request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            // No body needed for this request

            print("APIService: Creating Plaid Link token...")

            URLSession.shared.dataTask(with: request) { data, response, error in
                // Handle network error
                if let error = error {
                    print("APIService: Network error creating link token - \(error.localizedDescription)")
                    completion(.failure(.unknown(error)))
                    return
                }

                // Check HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("APIService: Invalid response received for link token.")
                    completion(.failure(.requestFailed(statusCode: 0, response: "Invalid response type")))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    var responseString: String?
                    if let data = data { responseString = String(data: data, encoding: .utf8) }
                    print("APIService: Link token request failed with status code \(httpResponse.statusCode). Response: \(responseString ?? "N/A")")
                    completion(.failure(.requestFailed(statusCode: httpResponse.statusCode, response: responseString)))
                    return
                }

                // Check for data
                guard let data = data else {
                    print("APIService: No data received for link token.")
                    completion(.failure(.noData))
                    return
                }

                // Decode the response
                do {
                    // Use custom decoder if needed for snake_case
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase // Handle link_token key
                    let decodedResponse = try decoder.decode(LinkTokenResponse.self, from: data)
                    print("APIService: Successfully created link token.")
                    completion(.success(decodedResponse.linkToken))
                } catch let decodingError {
                    print("APIService: Error decoding link token response - \(decodingError)")
                    completion(.failure(.decodingError(decodingError)))
                }
            }.resume()
        }
    }

    /// Exchanges a Plaid public token for an access token via the backend.
    func exchangePublicToken(publicToken: String, completion: @escaping (Result<Void, APIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/plaid/exchange_public_token") else {
            completion(.failure(.invalidURL))
            return
        }

        authViewModel?.getIDToken { idToken in
            guard let idToken = idToken else {
                completion(.failure(.notAuthenticated))
                return
            }

            // Construct request body
            let requestBody = ExchangeTokenRequest(publicToken: publicToken)
            // --- Create and configure the encoder ---
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase // Convert camelCase to snake_case
            // --- Encode using the configured encoder ---
            guard let encodedBody = try? encoder.encode(requestBody) else {
                print("APIService: Failed to encode public token request body")
                completion(.failure(.unknown(NSError(domain: "APIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request body"]))))
                return
            }

            // Construct the request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = encodedBody

            print("APIService: Exchanging public token...")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("APIService: Network error exchanging token - \(error.localizedDescription)")
                    completion(.failure(.unknown(error)))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("APIService: Invalid response received for token exchange.")
                    completion(.failure(.requestFailed(statusCode: 0, response: "Invalid response type")))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    var responseString: String?
                    if let data = data { responseString = String(data: data, encoding: .utf8) }
                    print("APIService: Token exchange request failed with status code \(httpResponse.statusCode). Response: \(responseString ?? "N/A")")
                    completion(.failure(.requestFailed(statusCode: httpResponse.statusCode, response: responseString)))
                    return
                }

                // Success (2xx response), no specific data needed
                print("APIService: Successfully exchanged public token.")
                completion(.success(()))

            }.resume()
        }
    }

    // --- Spending Data ---

    /// Fetches the spending summary from the backend.
    func fetchSpendingData(completion: @escaping (Result<SpendingSummary, APIError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/plaid/spending") else {
            completion(.failure(.invalidURL))
            return
        }

        authViewModel?.getIDToken { idToken in
            guard let idToken = idToken else {
                completion(.failure(.notAuthenticated))
                return
            }

            // Construct the request
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            print("APIService: Fetching spending data...")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("APIService: Network error fetching spending data - \(error.localizedDescription)")
                    completion(.failure(.unknown(error)))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("APIService: Invalid response received for spending data.")
                    completion(.failure(.requestFailed(statusCode: 0, response: "Invalid response type")))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    var responseString: String?
                    if let data = data { responseString = String(data: data, encoding: .utf8) }
                    print("APIService: Spending data request failed with status code \(httpResponse.statusCode). Response: \(responseString ?? "N/A")")
                    completion(.failure(.requestFailed(statusCode: httpResponse.statusCode, response: responseString)))
                    return
                }

                guard let data = data else {
                    print("APIService: No data received for spending data.")
                    completion(.failure(.noData))
                    return
                }

                // Decode the response
                do {
                    let decodedResponse = try JSONDecoder().decode(SpendingSummary.self, from: data)
                    print("APIService: Successfully fetched spending data.")
                    completion(.success(decodedResponse))
                } catch let decodingError {
                    print("APIService: Error decoding spending data response - \(decodingError)")
                    completion(.failure(.decodingError(decodingError)))
                }
            }.resume()
        }
    }

    // --- Add other API functions below ---
    // func createLinkToken(...)
    // func exchangePublicToken(...)
    // func fetchSpendingData(...)

}
