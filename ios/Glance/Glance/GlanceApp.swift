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
    // Create other potential global ViewModels if needed
    // @StateObject private var plaidViewModel = PlaidViewModel() // Initialize if needed globally

    var body: some Scene {
        WindowGroup {
            // Main view logic
            if authViewModel.isAuthenticated {
                // User is logged in, now check if Plaid connection is needed
                if authViewModel.needsPlaidConnection {
                    // Show the Plaid Connection prompt view
                    PlaidConnectView()
                        .environmentObject(authViewModel) // Pass AuthViewModel
                        // Pass PlaidViewModel if the button needs it directly
                        // .environmentObject(plaidViewModel)
                } else {
                    // Show the main dashboard/spending view
                    // Replace this VStack with your actual main content view (e.g., SpendingView or MainTabView)
                    VStack {
                        Text("Main Dashboard (Plaid Connected)") // Placeholder
                        // Add Logout Button (or move to a profile screen)
                        Button("Logout") {
                            authViewModel.signOut()
                        }
                        .padding()
                        .buttonStyle(.borderedProminent)
                    }
                    .environmentObject(authViewModel) // Pass AuthViewModel if needed
                    // Pass other ViewModels as needed
                    // .environmentObject(SpendingViewModel(authViewModel: authViewModel))
                }
            } else {
                // Show LoginView if not authenticated
                LoginView()
                    .environmentObject(authViewModel) // Pass the AuthViewModel
            }
        }
    }
}
