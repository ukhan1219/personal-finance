import UIKit
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // FirebaseApp.configure() // <-- REMOVE this call
        // Add other AppDelegate setup here later if needed (e.g., push notifications)
        print("AppDelegate: didFinishLaunchingWithOptions - Firebase configured in GlanceApp init.") // Update log
        return true
    }

    // Add methods here later for handling URL schemes (Google/Apple Sign In redirects)
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Try to handle the URL for Google Sign-In
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }

        // If not handled by Google Sign-In, add checks for other URL schemes (e.g., Apple Sign In, Plaid) later if needed
        // Example: if handleAppleSignIn(url) { return true }
        // Example: if handlePlaidOAuth(url) { return true }
        return false // Indicate the URL was not handled
    }

    // Add method here later for handling Universal Links (Plaid OAuth)
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

        // Check if the activity is for browsing a web page URL
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL else {
            print("AppDelegate: Not a web browsing activity or no URL.")
            return false
        }

        print("AppDelegate: Received Universal Link: \(incomingURL.absoluteString)")

        // Check if the URL matches our Plaid OAuth redirect pattern
        // TODO: Ensure the host ("usmankhan.dev") and path ("/plaid-oauth/") are correct and match backend/AASA file.
        if incomingURL.host == "usmankhan.dev" && incomingURL.path.starts(with: "/plaid-oauth/") {
            print("AppDelegate: URL matches Plaid OAuth pattern.")

            // Post a notification that the PlaidViewModel can observe
            // This decouples AppDelegate from knowing about PlaidViewModel directly.
            // NotificationCenter.default.post(name: .receivedPlaidLinkRedirectURI, object: incomingURL) // <-- Comment out this line
            // print("AppDelegate: Posted receivedPlaidLinkRedirectURI notification.")

            return true // Indicate we handled this universal link
        }

        // If the URL wasn't for Plaid OAuth, return false
        print("AppDelegate: Universal Link not handled.")
        return false
    }
}

// Define the Notification Name
extension Notification.Name {
    static let receivedPlaidLinkRedirectURI = Notification.Name("receivedPlaidLinkRedirectURI")
}

// class AppDelegate: NSObject, UIApplicationDelegate {
//     // ... (keep existing implementation including FirebaseApp.configure() and URL handling)
//      func application(_ application: UIApplication,
//                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
//         print("App Delegate: Configuring Firebase...")
//         FirebaseApp.configure()
//         print("App Delegate: Firebase Configured.")
//         return true
//     }

//     func application(_ app: UIApplication,
//                      open url: URL,
//                      options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
//         print("AppDelegate: Handling URL: \(url)")
//         if GIDSignIn.sharedInstance.handle(url) {
//              print("AppDelegate: URL handled by Google Sign-In.")
//             return true
//         }
//         // TODO: Add Apple Sign In URL handling
//         // TODO: Add Plaid OAuth URL handling (via NotificationCenter or directly calling PlaidViewModel)
//         print("AppDelegate: URL not handled.")
//         return false
//     }

//      
// }