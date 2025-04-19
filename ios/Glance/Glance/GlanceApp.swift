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
    // Register app delegate FOR Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    // Create ViewModels as StateObjects
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var plaidViewModel: PlaidViewModel
    @StateObject private var spendingViewModel: SpendingViewModel
    // Create the APIService (will be initialized in init)
    @State private var apiService: APIService!

    init() {
        // Configure Firebase FIRST
        FirebaseApp.configure()
        print("GlanceApp Init: Firebase Configured.")

        // --- Dependency Creation --- Create in order needed
        // 1. AuthViewModel (no dependencies needed for init)
        let authVM = AuthViewModel()
        _authViewModel = StateObject(wrappedValue: authVM)

        // 2. APIService (needs AuthViewModel)
        let apiSvc = APIService(authViewModel: authVM)
        _apiService = State(initialValue: apiSvc)

        // 3. Inject APIService into AuthViewModel (for getIDToken)
        authVM.setupAPIService(apiService: apiSvc)

        // 4. PlaidViewModel (needs APIService, AuthViewModel)
        _plaidViewModel = StateObject(wrappedValue: PlaidViewModel(apiService: apiSvc, authViewModel: authVM))

        // 5. SpendingViewModel (needs APIService)
        _spendingViewModel = StateObject(wrappedValue: SpendingViewModel(apiService: apiSvc))

        print("GlanceApp Init: ViewModels and Services Initialized.")
    }

    var body: some Scene {
        WindowGroup {
            // Use a Group to manage the view hierarchy based on auth and status
            Group {
                if !authViewModel.isAuthenticated {
                    // --- User Not Logged In ---
                    LoginView()
                } else if authViewModel.isCheckingStatus {
                    // --- Checking Plaid Status ---
                    // TODO: Replace with a nicer LoadingView
                    ProgressView("Checking account status...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.appBackground.ignoresSafeArea())
                } else if !authViewModel.hasConnectedBankAccount {
                    // --- Logged In, Needs Plaid Connection ---
                    PlaidConnectView()
                        .environmentObject(plaidViewModel)
                } else {
                    // --- Logged In, Plaid Connected ---
                    SpendingView()
                        // Provide SpendingViewModel to the SpendingView
                        .environmentObject(spendingViewModel)
                }
            }
            // Provide AuthViewModel to all views that might need it
            .environmentObject(authViewModel)
            // Provide apiService if needed directly (less common)
            // .environment(apiService)
        }
    }
}
