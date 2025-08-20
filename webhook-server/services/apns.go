package services

import (
	"fmt"
	"log"

	"mdtalkman-webhook/models"
)

// APNsService handles Apple Push Notifications (simplified version)
type APNsService struct {
	bundleID     string
	isDevelopment bool
}

// NewAPNsService creates a new APNs service instance (simplified)
func NewAPNsService(certPath, bundleID string, isDevelopment bool) (*APNsService, error) {
	log.Printf("APNs service created (simplified mode) - cert: %s, bundle: %s, dev: %t", 
		certPath, bundleID, isDevelopment)
	
	return &APNsService{
		bundleID:     bundleID,
		isDevelopment: isDevelopment,
	}, nil
}

// NewAPNsServiceWithToken creates APNs service using token-based authentication (simplified)
func NewAPNsServiceWithToken(keyPath, keyID, teamID, bundleID string, isDevelopment bool) (*APNsService, error) {
	log.Printf("APNs service created (simplified mode) - key: %s, keyID: %s, team: %s, bundle: %s, dev: %t", 
		keyPath, keyID, teamID, bundleID, isDevelopment)
	
	return &APNsService{
		bundleID:     bundleID,
		isDevelopment: isDevelopment,
	}, nil
}

// SendNotification sends a push notification to the iOS app (simplified)
func (a *APNsService) SendNotification(deviceToken string, event *models.WebhookEvent) error {
	log.Printf("📱 [SIMPLIFIED] Would send push notification to device %s", maskDeviceToken(deviceToken))
	log.Printf("📱 Event: %s, Repo: %s, Action: %s", event.EventType, event.RepositoryName, event.Action)
	
	// In production, this would send actual APNs notification
	// For now, just log the notification details
	
	return nil
}

// SendBroadcast sends a notification to multiple device tokens (simplified)
func (a *APNsService) SendBroadcast(deviceTokens []string, event *models.WebhookEvent) error {
	if len(deviceTokens) == 0 {
		return fmt.Errorf("no device tokens provided")
	}

	log.Printf("📱 [SIMPLIFIED] Would send push notification to %d devices", len(deviceTokens))
	log.Printf("📱 Event: %s, Repo: %s, Action: %s, HasMarkdown: %t", 
		event.EventType, event.RepositoryName, event.Action, event.HasMarkdownChanges)
	
	for _, token := range deviceTokens {
		log.Printf("📱 Device: %s", maskDeviceToken(token))
	}

	return nil
}

// maskDeviceToken masks a device token for logging (security)
func maskDeviceToken(token string) string {
	if len(token) < 8 {
		return "***"
	}
	return token[:4] + "..." + token[len(token)-4:]
}

// Close closes the APNs connection (simplified)
func (a *APNsService) Close() {
	log.Println("📱 APNs service closed (simplified mode)")
}