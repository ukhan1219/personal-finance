/**
 * @file handlers.go
 * @brief Implements the HTTP request handlers for the API endpoints defined in routes.go.
 */

package api

import (
	"context"
	"net/http"
	"time"

	"cloud.google.com/go/firestore"
	"firebase.google.com/go/v4/auth"
	"github.com/gin-gonic/gin"
	"github.com/plaid/plaid-go/v32/plaid"
	log "github.com/sirupsen/logrus"
	"google.golang.org/api/iterator"

	"github.com/ukhan1219/glance/backend/internal/config"
	"github.com/ukhan1219/glance/backend/internal/database" // Import database package
	"github.com/ukhan1219/glance/backend/internal/domain"   // Import domain package
)

// PlaidHandlerDependencies holds the dependencies needed by Plaid-related handlers.
// This helps in organizing dependencies passed from main.go or route setup.
type PlaidHandlerDependencies struct {
	Config          *config.Config
	PlaidClient     *plaid.APIClient
	FirestoreClient *firestore.Client
	AuthClient      *auth.Client
}

// CreateLinkTokenHandler handles the request to create a Plaid Link token.
// It expects an authenticated user context (set by AuthMiddleware).
//
// Returns:
//
//	gin.HandlerFunc: The Gin handler function.
func CreateLinkTokenHandler(cfg *config.Config, plaidClient *plaid.APIClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 1. Get User ID from context
		firebaseUser, exists := GetUserFromContext(c)
		if !exists {
			// GetUserFromContext already logs the error
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}
		userID := firebaseUser.UID
		logCtx := log.WithFields(log.Fields{"userID": userID})
		logCtx.Info("CreateLinkTokenHandler invoked")

		// 2. Prepare Plaid Link Token Request
		ctx := context.Background()
		linkUser := plaid.NewLinkTokenCreateRequestUser(userID)

		// --- *** ADD REQUIRED FIELDS *** ---
		// These are examples, adjust as needed for your app
		clientName := "Glance Finance App"                                             // Or get from config?
		products := []plaid.Products{plaid.PRODUCTS_TRANSACTIONS, plaid.PRODUCTS_AUTH} // Choose products needed
		countryCodes := []plaid.CountryCode{plaid.COUNTRYCODE_US}                      // Choose countries needed
		language := "en"
		// Add a placeholder redirect URI (even if just for sandbox/testing initially)
		// IMPORTANT: Also add this exact URI to your Plaid Dashboard API settings
		// redirectUri := "http://localhost:3000/oauth-callback" // Example, adjust if needed
		redirectUri := "https://usmankhan.dev/plaid-oauth/"
		linkTokenCreateRequest := plaid.NewLinkTokenCreateRequest(
			clientName,
			language,
			countryCodes,
			*linkUser,
		)
		linkTokenCreateRequest.SetProducts(products)
		linkTokenCreateRequest.SetRedirectUri(redirectUri) // Set the redirect URI
		// Optional: Set webhook URL if you have one configured
		// linkTokenCreateRequest.SetWebhook("YOUR_WEBHOOK_URL")

		logCtx.Info("Calling Plaid LinkTokenCreate API...")

		// 3. Call Plaid API
		resp, rawResponse, err := plaidClient.PlaidApi.LinkTokenCreate(ctx).LinkTokenCreateRequest(*linkTokenCreateRequest).Execute()

		// --- *** IMPROVED ERROR HANDLING *** ---
		if err != nil {
			errorMsg := "Failed to create link token"
			statusCode := http.StatusInternalServerError // Default status code
			logCtx.Errorf("Plaid API error during LinkTokenCreate: %v", rawResponse)

			c.AbortWithStatusJSON(statusCode, gin.H{"error": errorMsg}) // Keep generic error for client
			return
		}
		// --- *** END IMPROVED ERROR HANDLING *** ---

		// 4. Return Link Token
		linkToken := resp.GetLinkToken()
		logCtx.Info("Successfully created link token.")
		c.JSON(http.StatusOK, gin.H{"link_token": linkToken})
	}
}

// ExchangePublicTokenHandler handles the exchange of a Plaid public token for an access token.
// It stores the received access token and item ID securely (TODO: Encryption).
//
// Returns:
//
//	gin.HandlerFunc: The Gin handler function.
func ExchangePublicTokenHandler(cfg *config.Config, plaidClient *plaid.APIClient, dbService *database.DatabaseService) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 1. Get User ID from context
		firebaseUser, exists := GetUserFromContext(c)
		if !exists {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}
		userID := firebaseUser.UID

		// 2. Bind Request Body
		var req domain.ExchangePublicTokenRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"error": "Invalid request body", "details": err.Error()})
			return
		}

		// 3. Call Plaid API to exchange token
		ctx := context.Background()
		exchangeRequest := plaid.NewItemPublicTokenExchangeRequest(req.PublicToken)
		resp, _, err := plaidClient.PlaidApi.ItemPublicTokenExchange(ctx).ItemPublicTokenExchangeRequest(*exchangeRequest).Execute()

		if err != nil {
			errorMsg := "Failed to exchange public token"
			statusCode := http.StatusInternalServerError
			c.AbortWithStatusJSON(statusCode, gin.H{"error": errorMsg})
			return
		}

		accessToken := resp.GetAccessToken()
		itemID := resp.GetItemId()

		// 4. Store Access Token and Item ID using DatabaseService method
		log.Infof("Storing item details (Item ID: %s) for user %s", itemID, userID)
		err = dbService.StorePlaidItem(ctx, userID, itemID, accessToken) // Use dbService method
		if err != nil {
			log.Errorf("Failed to store Plaid item details for user %s, item %s: %v", userID, itemID, err)
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "Failed to save account connection details"})
			return
		}
		log.Infof("Successfully stored item details for user %s, item %s", userID, itemID)

		// 5. Return Success
		c.JSON(http.StatusOK, gin.H{"status": "success", "message": "Account connected successfully"})
	}
}

// GetSpendingHandler calculates and returns the user's spending for today, this week, and this month.
//
// Returns:
//
//	gin.HandlerFunc: The Gin handler function.
func GetSpendingHandler(cfg *config.Config, plaidClient *plaid.APIClient, dbService *database.DatabaseService) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 1. Get User ID from context
		firebaseUser, exists := GetUserFromContext(c)
		if !exists {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}
		userID := firebaseUser.UID

		// 2. Get User's Plaid Access Tokens using DatabaseService method
		accessTokens, err := dbService.GetUserAccessTokens(c.Request.Context(), userID) // Use dbService method
		if err != nil {
			log.Errorf("Failed to retrieve access tokens for user %s: %v", userID, err)
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "Could not retrieve account connection details"})
			return
		}

		if len(accessTokens) == 0 {
			c.JSON(http.StatusOK, domain.SpendingSummary{Today: 0, Week: 0, Month: 0})
			return
		}

		// 3. Calculate Date Ranges (Rolling period ending today)
		now := time.Now()
		todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()) // Start of today
		weekStart := todayStart.AddDate(0, 0, -6)                                               // Start of day 6 days ago
		monthStart := todayStart.AddDate(0, -1, 0)                                              // Start of day 1 month ago (e.g., if today is May 16, this is April 17)

		endDateStr := now.Format("2006-01-02")               // Plaid uses YYYY-MM-DD
		monthStartDateStr := monthStart.Format("2006-01-02") // Plaid uses YYYY-MM-DD

		var totalToday, totalWeek, totalMonth float64

		ctx := c.Request.Context() // Use request context for Plaid calls

		// 4. Iterate through each access token and fetch transactions
		for _, token := range accessTokens {
			// TODO: Decrypt token if it was stored encrypted

			options := plaid.NewTransactionsGetRequestOptions()
			options.SetCount(500)

			req := plaid.NewTransactionsGetRequest(token, monthStartDateStr, endDateStr)
			req.SetOptions(*options)

			resp, _, err := plaidClient.PlaidApi.TransactionsGet(ctx).TransactionsGetRequest(*req).Execute()
			if err != nil {
				// No logging here, just continue
				continue // Skip this token if transactions fail
			}

			// 5. Process Transactions and Aggregate Spending
			for _, txn := range resp.GetTransactions() {
				// Plaid amounts: positive means money flowing out (spending)
				amount := txn.GetAmount()
				if amount <= 0 { // Skip income/deposits/zero amounts
					continue
				}

				txnDate, err := time.Parse("2006-01-02", txn.GetDate())
				if err != nil {
					continue
				}

				// Add to monthly total (already filtered by API call dates)
				totalMonth += amount

				// Check if within week (Use time comparison: >= weekStart and <= now)
				if !txnDate.Before(weekStart) { // If txnDate is on or after weekStart
					totalWeek += amount
				}

				// Check if today (Use time comparison: >= todayStart and <= now)
				if !txnDate.Before(todayStart) { // If txnDate is on or after todayStart
					totalToday += amount
				}
			}
		} // End loop through tokens

		// 6. Return Aggregated Spending Summary
		summary := domain.SpendingSummary{
			Today: totalToday,
			Week:  totalWeek,
			Month: totalMonth,
		}
		c.JSON(http.StatusOK, summary)
	}
}

// GetUserStatusHandler checks if the authenticated user has linked Plaid items.
func GetUserStatusHandler(dbService *database.DatabaseService) gin.HandlerFunc {
	return func(c *gin.Context) {
		firebaseUser, exists := GetUserFromContext(c)
		if !exists {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}
		userID := firebaseUser.UID
		ctx := c.Request.Context() // Use request context

		logFields := log.Fields{"userID": userID}
		log.WithFields(logFields).Info("Checking Plaid connection status...")

		// Use the Firestore client directly for efficient existence check
		iter := dbService.GetFirestoreClient().Collection(database.PlaidItemsCollectionName).Where("userId", "==", userID).Limit(1).Documents(ctx)
		_, err := iter.Next() // We only care if there's at least one doc

		hasConnected := false
		if err == nil {
			hasConnected = true // Found at least one document
			log.WithFields(logFields).Info("User has connected bank account(s).")
		} else if err == iterator.Done {
			// No documents found
			log.WithFields(logFields).Info("User has not connected any bank accounts.")
			hasConnected = false
		} else {
			// Firestore error
			log.WithFields(logFields).Errorf("Error checking Firestore for Plaid items: %v", err)
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "Failed to check account status"})
			return
		}
		iter.Stop() // Ensure iterator is stopped

		c.JSON(http.StatusOK, gin.H{"hasConnectedBankAccount": hasConnected})
	}
}
