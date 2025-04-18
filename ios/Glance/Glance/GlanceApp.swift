//
//  GlanceApp.swift
//  Glance
//
//  Created by Usman Khan on 4/16/25.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct GlanceApp: App {
    // Register app delegate FOR Firebase setup - This line correctly refers to the AppDelegate class defined in AppDelegate.swift
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    // Create the AuthViewModel as a StateObject
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            // Conditionally show Login or Main App
            if authViewModel.isAuthenticated {
                // Replace with your main authenticated view (e.g., SpendingView or MainTabView)
                // Example: SpendingView()
                // Example: MainTabView()
                VStack { // Use a VStack to place the button
                    Text("Logged In! (Replace with Main View)") // Placeholder

                    // Add Logout Button
                    Button("Logout") {
                        authViewModel.signOut()
                    }
                    .padding()
                    .buttonStyle(.borderedProminent) // Basic styling
                }
                     .environmentObject(authViewModel) // Pass down if needed
                     // Pass other view models here if needed
                     // .environmentObject(SpendingViewModel(authViewModel: authViewModel))
                     // .environmentObject(PlaidViewModel(authViewModel: authViewModel))
            } else {
                // Show LoginView if not authenticated
                LoginView()
                    .environmentObject(authViewModel) // Pass the AuthViewModel
            }
        }
    }
}
