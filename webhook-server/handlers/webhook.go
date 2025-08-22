package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"

	"mdtalkman-webhook/models"
	"mdtalkman-webhook/services"
)

// WebhookHandler handles GitHub webhook requests
type WebhookHandler struct {
	githubService *services.GitHubService
	apnsService   *services.APNsService
	deviceTokens  []string // In production, this would be stored in a database
}

// NewWebhookHandler creates a new webhook handler
func NewWebhookHandler(githubService *services.GitHubService, apnsService *services.APNsService) *WebhookHandler {
	return &WebhookHandler{
		githubService: githubService,
		apnsService:   apnsService,
		deviceTokens:  make([]string, 0),
	}
}

// HandleGitHubWebhook handles incoming GitHub webhook requests
func (w *WebhookHandler) HandleGitHubWebhook(rw http.ResponseWriter, req *http.Request) {
	// Only accept POST requests
	if req.Method != http.MethodPost {
		http.Error(rw, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Read the request body
	body, err := io.ReadAll(req.Body)
	if err != nil {
		log.Printf("Error reading request body: %v", err)
		http.Error(rw, "Bad request", http.StatusBadRequest)
		return
	}
	defer req.Body.Close()

	// Get GitHub headers
	signature := req.Header.Get("X-Hub-Signature-256")
	eventType := req.Header.Get("X-GitHub-Event")
	deliveryID := req.Header.Get("X-GitHub-Delivery")

	log.Printf("Received webhook: Event=%s, Delivery=%s", eventType, deliveryID)

	// Verify the webhook signature (skip if testing without signature)
	if signature != "" && !w.githubService.VerifyWebhookSignature(body, signature) {
		log.Printf("Invalid webhook signature for delivery %s", deliveryID)
		http.Error(rw, "Unauthorized", http.StatusUnauthorized)
		return
	}
	
	if signature == "" {
		log.Printf("Warning: No signature provided for delivery %s (testing mode)", deliveryID)
	}

	// Parse the webhook payload
	var payload models.GitHubWebhookPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		log.Printf("Error parsing webhook payload: %v", err)
		http.Error(rw, "Bad request", http.StatusBadRequest)
		return
	}

	// Process the webhook event
	event := w.githubService.ProcessWebhookEvent(&payload, eventType)
	
	log.Printf("Processed event: Type=%s, Repo=%s, Action=%s, HasMarkdown=%t", 
		event.EventType, event.RepositoryName, event.Action, event.HasMarkdownChanges)

	// Check if we should notify the iOS app
	if w.githubService.ShouldNotifyApp(event) && len(w.deviceTokens) > 0 {
		log.Printf("Sending push notification for event: %s", event.EventType)
		
		if err := w.apnsService.SendBroadcast(w.deviceTokens, event); err != nil {
			log.Printf("Error sending push notifications: %v", err)
			// Don't return error to GitHub - we still processed the webhook successfully
		} else {
			log.Printf("Successfully sent push notifications to %d devices", len(w.deviceTokens))
		}
	} else {
		log.Printf("Skipping notification: ShouldNotify=%t, DeviceTokens=%d", 
			w.githubService.ShouldNotifyApp(event), len(w.deviceTokens))
	}

	// Respond to GitHub
	rw.WriteHeader(http.StatusOK)
	fmt.Fprintf(rw, `{"status": "success", "message": "Webhook processed"}`)
}

// RegisterDevice registers a device token for push notifications
func (w *WebhookHandler) RegisterDevice(rw http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		http.Error(rw, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var requestBody struct {
		DeviceToken string `json:"device_token"`
	}

	if err := json.NewDecoder(req.Body).Decode(&requestBody); err != nil {
		log.Printf("Error parsing device registration: %v", err)
		http.Error(rw, "Bad request", http.StatusBadRequest)
		return
	}

	deviceToken := strings.TrimSpace(requestBody.DeviceToken)
	if deviceToken == "" {
		http.Error(rw, "Device token required", http.StatusBadRequest)
		return
	}

	// Check if device token already exists
	for _, token := range w.deviceTokens {
		if token == deviceToken {
			log.Printf("Device token already registered: %s", maskToken(deviceToken))
			rw.WriteHeader(http.StatusOK)
			fmt.Fprintf(rw, `{"status": "already_registered"}`)
			return
		}
	}

	// Add the device token
	w.deviceTokens = append(w.deviceTokens, deviceToken)
	log.Printf("Registered new device token: %s", maskToken(deviceToken))

	rw.WriteHeader(http.StatusOK)
	fmt.Fprintf(rw, `{"status": "registered", "total_devices": %d}`, len(w.deviceTokens))
}

// UnregisterDevice removes a device token from push notifications
func (w *WebhookHandler) UnregisterDevice(rw http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		http.Error(rw, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var requestBody struct {
		DeviceToken string `json:"device_token"`
	}

	if err := json.NewDecoder(req.Body).Decode(&requestBody); err != nil {
		http.Error(rw, "Bad request", http.StatusBadRequest)
		return
	}

	deviceToken := strings.TrimSpace(requestBody.DeviceToken)
	if deviceToken == "" {
		http.Error(rw, "Device token required", http.StatusBadRequest)
		return
	}

	// Remove the device token
	for i, token := range w.deviceTokens {
		if token == deviceToken {
			w.deviceTokens = append(w.deviceTokens[:i], w.deviceTokens[i+1:]...)
			log.Printf("Unregistered device token: %s", maskToken(deviceToken))
			rw.WriteHeader(http.StatusOK)
			fmt.Fprintf(rw, `{"status": "unregistered", "total_devices": %d}`, len(w.deviceTokens))
			return
		}
	}

	log.Printf("Device token not found for unregistration: %s", maskToken(deviceToken))
	rw.WriteHeader(http.StatusOK)
	fmt.Fprintf(rw, `{"status": "not_found"}`)
}

// GetStatus returns the current status of the webhook handler
func (w *WebhookHandler) GetStatus(rw http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		http.Error(rw, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	status := struct {
		Status           string   `json:"status"`
		RegisteredDevices int     `json:"registered_devices"`
		SupportedEvents   []string `json:"supported_events"`
	}{
		Status:           "healthy",
		RegisteredDevices: len(w.deviceTokens),
		SupportedEvents:   w.githubService.GetWebhookEvents(),
	}

	rw.Header().Set("Content-Type", "application/json")
	json.NewEncoder(rw).Encode(status)
}

// maskToken masks a device token for logging
func maskToken(token string) string {
	if len(token) < 8 {
		return "***"
	}
	return token[:4] + "..." + token[len(token)-4:]
}