/**
 * @file firestore.go
 * @brief Defines functions for interacting with Google Firestore, including initialization and data operations.
 */

package database

import (
	"context"
	"encoding/base64" // Using Base64 as a TEMPORARY placeholder for "encryption"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	firebase "firebase.google.com/go/v4" // Add firebase import
	log "github.com/sirupsen/logrus"
	"google.golang.org/api/iterator" // Required for iterating through documents
)

// plaidItemsCollection defines the name of the Firestore collection used to store Plaid item data.
const plaidItemsCollection = "plaidItems"

// PlaidItem represents the structure of data stored for a Plaid item in Firestore.
type PlaidItem struct {
	UserID               string    `firestore:"userId"`      // Matches the Firebase Auth UID
	EncryptedAccessToken string    `firestore:"accessToken"` // Store the encrypted token
	CreatedAt            time.Time `firestore:"createdAt"`
	// Add other fields if needed, e.g., InstitutionID, InstitutionName
}

// --- Firestore Initialization ---

// InitializeFirestoreClient initializes the Firestore client from a Firebase App instance.
//
// Args:
//
//	ctx (context.Context): The context for initialization.
//	app (*firebase.App): The initialized Firebase App instance.
//
// Returns:
//
//	(*firestore.Client, error): The Firestore client and an error if initialization fails.
func InitializeFirestoreClient(ctx context.Context, app *firebase.App) (*firestore.Client, error) {
	log.Info("Attempting to initialize Firestore client...")
	firestoreClient, err := app.Firestore(ctx)
	if err != nil {
		log.Errorf("Failed to get Firestore client: %v", err) // Use Errorf, not Fatalf
		return nil, fmt.Errorf("failed to initialize Firestore client: %w", err)
	}
	log.Info("Firestore client obtained successfully.")
	return firestoreClient, nil
}

// --- Encryption Placeholder ---
// WARNING: Base64 is NOT real encryption. It's just encoding.
// This is a placeholder and MUST be replaced with a proper encryption mechanism
// (like AES-GCM with a key managed by KMS or environment variable) before production.

// encryptTokenPlaceholder encodes the token using Base64. Replace with real encryption.
func encryptTokenPlaceholder(token string) string {
	return base64.StdEncoding.EncodeToString([]byte(token))
}

// decryptTokenPlaceholder decodes the token from Base64. Replace with real decryption.
func decryptTokenPlaceholder(encodedToken string) (string, error) {
	decodedBytes, err := base64.StdEncoding.DecodeString(encodedToken)
	if err != nil {
		return "", fmt.Errorf("failed to decode base64 token: %w", err)
	}
	return string(decodedBytes), nil
}

// --- Firestore Operations ---

// StorePlaidItem saves Plaid item details (access token, item ID) for a user in Firestore.
// It uses a placeholder for access token encryption.
//
// Args:
//
//	ctx (context.Context): The context for the Firestore operation.
//	client (*firestore.Client): The Firestore client instance.
//	userID (string): The Firebase Authentication UID of the user.
//	itemID (string): The Plaid Item ID, used as the document ID.
//	accessToken (string): The raw Plaid access token (will be "encrypted").
//
// Returns:
//
//	error: An error if the operation fails, otherwise nil.
func StorePlaidItem(ctx context.Context, client *firestore.Client, userID, itemID, accessToken string) error {
	logFields := log.Fields{"userID": userID, "itemID": itemID}
	log.WithFields(logFields).Info("Storing Plaid item details in Firestore...")

	// --- !!! WARNING: Placeholder Encryption !!! ---
	encryptedToken := encryptTokenPlaceholder(accessToken)
	log.WithFields(logFields).Warn("Using placeholder (Base64) for access token storage. REPLACE WITH REAL ENCRYPTION.")
	// --- End Warning ---

	itemData := PlaidItem{
		UserID:               userID,
		EncryptedAccessToken: encryptedToken,
		CreatedAt:            time.Now().UTC(), // Use UTC time
	}

	// Use itemID as the document ID in the plaidItems collection
	docRef := client.Collection(plaidItemsCollection).Doc(itemID)

	_, err := docRef.Set(ctx, itemData)
	if err != nil {
		log.WithFields(logFields).Errorf("Failed to set Plaid item document in Firestore: %v", err)
		return fmt.Errorf("failed to store plaid item: %w", err)
	}

	log.WithFields(logFields).Info("Successfully stored Plaid item in Firestore.")
	return nil
}

// GetUserAccessTokens retrieves all Plaid access tokens associated with a user ID from Firestore.
// It uses a placeholder for access token decryption.
//
// Args:
//
//	ctx (context.Context): The context for the Firestore operation.
//	client (*firestore.Client): The Firestore client instance.
//	userID (string): The Firebase Authentication UID of the user.
//
// Returns:
//
//	([]string, error): A slice of decrypted access tokens and an error if retrieval fails.
func GetUserAccessTokens(ctx context.Context, client *firestore.Client, userID string) ([]string, error) {
	logFields := log.Fields{"userID": userID}
	log.WithFields(logFields).Info("Retrieving Plaid access tokens from Firestore...")

	var tokens []string
	// Query the plaidItems collection for documents where the userId field matches the user's ID
	iter := client.Collection(plaidItemsCollection).Where("userId", "==", userID).Documents(ctx)
	defer iter.Stop() // Ensure the iterator is always stopped

	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			log.WithFields(logFields).Infof("Finished iterating through Plaid items. Found %d token(s).", len(tokens))
			break // No more documents
		}
		if err != nil {
			log.WithFields(logFields).Errorf("Failed during iteration of Plaid items: %v", err)
			return nil, fmt.Errorf("failed to iterate plaid items: %w", err)
		}

		var item PlaidItem
		if err := doc.DataTo(&item); err != nil {
			log.WithFields(logFields).Warnf("Failed to parse Plaid item document %s: %v", doc.Ref.ID, err)
			continue // Skip this document if parsing fails
		}

		// --- !!! WARNING: Placeholder Decryption !!! ---
		log.WithFields(logFields).Warn("Using placeholder (Base64) for access token retrieval. REPLACE WITH REAL DECRYPTION.")
		decryptedToken, err := decryptTokenPlaceholder(item.EncryptedAccessToken)
		if err != nil {
			log.WithFields(logFields).Errorf("Failed to decrypt token for item %s: %v", doc.Ref.ID, err)
			// Decide how to handle decryption failure - skip token or return overall error?
			// Skipping for now.
			continue
		}
		// --- End Warning ---

		tokens = append(tokens, decryptedToken)
		log.WithFields(logFields).Debugf("Successfully retrieved and decrypted token for item %s", doc.Ref.ID)
	}

	return tokens, nil
}

// TODO: Implement EncryptTokenFunction and DecryptTokenFunction using a secure method
// (e.g., Google Cloud KMS, AES-GCM with key from env/secrets manager).
