import Foundation
import Combine

class SpendingViewModel: ObservableObject {

    // MARK: - Dependencies
    private let apiService: APIService

    // MARK: - Published State Properties
    @Published var spendingSummary: SpendingSummary? = nil
    @Published var errorMessage: String?

    // MARK: - Cache Properties
    private let cacheDuration: TimeInterval = 300 // Cache for 1 hour (in seconds)

    // MARK: - Initializer
    init(apiService: APIService) {
        self.apiService = apiService
        print("SpendingViewModel: Initialized")
        // --- Load initial data from cache upon initialization ---
        loadFromCache()
    }

    // MARK: - Data Loading and Caching

    /// Checks if the cached spending data is stale and triggers a network fetch if needed.
    /// Should be called when the app becomes active and is unlocked.
    func refreshSpendingDataIfNeeded() {
        print("SpendingViewModel: refreshSpendingDataIfNeeded called.")

        // Load timestamp directly from Keychain helper
        let (_, cachedTimestamp) = KeychainHelper.loadSpendingSummary()

        // Check if cache is stale or missing, then trigger network fetch
        if let timestamp = cachedTimestamp {
            let age = Date().timeIntervalSince(timestamp)
            print("SpendingViewModel: Cache age: \(age) seconds.")
            if age > cacheDuration {
                print("SpendingViewModel: Cache is stale (older than \(cacheDuration)s). Fetching from network.")
                fetchSpendingDataFromServer()
            } else {
                print("SpendingViewModel: Cache is fresh. Background fetch not required.")
                // Optionally: If you *always* want a background refresh uncomment below
                // fetchSpendingDataFromServer()
            }
        } else {
            print("SpendingViewModel: No cache timestamp found in Keychain. Fetching from network.")
            fetchSpendingDataFromServer() // Fetch if no timestamp exists
        }
    }

    /// Attempts to load and decode spending data from Keychain.
    private func loadFromCache() {
        let (cachedSummary, timestamp) = KeychainHelper.loadSpendingSummary()

        if let summary = cachedSummary, let ts = timestamp {
            // Update published property ONLY if it's different or nil to avoid unnecessary UI refreshes
            if self.spendingSummary == nil || self.spendingSummary != summary {
                 self.spendingSummary = summary
                 print("SpendingViewModel: Successfully loaded data from Keychain cache (Timestamp: \(ts)).")
             } else {
                 print("SpendingViewModel: Keychain cache data matches current state. Not updating UI from cache.")
             }
        } else {
             print("SpendingViewModel: No spending data found in Keychain cache.")
        }
    }

    /// Fetches spending data from the backend API.
    private func fetchSpendingDataFromServer() {
        print("SpendingViewModel: Starting network fetch...")
        errorMessage = nil

        apiService.fetchSpendingData { [weak self] result in
            DispatchQueue.main.async { // Ensure UI updates on main thread
                guard let self = self else { return }

                switch result {
                case .success(let summary):
                    print("SpendingViewModel: Successfully fetched data from network.")
                    // Update UI only if data changed
                    if self.spendingSummary != summary {
                        self.spendingSummary = summary
                    }
                    // Save to Keychain regardless of change to update timestamp
                    self.saveToCache(summary: summary)

                case .failure(let error):
                    print("SpendingViewModel: Error fetching spending data: \(error.localizedDescription)")
                    // Keep stale data if available, otherwise show error
                    if self.spendingSummary == nil {
                         self.errorMessage = "Could not load spending data. \(error.localizedDescription)"
                    } else {
                         // Optionally show a non-blocking error indicating refresh failed
                         self.errorMessage = "Failed to refresh spending data. Showing last known values."
                         // You might want a different state for this (e.g., a small error icon)
                    }
                }
            }
        }
    }

    /// Saves the fetched spending data and current timestamp to Keychain.
    private func saveToCache(summary: SpendingSummary) {
         if KeychainHelper.saveSpendingSummary(summary) {
             print("SpendingViewModel: Successfully saved data to Keychain cache.")
         } else {
             print("SpendingViewModel: Failed to save spending data to Keychain cache.")
             // Consider reporting this failure
         }
    }

    /// Removes spending data cache from Keychain.
    func clearCache() {
        _ = KeychainHelper.clearSpendingCache() // Explicitly ignore result
        print("SpendingViewModel: Attempted to clear spending data Keychain cache.") // Keep a log
    }
}

// Extension to allow comparison of SpendingSummary for cache update logic
// (Optional but helpful)
extension SpendingSummary: Equatable {
    static func == (lhs: SpendingSummary, rhs: SpendingSummary) -> Bool {
        return lhs.today == rhs.today &&
               lhs.week == rhs.week &&
               lhs.month == rhs.month
    }
}
