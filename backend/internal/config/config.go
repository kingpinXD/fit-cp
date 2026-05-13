package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds runtime configuration loaded from environment variables once at startup.
type Config struct {
	DatabaseURL           string
	FirebaseProjectID     string
	GoogleAppCredsPath    string
	Port                  int
	AuthDisabled          bool
}

// Load reads required environment variables and returns a Config. Returns an error
// listing every missing required variable so the operator sees the full picture at once.
func Load() (Config, error) {
	cfg := Config{
		DatabaseURL:        os.Getenv("DATABASE_URL"),
		FirebaseProjectID:  os.Getenv("FIREBASE_PROJECT_ID"),
		GoogleAppCredsPath: os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"),
		Port:               8080,
		AuthDisabled:       os.Getenv("AUTH_DISABLED") == "true",
	}

	if portStr := os.Getenv("PORT"); portStr != "" {
		p, err := strconv.Atoi(portStr)
		if err != nil {
			return Config{}, fmt.Errorf("PORT must be an integer: %w", err)
		}
		cfg.Port = p
	}

	var missing []string
	if cfg.DatabaseURL == "" {
		missing = append(missing, "DATABASE_URL")
	}
	// FIREBASE_PROJECT_ID is required even when AUTH_DISABLED so the Firebase client
	// can still be wired up consistently; the middleware skips verification only.
	if cfg.FirebaseProjectID == "" && !cfg.AuthDisabled {
		missing = append(missing, "FIREBASE_PROJECT_ID")
	}
	if len(missing) > 0 {
		return Config{}, fmt.Errorf("missing required env vars: %v", missing)
	}
	return cfg, nil
}
