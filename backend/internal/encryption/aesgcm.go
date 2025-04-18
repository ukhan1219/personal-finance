/**
 * @file aesgcm.go
 * @brief Provides AES-GCM encryption and decryption utilities.
 */

package encryption

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"io"

	log "github.com/sirupsen/logrus"
)

// Encrypt encrypts plaintext using AES-GCM with the provided key.
// The key must be 16, 24, or 32 bytes long (AES-128, AES-192, or AES-256).
// The output is a Base64 encoded string containing the nonce prepended to the ciphertext.
//
// Args:
//
//	plaintext (string): The data to encrypt.
//	key ([]byte): The AES encryption key.
//
// Returns:
//
//	(string, error): The Base64 encoded nonce+ciphertext, or an error.
func Encrypt(plaintext string, key []byte) (string, error) {
	log.Debug("Encrypting data...")
	block, err := aes.NewCipher(key)
	if err != nil {
		log.Errorf("Failed to create AES cipher block: %v", err)
		return "", fmt.Errorf("failed to create cipher block: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		log.Errorf("Failed to create GCM: %v", err)
		return "", fmt.Errorf("failed to create GCM: %w", err)
	}

	// Never use more than 2^32 random nonces with a given key because of the risk of repeat.
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		log.Errorf("Failed to generate nonce: %v", err)
		return "", fmt.Errorf("failed to generate nonce: %w", err)
	}

	// Seal encrypts the plaintext and authenticates the nonce.
	// The nonce is prepended to the ciphertext output.
	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil) // Prepend nonce

	encodedCiphertext := base64.StdEncoding.EncodeToString(ciphertext)
	log.Debug("Data encrypted successfully.")
	return encodedCiphertext, nil
}

// Decrypt decrypts a Base64 encoded string (nonce+ciphertext) using AES-GCM.
// The key must be the same one used for encryption.
//
// Args:
//
//	encodedCiphertext (string): The Base64 encoded string containing nonce+ciphertext.
//	key ([]byte): The AES decryption key.
//
// Returns:
//
//	(string, error): The original plaintext, or an error.
func Decrypt(encodedCiphertext string, key []byte) (string, error) {
	log.Debug("Decrypting data...")
	ciphertext, err := base64.StdEncoding.DecodeString(encodedCiphertext)
	if err != nil {
		log.Errorf("Failed to decode base64 ciphertext: %v", err)
		return "", fmt.Errorf("failed to decode base64 ciphertext: %w", err)
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		log.Errorf("Failed to create AES cipher block during decryption: %v", err)
		return "", fmt.Errorf("failed to create cipher block: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		log.Errorf("Failed to create GCM during decryption: %v", err)
		return "", fmt.Errorf("failed to create GCM: %w", err)
	}

	nonceSize := gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		log.Error("Ciphertext is too short (missing nonce)")
		return "", fmt.Errorf("ciphertext too short")
	}

	// Extract nonce and actual ciphertext
	nonce, actualCiphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]

	plaintextBytes, err := gcm.Open(nil, nonce, actualCiphertext, nil)
	if err != nil {
		// This indicates either the key is wrong or the ciphertext has been tampered with.
		log.Errorf("Failed to open GCM (decryption/authentication failed): %v", err)
		return "", fmt.Errorf("failed to decrypt/authenticate data: %w", err)
	}

	log.Debug("Data decrypted successfully.")
	return string(plaintextBytes), nil
}
