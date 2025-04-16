/**
 * @file types.go
 * @brief Defines shared domain types used across the backend application.
 */

package domain

// SpendingSummary represents the calculated spending totals for different periods.
// Amounts are typically in the smallest currency unit (e.g., cents) or as floats depending on precision needs.
// Using float64 here for simplicity, consider using decimal types for precise financial calculations.
type SpendingSummary struct {
	Today float64 `json:"today"`
	Week  float64 `json:"week"`
	Month float64 `json:"month"`
}

// ExchangePublicTokenRequest defines the expected JSON body for the public token exchange endpoint.
type ExchangePublicTokenRequest struct {
	PublicToken string `json:"public_token" binding:"required"`
}
