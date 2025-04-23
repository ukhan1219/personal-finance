import Foundation
import Security

// Simple Keychain helper for saving/loading/deleting Data
struct KeychainHelper {

    // Define unique identifiers for the Keychain item
    // Use the app's bundle ID or a specific domain for service
    private static let service = Bundle.main.bundleIdentifier ?? "com.glanceFinance.Glance"
    // Use a specific key for the cached spending data
    private static let spendingSummaryAccount = "cachedSpendingSummaryData"
    private static let spendingTimestampAccount = "cachedSpendingTimestamp" // Also store timestamp securely

    // MARK: - Save Data

    static func saveData(_ data: Data, forKey account: String) -> Bool {
        let query = createBaseQuery(account: account)

        // Check if item already exists
        let status = SecItemCopyMatching(query as CFDictionary, nil)

        var attributesToSave: [String: Any] = [
            kSecValueData as String: data,
            // Ensure accessibility allows reading when unlocked
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        if status == errSecSuccess {
            // Item exists, update it
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToSave as CFDictionary)
            if updateStatus != errSecSuccess {
                print("KeychainHelper: Error updating item for account \(account). Status: \(updateStatus)")
                return false
            }
            print("KeychainHelper: Successfully updated item for account \(account).")
            return true
        } else if status == errSecItemNotFound {
            // Item does not exist, add it
            // Add service and account to the attributes only when adding
            attributesToSave[kSecClass as String] = kSecClassGenericPassword
            attributesToSave[kSecAttrService as String] = service
            attributesToSave[kSecAttrAccount as String] = account

            let addStatus = SecItemAdd(attributesToSave as CFDictionary, nil)
            if addStatus != errSecSuccess {
                print("KeychainHelper: Error adding item for account \(account). Status: \(addStatus)")
                return false
            }
            print("KeychainHelper: Successfully added item for account \(account).")
            return true
        } else {
            // Another error occurred during lookup
            print("KeychainHelper: Error checking for item \(account). Status: \(status)")
            return false
        }
    }

    // MARK: - Load Data

    static func loadData(forKey account: String) -> Data? {
        var query = createBaseQuery(account: account)
        // Add attributes to retrieve
        query[kSecMatchLimit as String] = kSecMatchLimitOne // We only want one item
        query[kSecReturnData as String] = kCFBooleanTrue // We want the data back

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound { // Don't log if simply not found
                 print("KeychainHelper: Error loading item for account \(account). Status: \(status)")
            }
            return nil
        }

        guard let data = item as? Data else {
             print("KeychainHelper: Loaded item for account \(account) is not Data.")
            return nil
        }
        print("KeychainHelper: Successfully loaded data for account \(account).")
        return data
    }

    // MARK: - Delete Data

    static func deleteData(forKey account: String) -> Bool {
        let query = createBaseQuery(account: account)
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            print("KeychainHelper: Error deleting item for account \(account). Status: \(status)")
            return false
        }
        if status == errSecSuccess {
             print("KeychainHelper: Successfully deleted item for account \(account).")
        } else {
             print("KeychainHelper: Item for account \(account) not found, nothing to delete.")
        }
        return true
    }

    // MARK: - Helper Methods

    // Creates the base query dictionary identifying the item
    private static func createBaseQuery(account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword, // Store as generic password
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    // MARK: - Specific Helpers for Spending Cache

    static func saveSpendingSummary(_ summary: SpendingSummary) -> Bool {
         do {
             let encoder = JSONEncoder()
             let data = try encoder.encode(summary)
             let timestampData = try JSONEncoder().encode(Date()) // Encode current date

             let dataSaved = saveData(data, forKey: spendingSummaryAccount)
             let timestampSaved = saveData(timestampData, forKey: spendingTimestampAccount)

             return dataSaved && timestampSaved
         } catch {
             print("KeychainHelper: Failed to encode spending summary or timestamp for caching: \(error)")
             return false
         }
     }

     static func loadSpendingSummary() -> (summary: SpendingSummary?, timestamp: Date?) {
         guard let savedData = loadData(forKey: spendingSummaryAccount),
               let timestampData = loadData(forKey: spendingTimestampAccount) else {
             return (nil, nil)
         }

         do {
             let decoder = JSONDecoder()
             let cachedSummary = try decoder.decode(SpendingSummary.self, from: savedData)
             let cachedTimestamp = try decoder.decode(Date.self, from: timestampData)
             return (cachedSummary, cachedTimestamp)
         } catch {
             print("KeychainHelper: Failed to decode cached spending data or timestamp: \(error). Clearing potentially corrupt cache.")
             // Clear potentially corrupt data - explicitly ignore return value
             _ = clearSpendingCache()
             return (nil, nil)
         }
     }

     static func clearSpendingCache() -> Bool {
         let dataDeleted = deleteData(forKey: spendingSummaryAccount)
         let timestampDeleted = deleteData(forKey: spendingTimestampAccount)
         return dataDeleted && timestampDeleted
     }
}
