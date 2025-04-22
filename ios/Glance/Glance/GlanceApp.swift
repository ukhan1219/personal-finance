//
//  GlanceApp.swift
//  Glance
//
//  Created by Usman Khan on 4/16/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAppCheck

@main
struct GlanceApp: App {
    // Register app delegate FOR Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    // Access scene phase to detect app becoming active
    @Environment(\.scenePhase) var scenePhase

    // Create ViewModels as StateObjects
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var plaidViewModel: PlaidViewModel
    @StateObject private var spendingViewModel: SpendingViewModel
    // Create the APIService (will be initialized in init)
    @State private var apiService: APIService!

    init() {
        // Configure Firebase FIRST
        FirebaseApp.configure()
        print("GlanceApp Init: Firebase Configured HERE.")

        // --- Initialize App Check ---
        #if DEBUG
        // Use the debug provider factory on DEBUG builds
        let providerFactory = AppCheckDebugProviderFactory()
        print("GlanceApp Init: Using App Check DEBUG Provider Factory.")
        // ** IMPORTANT: Run your app with this change in the simulator or on a test device.
        // ** Look for a log message like: "[Firebase/AppCheck][I-FAC000001] App Check debug token: '<SOME_TOKEN_STRING>'. ..."
        // ** Copy that token string.
        // ** Edit your Xcode scheme: Run -> Arguments -> Environment Variables.
        // ** Add variable named "FIRAAppCheckDebugToken" with the copied token string as the value.
        // ** Now, rerun your app. App Check requests should succeed in DEBUG.
        #else
        // Use the DeviceCheck provider factory on RELEASE builds
        let providerFactory = DeviceCheckProviderFactory()
        print("GlanceApp Init: Using App Check DeviceCheck Provider Factory.")
        #endif
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("GlanceApp Init: App Check Provider Factory Set.")
        print("GlanceApp Init: ==> CONFIRM: App Check Debug Factory setup should be complete.")

        // --- Dependency Creation --- Create in order needed
        // 1. AuthViewModel (no dependencies needed for init)
        let authVM = AuthViewModel()
        _authViewModel = StateObject(wrappedValue: authVM)

        // 2. APIService (needs AuthViewModel)
        let apiSvc = APIService(authViewModel: authVM)
        _apiService = State(initialValue: apiSvc)

        // 3. Inject APIService into AuthViewModel (for getIDToken)
        authVM.setupAPIService(apiService: apiSvc)

        // 4. SpendingViewModel (needs APIService) - Create BEFORE PlaidViewModel
        let spendingVM = SpendingViewModel(apiService: apiSvc)
        _spendingViewModel = StateObject(wrappedValue: spendingVM)

        // 5. PlaidViewModel (needs APIService, AuthViewModel, SpendingViewModel)
        _plaidViewModel = StateObject(wrappedValue: PlaidViewModel(apiService: apiSvc, authViewModel: authVM, spendingViewModel: spendingVM))

        print("GlanceApp Init: ViewModels and Services Initialized.")
    }

    var body: some Scene {
        WindowGroup {
            // Use a Group to manage the view hierarchy based on auth and status
            Group {
                // --- NEW: Locked State Check --- Handle this FIRST
                if authViewModel.isAuthenticated && authViewModel.isLocked {
                    LockedView()
                         .transition(.opacity) // Optional: Add a subtle transition
                } else if !authViewModel.isAuthenticated {
                    // --- User Not Logged In ---
                    LoginView()
                } else if !authViewModel.isEmailVerified && authViewModel.user?.providerData.first?.providerID == "password" {
                    // --- Logged In via Email/Pass, Needs Verification ---
                    // Check providerID to ensure only email/password users see this.
                    // Apple/Google users skip this step.
                    EmailVerificationView()
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
                    // --- Logged In, Plaid Connected, Email Verified (if applicable) --- Show Main App UI
                    // Wrap SpendingView and SettingsView in a TabView for swipe navigation
                    TabView {
                        SpendingView()
                            // Provide SpendingViewModel to the SpendingView
                            .environmentObject(spendingViewModel)
                            .tag(0) // Assign a tag for potential programmatic navigation (optional)

                        SettingsView()
                            .tag(1) // Assign a tag

                    }
                    .tabViewStyle(.page(indexDisplayMode: .never)) // Use page style, hide dots
                    .background(Color.appBackground.ignoresSafeArea()) // Ensure background covers edges
                    .ignoresSafeArea(edges: .bottom) // Allow content like TabView to go to bottom edge

                }
            }
            // Provide AuthViewModel to all views that might need it
            .environmentObject(authViewModel)
            // --- Provide PlaidViewModel and SpendingViewModel --- Needed by subviews
            .environmentObject(plaidViewModel)
            .environmentObject(spendingViewModel)
            // Provide apiService if needed directly (less common)
            // .environment(apiService)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
             if newPhase == .inactive || newPhase == .background {
                  // Lock the app when going to background if authenticated
                  if authViewModel.isAuthenticated {
                      print("GlanceApp: Scene inactive/background. Locking app.")
                      authViewModel.lock()
                  }
             } else if newPhase == .active {
                 // Reload user data when the app becomes active,
                 // especially important for picking up email verification status
                 // after the user clicks the link in their email app.
                 if authViewModel.isAuthenticated {
                      print("GlanceApp: App became active, user authenticated. Reloading user data.")
                      authViewModel.reloadUser() // Ensure latest user state

                      // Request unlock *after* confirming auth state
                      print("GlanceApp: Requesting biometric unlock.")
                      // Only request unlock if currently locked
                      if authViewModel.isLocked {
                          authViewModel.requestBiometricUnlock()
                      } else {
                           print("GlanceApp: App already unlocked.")
                           // If already unlocked, trigger data refresh immediately
                           spendingViewModel.refreshSpendingDataIfNeeded()
                      }
                 } else {
                      print("GlanceApp: App became active, user NOT authenticated.")
                      // Ensure app is locked if user is not authenticated when coming to foreground
                      // (Safety measure, should normally be handled by signOut)                     
                      authViewModel.lock()
                 }
             }
         }
         // --- NEW: Trigger data refresh *after* unlock ---
         .onChange(of: authViewModel.isLocked) { wasLocked, isNowLocked in
              // If the app is authenticated AND just became unlocked
              if authViewModel.isAuthenticated && !isNowLocked {
                   print("GlanceApp: App unlocked via isLocked change. Refreshing spending data if needed.")
                   spendingViewModel.refreshSpendingDataIfNeeded()
              }
         }
    }
}
