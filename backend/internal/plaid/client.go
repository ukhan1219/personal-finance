package plaid

import (
	"fmt"

	"github.com/plaid/plaid-go/v32/plaid"
	log "github.com/sirupsen/logrus"
	"github.com/ukhan1219/glance/backend/internal/config"
)

// InitializePlaidClient initializes the Plaid API client using configuration values.
//
// Args:
//
//	cfg (*config.Config): The application configuration containing Plaid credentials and environment.
//
// Returns:
//
//	(*plaid.APIClient, error): The initialized Plaid API client and an error if initialization fails.
func InitializePlaidClient(cfg *config.Config) (*plaid.APIClient, error) {
	log.Info("Attempting to initialize Plaid client...")
	plaidConfig := plaid.NewConfiguration()
	plaidConfig.AddDefaultHeader("PLAID-CLIENT-ID", cfg.PlaidClientID)
	plaidConfig.AddDefaultHeader("PLAID-SECRET", cfg.PlaidSecret)

	// Determine Plaid environment based on config string
	var plaidEnv plaid.Environment
	switch cfg.PlaidEnv {
	case "sandbox":
		plaidEnv = plaid.Sandbox
	// case "development": // Plaid Go library might not have a specific constant for 'development'
	// 	plaidEnv = plaid.Development // Use if available, otherwise handle as error or map to Sandbox/Production
	case "production":
		plaidEnv = plaid.Production
	default:
		errMsg := fmt.Sprintf("invalid Plaid environment in config: '%s'. Must be 'sandbox' or 'production'", cfg.PlaidEnv)
		log.Error(errMsg)
		return nil, fmt.Errorf(errMsg)
	}
	plaidConfig.UseEnvironment(plaidEnv)

	log.Infof("Plaid client configured for environment: %s", cfg.PlaidEnv)
	client := plaid.NewAPIClient(plaidConfig)
	if client == nil {
		errMsg := "Failed to create Plaid API client (NewAPIClient returned nil)"
		log.Error(errMsg)
		return nil, fmt.Errorf(errMsg)
	}

	log.Info("Plaid client initialized successfully.")
	return client, nil
}
