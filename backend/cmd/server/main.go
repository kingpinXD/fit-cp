package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kingpinXD/fit-cp/backend/internal/auth"
	"github.com/kingpinXD/fit-cp/backend/internal/config"
	"github.com/kingpinXD/fit-cp/backend/internal/httpx"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	if err := run(); err != nil {
		logger.Error("server exited with error", "err", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("connect db: %w", err)
	}
	defer pool.Close()

	authMW, err := buildAuthMiddleware(ctx, cfg)
	if err != nil {
		return fmt.Errorf("init auth: %w", err)
	}

	srv := &http.Server{
		Addr:              fmt.Sprintf(":%d", cfg.Port),
		Handler:           httpx.NewRouter(httpx.RouterDeps{Pool: pool, AuthMW: authMW}),
		ReadHeaderTimeout: 10 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		slog.Info("server listening", "port", cfg.Port, "auth_disabled", cfg.AuthDisabled)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
		close(errCh)
	}()

	select {
	case <-ctx.Done():
		slog.Info("shutdown signal received")
	case err := <-errCh:
		if err != nil {
			return fmt.Errorf("listen: %w", err)
		}
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("shutdown: %w", err)
	}
	slog.Info("server stopped")
	return nil
}

func buildAuthMiddleware(ctx context.Context, cfg config.Config) (func(http.Handler) http.Handler, error) {
	if cfg.AuthDisabled {
		slog.Warn("AUTH_DISABLED=true — all /v1 requests will be served as uid=dev")
		return auth.DisabledMiddleware(), nil
	}
	verifier, err := auth.NewFirebaseVerifier(ctx, cfg.FirebaseProjectID, cfg.GoogleAppCredsPath)
	if err != nil {
		return nil, err
	}
	return auth.Middleware(verifier), nil
}
