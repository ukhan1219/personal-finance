/**
 * @file firestore.go
 * @brief Defines functions for interacting with Google Firestore, including initialization and data operations.
 */

package database

import (
	"context" // Needed for decoding the key from config
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	firebase "firebase.google.com/go/v4"
	log "github.com/sirupsen/logrus"
	"google.golang.org/api/iterator"

	"github.com/ukhan1219/glance/backend/internal/encryption" // Import encryption package
)

// PlaidItemsCollectionName defines the name of the Firestore collection used to store Plaid item data.
// Exported constant for use in other packages like api handlers.
const PlaidItemsCollectionName = "plaidItems"

// PlaidItem represents the structure of data stored for a Plaid item in Firestore.
type PlaidItem struct {
	UserID               string    `firestore:"userId"`      // Matches the Firebase Auth UID
	EncryptedAccessToken string    `firestore:"accessToken"` // Store the encrypted token
	CreatedAt            time.Time `firestore:"createdAt"`
}

// DatabaseService encapsulates Firestore client and encryption key.
type DatabaseService struct {
	client        *firestore.Client
	encryptionKey []byte // Store the raw key bytes
}

// --- Initialization ---

// NewDatabaseService creates a new service instance with Firestore client and decoded encryption key.
// It also initializes the Firestore client itself from the Firebase App.
//
// Args:
//
//	ctx (context.Context): The context for initialization.
//	app (*firebase.App): The initialized Firebase App instance.
//	encryptionKey ([]byte): The raw encryption key bytes.
//
// Returns:
//
//	(*DatabaseService, error): The database service instance or an error.
func NewDatabaseService(client *firestore.Client, encryptionKey []byte) (*DatabaseService, error) {
	if len(encryptionKey) != 32 {
		return nil, fmt.Errorf("invalid encryption key length: expected 32 bytes, got %d", len(encryptionKey))
	}
	return &DatabaseService{
		client:        client,
		encryptionKey: encryptionKey,
	}, nil
}

// InitializeFirestoreClient creates and returns a Firestore client from a Firebase App instance.
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
		log.Errorf("Failed to get Firestore client: %v", err)
		return nil, fmt.Errorf("failed to initialize Firestore client: %w", err)
	}
	log.Info("Firestore client initialized successfully.")
	return firestoreClient, nil
}

// --- Firestore Operations (Methods on DatabaseService) ---

// StorePlaidItem saves Plaid item details for a user in Firestore, encrypting the access token.
//
// Args:
//
//	ctx (context.Context): The context for the Firestore operation.
//	userID (string): The Firebase Authentication UID of the user.
//	itemID (string): The Plaid Item ID, used as the document ID.
//	accessToken (string): The raw Plaid access token to be encrypted.
//
// Returns:
//
//	error: An error if the operation fails, otherwise nil.
func (s *DatabaseService) StorePlaidItem(ctx context.Context, userID, itemID, accessToken string) error {
	logFields := log.Fields{"userID": userID, "itemID": itemID}
	log.WithFields(logFields).Info("Storing Plaid item details in Firestore...")

	// Encrypt the access token using the service's key
	encryptedToken, err := encryption.Encrypt(accessToken, s.encryptionKey)
	if err != nil {
		log.WithFields(logFields).Errorf("Failed to encrypt access token: %v", err)
		return fmt.Errorf("failed to prepare item data for storage: %w", err)
	}
	log.WithFields(logFields).Debug("Access token encrypted.")

	itemData := PlaidItem{
		UserID:               userID,
		EncryptedAccessToken: encryptedToken,
		CreatedAt:            time.Now().UTC(),
	}

	docRef := s.client.Collection(PlaidItemsCollectionName).Doc(itemID)

	_, err = docRef.Set(ctx, itemData)
	if err != nil {
		log.WithFields(logFields).Errorf("Failed to set Plaid item document in Firestore: %v", err)
		return fmt.Errorf("failed to store plaid item: %w", err)
	}

	log.WithFields(logFields).Info("Successfully stored Plaid item in Firestore.")
	return nil
}

// GetUserAccessTokens retrieves and decrypts all Plaid access tokens for a user ID from Firestore.
//
// Args:
//
//	ctx (context.Context): The context for the Firestore operation.
//	userID (string): The Firebase Authentication UID of the user.
//
// Returns:
//
//	([]string, error): A slice of decrypted access tokens and an error if retrieval fails.
func (s *DatabaseService) GetUserAccessTokens(ctx context.Context, userID string) ([]string, error) {
	logFields := log.Fields{"userID": userID}
	log.WithFields(logFields).Info("Retrieving Plaid access tokens from Firestore...")

	var tokens []string
	iter := s.client.Collection(PlaidItemsCollectionName).Where("userId", "==", userID).Documents(ctx)
	defer iter.Stop()

	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			log.WithFields(logFields).Infof("Finished iterating through Plaid items. Found %d token(s).", len(tokens))
			break
		}
		if err != nil {
			log.WithFields(logFields).Errorf("Failed during iteration of Plaid items: %v", err)
			return nil, fmt.Errorf("failed to iterate plaid items: %w", err)
		}

		var item PlaidItem
		if err := doc.DataTo(&item); err != nil {
			log.WithFields(logFields).Warnf("Failed to parse Plaid item document %s: %v", doc.Ref.ID, err)
			continue
		}

		// Decrypt the token using the service's key
		decryptedToken, err := encryption.Decrypt(item.EncryptedAccessToken, s.encryptionKey)
		if err != nil {
			log.WithFields(logFields).Errorf("Failed to decrypt token for item %s: %v", doc.Ref.ID, err)
			// Stop processing and return error immediately if decryption fails
			return nil, fmt.Errorf("failed to decrypt access token for item %s: %w", doc.Ref.ID, err)
			// Depending on policy, you might want to return an error here instead of just skipping.
		}
		log.WithFields(logFields).Debugf("Successfully retrieved and decrypted token for item %s", doc.Ref.ID)
		tokens = append(tokens, decryptedToken)
	}

	return tokens, nil
}

// CloseFirestore closes the underlying Firestore client connection.
// Should be called during graceful server shutdown.
func (s *DatabaseService) CloseFirestore(ctx context.Context) error {
	log.Info("Attempting to close Firestore client connection via DatabaseService...")
	if s.client == nil {
		log.Warn("Firestore client was already nil, cannot close.")
		return nil
	}
	err := s.client.Close()
	if err != nil {
		log.Errorf("Error closing Firestore client: %v", err)
		return err
	}
	log.Info("Firestore client connection closed.")
	s.client = nil // Prevent double closing
	return nil
}

// GetFirestoreClient returns the underlying Firestore client instance.
// This might be needed by handlers for specific queries not covered by service methods.
func (s *DatabaseService) GetFirestoreClient() *firestore.Client {
	return s.client
}
