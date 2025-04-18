/**
 * @file routes.go
 * @brief Defines the API routes for the Glance backend server.
 */

package api

import (
	"net/http"

	"firebase.google.com/go/v4/auth"
	"github.com/gin-gonic/gin"
	"github.com/plaid/plaid-go/v32/plaid"
	log "github.com/sirupsen/logrus"
	"github.com/ukhan1219/glance/backend/internal/config"
	"github.com/ukhan1219/glance/backend/internal/database"
)

// SetupRoutes configures the Gin engine with all application routes.
// It applies necessary middleware like authentication checks.
//
// Args:
//
//	router (*gin.Engine): The Gin engine instance.
//	cfg (*config.Config): The application configuration.
//	authClient (*auth.Client): The Firebase Auth client.
//	dbService (*database.DatabaseService): The database service instance.
//	plaidClient (*plaid.APIClient): The Plaid API client.
func SetupRoutes(
	router *gin.Engine,
	cfg *config.Config,
	authClient *auth.Client,
	dbService *database.DatabaseService,
	plaidClient *plaid.APIClient,
) {
	log.Info("Setting up API routes...")

	// --- Public Routes ---
	// Health check - already added in main, but good practice to have it grouped if more public routes are added
	router.GET("/health", func(c *gin.Context) {
		log.Debug("Received request for /health endpoint")
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// --- API Route Group (e.g., /api/v1) ---
	// Consider versioning your API from the start
	apiGroup := router.Group("/api/v1") // Example using v1

	// --- Plaid Routes (Require Authentication) ---
	plaidGroup := apiGroup.Group("/plaid")
	plaidGroup.Use(AuthMiddleware(authClient)) // Apply Firebase Auth middleware to all /plaid routes
	{
		log.Info("Setting up /api/v1/plaid routes...")
		// Use the actual handlers from handlers.go
		plaidGroup.POST("/create_link_token", CreateLinkTokenHandler(cfg, plaidClient))
		plaidGroup.POST("/exchange_public_token", ExchangePublicTokenHandler(cfg, plaidClient, dbService))
		plaidGroup.GET("/spending", GetSpendingHandler(cfg, plaidClient, dbService))
		// Add more Plaid-related routes here if needed
	}

	// --- User Routes (Example - Might not be needed if using client-side Firebase Auth only) ---
	// userGroup := apiGroup.Group("/users")
	// userGroup.Use(AuthMiddleware(authClient))
	// {
	//  log.Info("Setting up /api/v1/users routes...")
	// 	userGroup.GET("/me", GetCurrentUserHandler(firestoreClient)) // Example endpoint
	// }

	log.Info("Finished setting up API routes.")
}

// No longer need placeholder handlers here as they are defined in handlers.go
