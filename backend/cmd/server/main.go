package main

import (
	"context"
	"fmt"

	// Remove direct import of firestore client type, it's handled in database package
	// "cloud.google.com/go/firestore"
	firebase "firebase.google.com/go/v4"

	// Remove direct import of v4/auth, it's handled in the auth package
	// "firebase.google.com/go/v4/auth"

	log "github.com/sirupsen/logrus"
	"google.golang.org/api/option"

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
	opt := option.WithCredentialsFile(cfg.FirebaseCredentials)
	// Use firebase.NewApp from the v4 package
	app, err := firebase.NewApp(ctx, nil, opt)
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

	// Initialize Firestore Client using the database package function
	firestoreClient, err := database.InitializeFirestoreClient(ctx, firebaseApp)
	if err != nil {
		// Error is already logged in initFirestore
		log.Fatalf("Failed to initialize Firestore client.")
	}
	// Ensure Firestore client is closed gracefully on shutdown
	defer func() {
		log.Info("Closing Firestore client...")
		if err := firestoreClient.Close(); err != nil {
			log.Errorf("Error closing Firestore client: %v", err)
		} else {
			log.Info("Firestore client closed successfully.")
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
	// Pass the initialized clients to the route setup function
	api.SetupRoutes(router, cfg, authClient, firestoreClient, plaidClient)
	log.Info("API routes setup complete.")

	// --- Start Server ---
	serverAddr := ":" + cfg.Port
	log.Infof("Starting HTTP server on %s", serverAddr)
	if err := router.Run(serverAddr); err != nil {
		log.Fatalf("Failed to run server: %v", err)
	}
}
