import UIKit
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure() // Initialize Firebase
        // Add other AppDelegate setup here later if needed (e.g., push notifications)
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
// TODO: Add application(_:continue:restorationHandler:) for Plaid OAuth Universal Links if needed
        return false // Indicate the URL was not handled
    }

    // Add method here later for handling Universal Links (Plaid OAuth)
    // func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool { ... }
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