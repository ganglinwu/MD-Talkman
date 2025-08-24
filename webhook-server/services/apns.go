package services

import (
	"fmt"
	"log"

	"github.com/sideshow/apns2"
	"github.com/sideshow/apns2/token"
	"mdtalkman-webhook/models"
)

// APNsService handles Apple Push Notifications
type APNsService struct {
	client        *apns2.Client
	bundleID      string
	isDevelopment bool
	token         *token.Token
}

// NewAPNsService creates a new APNs service instance with certificate authentication
func NewAPNsService(certPath, bundleID string, isDevelopment bool) (*APNsService, error) {
	if certPath == "" {
		// Return simplified service if no cert path
		log.Printf("APNs service created (simplified mode) - cert: %s, bundle: %s, dev: %t", 
			certPath, bundleID, isDevelopment)
		
		return &APNsService{
			bundleID:      bundleID,
			isDevelopment: isDevelopment,
		}, nil
	}
	
	log.Printf("APNs service created (cert mode) - cert: %s, bundle: %s, dev: %t", 
		certPath, bundleID, isDevelopment)
	
	// TODO: Implement certificate-based APNs when needed
	return nil, fmt.Errorf("certificate-based APNs not implemented yet")
}

// NewAPNsServiceWithToken creates APNs service using token-based authentication
func NewAPNsServiceWithToken(keyPath, keyID, teamID, bundleID string, isDevelopment bool) (*APNsService, error) {
	log.Printf("🔑 Initializing APNs with token-based authentication...")
	log.Printf("📱 Key: %s, KeyID: %s, Team: %s, Bundle: %s, Dev: %t", 
		maskPath(keyPath), keyID, teamID, bundleID, isDevelopment)
	
	// Load the private key from file
	privateKey, err := token.AuthKeyFromFile(keyPath)
	if err != nil {
		return nil, fmt.Errorf("failed to load APNs private key: %w", err)
	}
	
	// Create token
	token := &token.Token{
		AuthKey: privateKey,
		KeyID:   keyID,
		TeamID:  teamID,
	}
	
	// Create APNs client
	var client *apns2.Client
	if isDevelopment {
		client = apns2.NewTokenClient(token).Development()
		log.Println("📱 Using APNs development environment")
	} else {
		client = apns2.NewTokenClient(token).Production()
		log.Println("📱 Using APNs production environment")
	}
	
	return &APNsService{
		client:        client,
		bundleID:      bundleID,
		isDevelopment: isDevelopment,
		token:         token,
	}, nil
}

// SendNotification sends a push notification to the iOS app
func (a *APNsService) SendNotification(deviceToken string, event *models.WebhookEvent) error {
	if a.client == nil {
		// Simplified mode - just log
		log.Printf("📱 [SIMPLIFIED] Would send push notification to device %s", maskDeviceToken(deviceToken))
		log.Printf("📱 Event: %s, Repo: %s, Action: %s", event.EventType, event.RepositoryName, event.Action)
		return nil
	}
	
	// Create notification payload
	payload := createNotificationPayload(event)
	
	// Create notification
	notification := &apns2.Notification{
		DeviceToken: deviceToken,
		Topic:       a.bundleID,
		Payload:     payload,
		Priority:    apns2.PriorityHigh,
	}
	
	// Send notification
	log.Printf("📱 Sending push notification to device %s", maskDeviceToken(deviceToken))
	log.Printf("📱 Event: %s, Repo: %s, HasMarkdown: %t", event.EventType, event.RepositoryName, event.HasMarkdownChanges)
	
	response, err := a.client.Push(notification)
	if err != nil {
		return fmt.Errorf("failed to send APNs notification: %w", err)
	}
	
	if response.StatusCode != 200 {
		log.Printf("⚠️ APNs response: %d - %s (ID: %s)", response.StatusCode, response.Reason, response.ApnsID)
		return fmt.Errorf("APNs returned non-200 status: %d - %s", response.StatusCode, response.Reason)
	}
	
	log.Printf("✅ Push notification sent successfully (ID: %s)", response.ApnsID)
	return nil
}

// SendBroadcast sends a notification to multiple device tokens
func (a *APNsService) SendBroadcast(deviceTokens []string, event *models.WebhookEvent) error {
	if len(deviceTokens) == 0 {
		return fmt.Errorf("no device tokens provided")
	}

	log.Printf("📱 Sending push notification to %d devices", len(deviceTokens))
	log.Printf("📱 Event: %s, Repo: %s, Action: %s, HasMarkdown: %t", 
		event.EventType, event.RepositoryName, event.Action, event.HasMarkdownChanges)
	
	var errors []error
	successCount := 0
	
	for _, deviceToken := range deviceTokens {
		err := a.SendNotification(deviceToken, event)
		if err != nil {
			log.Printf("❌ Failed to send to device %s: %v", maskDeviceToken(deviceToken), err)
			errors = append(errors, fmt.Errorf("device %s: %w", maskDeviceToken(deviceToken), err))
		} else {
			successCount++
		}
	}
	
	log.Printf("📱 Broadcast complete: %d/%d devices successful", successCount, len(deviceTokens))
	
	if len(errors) > 0 {
		return fmt.Errorf("failed to send to %d devices: %v", len(errors), errors)
	}
	
	return nil
}

// createNotificationPayload creates the APNs notification payload
func createNotificationPayload(event *models.WebhookEvent) []byte {
	// Create notification title and body based on event
	title := "Repository Updated"
	body := fmt.Sprintf("%s repository has been updated", event.RepositoryName)
	
	if event.HasMarkdownChanges {
		title = "Markdown Files Updated"
		body = fmt.Sprintf("New markdown content available in %s", event.RepositoryName)
	}
	
	// APNs payload format
	payload := fmt.Sprintf(`{
		"aps": {
			"alert": {
				"title": "%s",
				"body": "%s"
			},
			"sound": "default",
			"badge": 1,
			"content-available": 1
		},
		"repository": "%s",
		"event_type": "%s",
		"has_markdown": %t
	}`, title, body, event.RepositoryName, event.EventType, event.HasMarkdownChanges)
	
	return []byte(payload)
}

// maskDeviceToken masks a device token for logging (security)
func maskDeviceToken(token string) string {
	if len(token) < 8 {
		return "***"
	}
	return token[:4] + "..." + token[len(token)-4:]
}

// maskPath masks a file path for logging (security)
func maskPath(path string) string {
	if path == "" {
		return "<empty>"
	}
	// Just show the filename, not the full path
	if lastSlash := len(path) - 1; lastSlash >= 0 {
		for i := lastSlash; i >= 0; i-- {
			if path[i] == '/' {
				return "..." + path[i:]
			}
		}
	}
	return path
}

// Close closes the APNs connection
func (a *APNsService) Close() {
	if a.client != nil {
		log.Println("📱 APNs service closed")
		// The apns2 client doesn't need explicit closing
	} else {
		log.Println("📱 APNs service closed (simplified mode)")
	}
}