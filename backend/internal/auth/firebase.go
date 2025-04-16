package auth

import (
	"context"
	"fmt"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	log "github.com/sirupsen/logrus"
)

// InitializeAuthClient creates and returns a Firebase Authentication client
// from a given Firebase App instance.
//
// Args:
//
//	ctx (context.Context): The context for initialization.
//	app (*firebase.App): The initialized Firebase App instance.
//
// Returns:
//
//	(*auth.Client, error): The Firebase Auth client and an error if initialization fails.
func InitializeAuthClient(ctx context.Context, app *firebase.App) (*auth.Client, error) {
	log.Info("Attempting to initialize Firebase Auth client...")
	authClient, err := app.Auth(ctx)
	if err != nil {
		log.Errorf("Failed to get Firebase Auth client: %v", err)
		return nil, fmt.Errorf("failed to initialize Firebase Auth client: %w", err)
	}
	log.Info("Firebase Auth client initialized successfully.")
	return authClient, nil
}
