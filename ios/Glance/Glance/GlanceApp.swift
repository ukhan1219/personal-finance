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
                // Show lock screen only if authenticated, bank connected, AND locked
                if authViewModel.isAuthenticated && authViewModel.hasConnectedBankAccount && authViewModel.isLocked {
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
                } else {
                    // --- Logged In, Email Verified (if needed) --- Show Main App UI (with conditional first tab)
                    // Wrap main views in a TabView for swipe navigation
                    TabView {
                        // --- CONDITIONAL FIRST TAB ---
                        if !authViewModel.hasConnectedBankAccount {
                             // --- Logged In, Needs Plaid Connection ---
                             PlaidConnectView()
                                 // EnvironmentObject for PlaidViewModel is already applied below
                                 .tag(0) // Assign a tag
                        } else {
                            // --- Logged In, Plaid Connected --- Show Spending View
                            SpendingView()
                                // EnvironmentObject for SpendingViewModel is already applied below
                                .tag(0) // Assign the same tag
                        }

                        // --- Settings View (Always the second tab) ---
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
            // These are available to PlaidConnectView, SpendingView, and SettingsView as needed
            .environmentObject(plaidViewModel)
            .environmentObject(spendingViewModel)
            // Provide apiService if needed directly (less common)
            // .environment(apiService)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
             if newPhase == .inactive || newPhase == .background {
                  // Lock the app when going to background ONLY if authenticated AND bank connected
                  if authViewModel.isAuthenticated && authViewModel.hasConnectedBankAccount {
                      print("GlanceApp: Scene inactive/background. Locking app (authenticated + bank connected).")
                      authViewModel.lock()
                  } else {
                      print("GlanceApp: Scene inactive/background. Not locking (not authenticated or bank not connected).")
                  }
             } else if newPhase == .active {
                 // --- Handle App Activation ---
                 if authViewModel.isAuthenticated {
                     // If user is authenticated when app becomes active...
                     print("GlanceApp: App became active, user authenticated. Reloading user data.")
                     authViewModel.reloadUser() // Ensure latest user state (incl. verification)

                     // Check if bank account is connected
                     if authViewModel.hasConnectedBankAccount {
                          print("GlanceApp: Bank account IS connected.")
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
                         // Authenticated, but NO bank account connected yet
                         print("GlanceApp: Bank account IS NOT connected.")
                         // Ensure the app is NOT locked in this state
                         DispatchQueue.main.async { // Ensure state update happens on main thread
                             authViewModel.isLocked = false
                         }
                         print("GlanceApp: Ensured app is unlocked (no bank account).")
                         // No spending data to refresh here yet.
                     }

                 } else {
                      print("GlanceApp: App became active, user NOT authenticated.")
                      // Ensure app is locked if user is not authenticated when coming to foreground
                      // (Safety measure, should normally be handled by signOut)
                      // Calling lock() is safe as it will internally check auth/bank status
                      authViewModel.lock()
                 }
             }
         }
         // --- NEW: Trigger data refresh *after* unlock ---
         .onChange(of: authViewModel.isLocked) { wasLocked, isNowLocked in
              // If the app is authenticated, bank connected, AND just became unlocked
              if authViewModel.isAuthenticated && authViewModel.hasConnectedBankAccount && !isNowLocked {
                   print("GlanceApp: App unlocked via isLocked change (with bank connected). Refreshing spending data if needed.")
                   spendingViewModel.refreshSpendingDataIfNeeded()
              } else if !isNowLocked {
                   print("GlanceApp: App unlocked via isLocked change (but not authenticated or no bank connected). No data refresh triggered.")
              }
         }
    }
}
