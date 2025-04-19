import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int, response: String?)
    case noData
    case decodingError(Error)
    case notAuthenticated
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server endpoint URL is invalid."
        case .requestFailed(let statusCode, let response):
            return "The network request failed with status code \(statusCode). Response: \(response ?? "N/A")"
        case .noData:
            return "No data was received from the server."
        case .decodingError(let error):
            return "Failed to decode the server response: \(error.localizedDescription)"
        case .notAuthenticated:
            return "User is not authenticated. Cannot make authorized request."
        case .unknown(let error):
            return "An unknown API error occurred: \(error.localizedDescription)"
        }
    }
}
