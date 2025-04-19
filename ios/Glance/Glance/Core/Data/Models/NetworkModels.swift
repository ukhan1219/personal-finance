import Foundation

// MARK: - API Response Models

/// Response from the backend endpoint checking if the user has connected a bank account.
struct UserStatusResponse: Codable {
    let hasConnectedBankAccount: Bool
}

/// Response from the backend endpoint providing a Plaid Link token.
struct LinkTokenResponse: Codable {
    let linkToken: String
    // Add other fields if your backend returns them (e.g., expiration)
}

// MARK: - API Request Models
// (Add request body structs here if needed for POST/PUT)

/// Request body for exchanging a Plaid public token for an access token.
struct ExchangeTokenRequest: Codable {
   let publicToken: String
}

// MARK: - Shared Domain Models (Matching Backend)

/// Represents the user's spending summary for different periods.
/// Matches the backend's `domain.SpendingSummary` struct.
struct SpendingSummary: Codable {
	let today: Double
	let week: Double
	let month: Double
}

// Add other response/request structs as needed
// struct SpendingSummaryResponse: Codable { ... } 