import Foundation
import Combine

class SpendingViewModel: ObservableObject {

    // MARK: - Dependencies
    private let apiService: APIService

    // MARK: - Published State Properties
    @Published var spendingSummary: SpendingSummary? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Cache Properties
    private let userDefaults = UserDefaults.standard
    private let cachedSpendingDataKey = "cachedSpendingData"
    private let cachedSpendingTimestampKey = "cachedSpendingTimestamp"
    private let cacheDuration: TimeInterval = 3600 // Cache for 1 hour (in seconds)

    // MARK: - Initializer
    init(apiService: APIService) {
        self.apiService = apiService
        print("SpendingViewModel: Initialized")
        // Initial load from cache can happen here or triggered by view's onAppear
    }

    // MARK: - Data Loading and Caching

    /// Loads spending data, prioritizing cache and then fetching from the network.
    /// Call this from the View's .onAppear.
    func loadSpendingData() {
        print("SpendingViewModel: loadSpendingData called.")
        // 1. Attempt to load from cache immediately
        loadFromCache()

        // 2. Check if cache is stale or missing, then trigger network fetch
        if let timestamp = userDefaults.object(forKey: cachedSpendingTimestampKey) as? Date {
            let age = Date().timeIntervalSince(timestamp)
            print("SpendingViewModel: Cache age: \(age) seconds.")
            if age > cacheDuration {
                print("SpendingViewModel: Cache is stale (older than \(cacheDuration)s). Fetching from network.")
                fetchSpendingDataFromServer()
            } else {
                print("SpendingViewModel: Cache is fresh. Network fetch not required immediately.")
                // Optional: Still trigger a background refresh even if cache is fresh?
                // fetchSpendingDataFromServer() // Uncomment to always refresh in background
            }
        } else {
            print("SpendingViewModel: No cache timestamp found. Fetching from network.")
            fetchSpendingDataFromServer() // Fetch if no timestamp exists
        }
    }

    /// Attempts to load and decode spending data from UserDefaults.
    private func loadFromCache() {
        if let timestamp = userDefaults.object(forKey: cachedSpendingTimestampKey) as? Date,
           let savedData = userDefaults.data(forKey: cachedSpendingDataKey) {
            do {
                let decoder = JSONDecoder()
                let cachedSummary = try decoder.decode(SpendingSummary.self, from: savedData)
                // Update published property ONLY if it's different or nil to avoid unnecessary UI refreshes
                if self.spendingSummary == nil || self.spendingSummary?.today != cachedSummary.today || self.spendingSummary?.week != cachedSummary.week || self.spendingSummary?.month != cachedSummary.month {
                    self.spendingSummary = cachedSummary
                    print("SpendingViewModel: Successfully loaded data from cache (Timestamp: \(timestamp)).")
                } else {
                    print("SpendingViewModel: Cache data matches current state. Not updating UI from cache.")
                }
            } catch {
                print("SpendingViewModel: Failed to decode cached spending data: \(error). Clearing cache.")
                clearCache()
            }
        } else {
            print("SpendingViewModel: No spending data found in cache.")
        }
    }

    /// Fetches spending data from the backend API.
    private func fetchSpendingDataFromServer() {
        guard !isLoading else { // Prevent concurrent fetches
            print("SpendingViewModel: Already fetching data.")
            return
        }

        print("SpendingViewModel: Starting network fetch...")
        isLoading = true
        errorMessage = nil

        apiService.fetchSpendingData { [weak self] result in
            DispatchQueue.main.async { // Ensure UI updates on main thread
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let summary):
                    print("SpendingViewModel: Successfully fetched data from network.")
                    self.spendingSummary = summary
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

    /// Saves the fetched spending data and current timestamp to UserDefaults.
    private func saveToCache(summary: SpendingSummary) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(summary)
            userDefaults.set(data, forKey: cachedSpendingDataKey)
            userDefaults.set(Date(), forKey: cachedSpendingTimestampKey)
            print("SpendingViewModel: Successfully saved data to cache.")
        } catch {
            print("SpendingViewModel: Failed to encode spending data for caching: \(error)")
        }
    }

    /// Removes spending data cache from UserDefaults.
    private func clearCache() {
        userDefaults.removeObject(forKey: cachedSpendingDataKey)
        userDefaults.removeObject(forKey: cachedSpendingTimestampKey)
        print("SpendingViewModel: Cleared spending data cache.")
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
