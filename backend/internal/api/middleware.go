/**
 * @file middleware.go
 * @brief Defines Gin middleware functions, particularly for handling authentication.
 */

package api

import (
	"context"
	"net/http"
	"strings"

	// Corrected Firebase Auth Import
	"firebase.google.com/go/v4/auth"

	"github.com/gin-gonic/gin"
	log "github.com/sirupsen/logrus"
)

// firebaseUserContextKey is the key used to store the verified Firebase user token in the Gin context.
const firebaseUserContextKey = "firebaseUser"

/**
 * @brief Creates a Gin middleware function to verify Firebase ID tokens.
 *
 * This middleware expects an ID token in the 'Authorization: Bearer <token>' header.
 * It verifies the token using the provided Firebase Auth client. If valid, it extracts
 * the user information and stores it in the Gin context under the key defined by
 * 'firebaseUserContextKey'. If the token is missing, invalid, or verification fails,
 * it aborts the request with a 401 Unauthorized status.
 *
 * @param authClient *auth.Client A pointer to the initialized Firebase Auth client (from v4/auth).
 * @return gin.HandlerFunc The Gin middleware handler function.
 */
func AuthMiddleware(authClient *auth.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			log.Warn("Authorization header missing")
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			log.Warnf("Invalid Authorization header format: %s", authHeader)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid Authorization header format"})
			return
		}
		idToken := parts[1]

		// VerifyIDToken is a method on the *auth.Client type from v4/auth
		token, err := authClient.VerifyIDToken(context.Background(), idToken)
		if err != nil {
			log.Warnf("Error verifying Firebase ID token: %v", err)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
			return
		}

		// Token is valid, add user info to context for handlers
		log.Debugf("Firebase ID token verified successfully for UID: %s", token.UID)
		c.Set(firebaseUserContextKey, token) // token is of type *auth.Token from v4/auth
		c.Next()                             // Proceed to the next handler
	}
}

/**
 * @brief Retrieves the verified Firebase user token from the Gin context.
 *
 * This helper function should be called within route handlers that are protected
 * by the AuthMiddleware. It fetches the token stored by the middleware.
 *
 * @param c *gin.Context The Gin context for the current request.
 * @return (*auth.Token, bool) A pointer to the verified Firebase token (from v4/auth) and a boolean
 *         indicating whether the token was found and is of the correct type.
 */
func GetUserFromContext(c *gin.Context) (*auth.Token, bool) {
	user, exists := c.Get(firebaseUserContextKey)
	if !exists {
		log.Error("Firebase user token not found in context. Middleware might be missing.")
		return nil, false
	}
	// Ensure the type assertion matches the type from v4/auth
	token, ok := user.(*auth.Token)
	if !ok {
		log.Error("Value found in context for firebaseUserContextKey is not of type *auth.Token")
		return nil, false
	}
	return token, true
}
