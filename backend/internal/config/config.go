package config

import (
	"fmt"
	"os"
	"strconv"

	"github.com/kingpinXD/fit-cp/backend/internal/agent"
)

// Config holds runtime configuration loaded from environment variables once at startup.
type Config struct {
	DatabaseURL        string
	FirebaseProjectID  string
	GoogleAppCredsPath string
	Port               int
	AuthDisabled       bool

	// OpenAIAPIKey is required at startup so missing keys fail fast rather
	// than 500ing the first agent call. OpenAIBaseURL is optional; when empty
	// the SDK uses its default. OpenAIModel is the default model when the
	// request body omits "model".
	OpenAIAPIKey  string
	OpenAIBaseURL string
	OpenAIModel   string
}

// DefaultOpenAIModel is the fallback model when OPENAI_MODEL is unset. It
// re-exports agent.DefaultModel so the env-loading layer doesn't carry its
// own copy.
const DefaultOpenAIModel = agent.DefaultModel

// Load reads required environment variables and returns a Config. Returns an error
// listing every missing required variable so the operator sees the full picture at once.
func Load() (Config, error) {
	cfg := Config{
		DatabaseURL:        os.Getenv("DATABASE_URL"),
		FirebaseProjectID:  os.Getenv("FIREBASE_PROJECT_ID"),
		GoogleAppCredsPath: os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"),
		Port:               8080,
		AuthDisabled:       os.Getenv("AUTH_DISABLED") == "true",
		OpenAIAPIKey:       os.Getenv("OPENAI_API_KEY"),
		OpenAIBaseURL:      os.Getenv("OPENAI_BASE_URL"),
		OpenAIModel:        os.Getenv("OPENAI_MODEL"),
	}
	if cfg.OpenAIModel == "" {
		cfg.OpenAIModel = DefaultOpenAIModel
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
	// Required at startup so /v1/agent/chat fails fast instead of 500ing on
	// the first request. Dev shells set AUTH_DISABLED=true but still need a
	// key to hit OpenAI — there's no equivalent bypass for billing.
	if cfg.OpenAIAPIKey == "" {
		missing = append(missing, "OPENAI_API_KEY")
	}
	if len(missing) > 0 {
		return Config{}, fmt.Errorf("missing required env vars: %v", missing)
	}
	return cfg, nil
}
