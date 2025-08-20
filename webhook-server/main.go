package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"mdtalkman-webhook/handlers"
	"mdtalkman-webhook/services"
)

func main() {
	log.Println("🚀 Starting MD TalkMan Webhook Server...")

	// Load configuration from environment variables
	config := loadConfig()
	
	// Initialize services
	githubService := services.NewGitHubService(config.WebhookSecret)
	
	// Initialize APNs service (choose one method)
	var apnsService *services.APNsService
	var err error
	
	if config.APNsKeyPath != "" {
		// Token-based authentication (recommended)
		apnsService, err = services.NewAPNsServiceWithToken(
			config.APNsKeyPath,
			config.APNsKeyID,
			config.APNsTeamID,
			config.BundleID,
			config.IsDevelopment,
		)
	} else if config.APNsCertPath != "" {
		// Certificate-based authentication (legacy)
		apnsService, err = services.NewAPNsService(
			config.APNsCertPath,
			config.BundleID,
			config.IsDevelopment,
		)
	} else {
		log.Fatal("❌ Either APNs key file or certificate file must be provided")
	}
	
	if err != nil {
		log.Fatalf("❌ Failed to initialize APNs service: %v", err)
	}
	
	log.Printf("✅ APNs service initialized (development: %t)", config.IsDevelopment)

	// Initialize handlers
	webhookHandler := handlers.NewWebhookHandler(githubService, apnsService)
	healthHandler := handlers.NewHealthHandler()

	// Set up HTTP routes
	mux := http.NewServeMux()

	// Webhook endpoints
	mux.HandleFunc("/webhook/github", webhookHandler.HandleGitHubWebhook)
	mux.HandleFunc("/webhook/register", webhookHandler.RegisterDevice)
	mux.HandleFunc("/webhook/unregister", webhookHandler.UnregisterDevice)
	mux.HandleFunc("/webhook/status", webhookHandler.GetStatus)

	// Health check endpoints
	mux.HandleFunc("/health", healthHandler.HealthCheck)
	mux.HandleFunc("/ready", healthHandler.ReadinessCheck)

	// Root endpoint
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		fmt.Fprintf(w, `{
	"service": "MD TalkMan Webhook Server",
	"version": "1.0.0",
	"endpoints": {
		"webhook": "/webhook/github",
		"register": "/webhook/register", 
		"unregister": "/webhook/unregister",
		"status": "/webhook/status",
		"health": "/health",
		"ready": "/ready"
	}
}`)
	})

	// Create HTTP server
	server := &http.Server{
		Addr:    fmt.Sprintf(":%s", config.Port),
		Handler: mux,
	}

	// Start server in a goroutine
	go func() {
		log.Printf("🌐 Server starting on port %s", config.Port)
		log.Printf("📍 Webhook endpoint: http://localhost:%s/webhook/github", config.Port)
		log.Printf("🔍 Health check: http://localhost:%s/health", config.Port)
		
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("❌ Server failed to start: %v", err)
		}
	}()

	log.Println("✅ MD TalkMan Webhook Server is running!")
	log.Println("📝 Supported webhook events:", githubService.GetWebhookEvents())

	// Wait for interrupt signal to gracefully shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("🛑 Shutting down server...")
	
	// Graceful shutdown would go here
	// server.Shutdown(ctx)
	
	log.Println("✅ Server stopped")
}

// Config holds all configuration for the webhook server
type Config struct {
	Port           string
	WebhookSecret  string
	BundleID       string
	IsDevelopment  bool
	APNsKeyPath    string
	APNsKeyID      string
	APNsTeamID     string
	APNsCertPath   string
}

// loadConfig loads configuration from environment variables
func loadConfig() *Config {
	config := &Config{
		Port:          getEnv("PORT", "8080"),
		WebhookSecret: getEnv("GITHUB_WEBHOOK_SECRET", ""),
		BundleID:      getEnv("BUNDLE_ID", "ganglinwu.MD-TalkMan"),
		IsDevelopment: getEnv("APNS_DEVELOPMENT", "true") == "true",
		APNsKeyPath:   getEnv("APNS_KEY_PATH", ""),
		APNsKeyID:     getEnv("APNS_KEY_ID", ""),
		APNsTeamID:    getEnv("APNS_TEAM_ID", ""),
		APNsCertPath:  getEnv("APNS_CERT_PATH", ""),
	}

	// Validate required configuration
	if config.WebhookSecret == "" {
		log.Fatal("❌ GITHUB_WEBHOOK_SECRET environment variable is required")
	}

	if config.APNsKeyPath == "" && config.APNsCertPath == "" {
		log.Fatal("❌ Either APNS_KEY_PATH or APNS_CERT_PATH environment variable is required")
	}

	if config.APNsKeyPath != "" && (config.APNsKeyID == "" || config.APNsTeamID == "") {
		log.Fatal("❌ APNS_KEY_ID and APNS_TEAM_ID are required when using APNS_KEY_PATH")
	}

	return config
}

// getEnv gets an environment variable with a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}