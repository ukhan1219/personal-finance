package config

import (
	"fmt"
	"os"
	"strconv"

	"github.com/joho/godotenv"
	log "github.com/sirupsen/logrus" // Using logrus for structured logging
)

// Config holds application configuration values loaded from the environment.
type Config struct {
	Port                string
	PlaidClientID       string
	PlaidSecret         string
	PlaidEnv            string // e.g., "sandbox", "development", "production"
	FirebaseCredentials string // Path to Firebase service account key
	// Add other config fields as needed, e.g., JWT secret, encryption keys
}

// Load reads configuration from environment variables.
// It first attempts to load a .env file if present.
//
// Returns:
//
//	(*Config, error): A pointer to the loaded Config struct and an error if loading fails.
func Load() (*Config, error) {
	// Attempt to load .env file - useful for local development
	// In production, environment variables should be set directly.
	err := godotenv.Load() // Load from .env in the current directory (backend/)
	if err != nil {
		log.Warn("No .env file found or error loading it, relying solely on environment variables. Error: ", err)
	} else {
		log.Info("Loaded configuration from .env file")
	}

	cfg := &Config{}
	requiredVars := map[string]*string{
		"PORT":                 &cfg.Port,
		"PLAID_CLIENT_ID":      &cfg.PlaidClientID,
		"PLAID_SECRET":         &cfg.PlaidSecret,
		"PLAID_ENV":            &cfg.PlaidEnv,
		"FIREBASE_CREDENTIALS": &cfg.FirebaseCredentials,
	}

	// Load required variables
	for key, pointer := range requiredVars {
		value := os.Getenv(key)
		if value == "" {
			errMsg := fmt.Sprintf("Missing required environment variable: %s", key)
			log.Error(errMsg)
			return nil, fmt.Errorf(errMsg)
		}
		*pointer = value
		log.Debugf("Loaded env var %s", key) // Don't log secrets in production
	}

	// Validate and parse specific fields
	_, err = strconv.Atoi(cfg.Port)
	if err != nil {
		errMsg := fmt.Sprintf("Invalid PORT value: %s, must be a number", cfg.Port)
		log.Error(errMsg)
		return nil, fmt.Errorf(errMsg)
	}

	// Validate Plaid Env string
	switch cfg.PlaidEnv {
	case "sandbox", "development", "production":
		// Valid environment string
		log.Debugf("Plaid environment set to: %s", cfg.PlaidEnv)
	default:
		errMsg := fmt.Sprintf("Invalid PLAID_ENV value: %s, must be 'sandbox', 'development', or 'production'", cfg.PlaidEnv)
		log.Error(errMsg)
		return nil, fmt.Errorf(errMsg)
	}

	log.Infof("Configuration loaded successfully. Port: %s, Plaid Env: %s", cfg.Port, cfg.PlaidEnv)

	// Validate Firebase credentials file exists (optional basic check)
	if _, err := os.Stat(cfg.FirebaseCredentials); os.IsNotExist(err) {
		log.Warnf("Firebase credentials file not found at path specified by FIREBASE_CREDENTIALS: %s", cfg.FirebaseCredentials)
		// Depending on deployment, this might be acceptable if credentials are handled differently (e.g., GCP service account)
		// Return nil, fmt.Errorf("firebase credentials file not found: %s", cfg.FirebaseCredentials) // Uncomment to make it a hard error
	}

	return cfg, nil
}
