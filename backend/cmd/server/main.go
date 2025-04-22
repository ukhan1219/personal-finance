package main

import (
	"context"
	"encoding/base64" // Import base64
	"fmt"
	"net/http"  // Added for http.Server
	"os"        // Added for signal handling
	"os/signal" // Added for signal handling
	"syscall"   // Added for signal handling
	"time"      // Added for context timeout

	// Remove direct import of firestore client type, it's handled in database package
	// "cloud.google.com/go/firestore"
	firebase "firebase.google.com/go/v4"

	// Remove direct import of v4/auth, it's handled in the auth package
	// "firebase.google.com/go/v4/auth"

	log "github.com/sirupsen/logrus"

	"github.com/gin-gonic/gin"
	// Remove direct import of plaid library, it's handled in the plaid package
	// "github.com/plaid/plaid-go/v32/plaid"

	"github.com/ukhan1219/glance/backend/internal/api"
	"github.com/ukhan1219/glance/backend/internal/auth" // Import internal auth package
	"github.com/ukhan1219/glance/backend/internal/config"
	"github.com/ukhan1219/glance/backend/internal/database" // Import internal database package
	"github.com/ukhan1219/glance/backend/internal/plaid"    // Import internal plaid package
)

// initFirebase initializes the Firebase Admin SDK application.
// It uses the credentials file path specified in the configuration.
// This initializes the core Firebase App, needed by both Auth and Firestore.
//
// Args:
//
//	ctx (context.Context): The context for initialization.
//	cfg (*config.Config): The application configuration containing the credentials path.
//
// Returns:
//
//	(*firebase.App, error): The initialized Firebase app instance and an error if initialization fails.
func initFirebase(ctx context.Context, cfg *config.Config) (*firebase.App, error) {
	log.Info("Attempting to initialize Firebase Admin SDK App...")
	// opt := option.WithCredentialsFile(cfg.FirebaseCredentials)
	// Use firebase.NewApp from the v4 package
	app, err := firebase.NewApp(ctx, nil)
	if err != nil {
		log.Errorf("Error initializing Firebase app: %v", err)
		return nil, fmt.Errorf("error initializing Firebase app: %w", err)
	}
	log.Info("Firebase Admin SDK App initialized successfully.")
	return app, nil
}

// main is the entry point for the Glance backend server.
// It loads configuration, initializes Firebase, initializes Plaid, sets up the Gin router,
// defines a health check endpoint, and starts the HTTP server.
func main() {
	// Configure logger
	log.SetFormatter(&log.JSONFormatter{})
	log.SetLevel(log.InfoLevel)

	log.Info("Starting Glance backend server...")

	// --- Load Configuration ---
	log.Info("Loading configuration...")
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}
	// Decode encryption key early (already validated in config.Load)
	encryptionKeyBytes, _ := base64.StdEncoding.DecodeString(cfg.PlaidTokenEncryptionKey)

	// --- Initialize Firebase App ---
	ctx := context.Background()
	firebaseApp, err := initFirebase(ctx, cfg)
	if err != nil {
		log.Fatalf("Failed to initialize Firebase App: %v", err)
	}

	// --- Initialize Firebase Services ---
	// Initialize Auth Client using the auth package function
	authClient, err := auth.InitializeAuthClient(ctx, firebaseApp)
	if err != nil {
		// Error is already logged in InitializeAuthClient
		log.Fatalf("Failed to initialize Firebase Auth client.")
	}

	// Define Project ID (Ideally from config or metadata server in production)
	projectID := "glance-prod-457519" // Replace with your actual project ID
	log.Infof("Using Project ID: %s for Firestore", projectID)

	// Initialize Firestore client first, passing the project ID
	// Note: We no longer pass firebaseApp here, as the new func doesn't need it.
	firestoreClient, err := database.InitializeFirestoreClient(ctx, projectID)
	if err != nil {
		log.Fatalf("Failed to initialize Firestore client: %v", err)
	}

	// Then create database service
	dbService, err := database.NewDatabaseService(firestoreClient, encryptionKeyBytes)
	if err != nil {
		log.Fatalf("Failed to initialize Database service: %v", err)
	}
	// Ensure Firestore client within dbService is closed gracefully
	defer func() {
		if dbService != nil {
			log.Info("Closing Firestore client via DatabaseService...")
			if err := dbService.CloseFirestore(ctx); err != nil { // Use context here
				log.Errorf("Error closing Firestore client: %v", err)
			} else {
				log.Info("Firestore client closed successfully.")
			}
		}
	}()

	// --- Initialize Plaid Client ---
	// Initialize Plaid Client using the plaid package function
	plaidClient, err := plaid.InitializePlaidClient(cfg)
	if err != nil {
		// Error is already logged in InitializePlaidClient
		log.Fatalf("Failed to initialize Plaid client.")
	}

	// --- Setup Gin Router ---
	log.Info("Setting up Gin router...")
	router := gin.Default() // Includes Logger and Recovery middleware

	// TODO: Setup additional general Middleware (CORS?) later if needed.

	// --- Setup API Routes ---
	// Pass the initialized clients and services to the route setup function
	api.SetupRoutes(router, cfg, authClient, dbService, plaidClient) // Pass dbService
	log.Info("API routes setup.")

	// --- Start Server with Graceful Shutdown ---
	serverAddr := ":" + cfg.Port
	log.Infof("Attempting to start HTTP server on %s", serverAddr)

	// Create the HTTP server
	srv := &http.Server{
		Addr:    serverAddr,
		Handler: router, // Use the Gin engine as the handler
	}

	// Start the server in a goroutine
	go func() {
		log.Infof("Starting HTTP server on %s", serverAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to listen and serve: %v", err)
		}
	}()

	// --- Wait for interrupt signal to gracefully shut down the server ---
	quit := make(chan os.Signal, 1) // Buffer of 1
	// Notify sends the specified signals to the channel.
	// SIGINT: Sent on Ctrl+C.
	// SIGTERM: Standard signal for termination.
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	// Block until a signal is received.
	<-quit
	log.Info("Received shutdown signal. Starting graceful shutdown...")

	// Create a context with a timeout for the shutdown.
	// Give outstanding requests 5 seconds to finish.
	shutdownCtx, cancelShutdown := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancelShutdown()

	// Attempt to gracefully shut down the HTTP server.
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Errorf("Server forced to shutdown: %v", err)
	}

	// --- Close Firestore Connection ---
	// Use a separate context for Firestore closure, potentially with its own timeout
	// if the 5-second server shutdown timeout isn't sufficient.
	closeDbCtx, cancelCloseDb := context.WithTimeout(context.Background(), 10*time.Second) // Example: 10s timeout for DB close
	defer cancelCloseDb()

	// Call the CloseFirestore method from the DatabaseService
	if dbService != nil {
		log.Info("Closing Firestore client as part of graceful shutdown...")
		if err := dbService.CloseFirestore(closeDbCtx); err != nil {
			log.Errorf("Error closing Firestore client during shutdown: %v", err)
		} else {
			log.Info("Firestore client closed successfully during shutdown.")
		}
	} else {
		log.Warn("dbService was nil during shutdown, couldn't close Firestore.")
	}

	log.Info("Server exiting.")
}
