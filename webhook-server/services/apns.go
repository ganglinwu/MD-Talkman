package services

import (
	"context"
	"crypto/tls"
	"fmt"
	"log"
	"time"

	"github.com/sideshow/apns2"
	"github.com/sideshow/apns2/certificate"
	"github.com/sideshow/apns2/payload"

	"mdtalkman-webhook/models"
)

// APNsService handles Apple Push Notifications
type APNsService struct {
	client       *apns2.Client
	bundleID     string
	isDevelopment bool
}

// NewAPNsService creates a new APNs service instance
func NewAPNsService(certPath, bundleID string, isDevelopment bool) (*APNsService, error) {
	// Load the certificate
	cert, err := certificate.FromP12File(certPath, "")
	if err != nil {
		return nil, fmt.Errorf("failed to load certificate: %w", err)
	}

	// Create APNs client
	var client *apns2.Client
	if isDevelopment {
		client = apns2.NewClient(cert).Development()
	} else {
		client = apns2.NewClient(cert).Production()
	}

	return &APNsService{
		client:        client,
		bundleID:      bundleID,
		isDevelopment: isDevelopment,
	}, nil
}

// NewAPNsServiceWithToken creates APNs service using token-based authentication
func NewAPNsServiceWithToken(keyPath, keyID, teamID, bundleID string, isDevelopment bool) (*APNsService, error) {
	// Load the authentication token
	authKey, err := certificate.AuthKeyFromFile(keyPath)
	if err != nil {
		return nil, fmt.Errorf("failed to load auth key: %w", err)
	}

	token := &certificate.Token{
		AuthKey: authKey,
		KeyID:   keyID,
		TeamID:  teamID,
	}

	// Create APNs client
	var client *apns2.Client
	if isDevelopment {
		client = apns2.NewTokenClient(token).Development()
	} else {
		client = apns2.NewTokenClient(token).Production()
	}

	return &APNsService{
		client:        client,
		bundleID:      bundleID,
		isDevelopment: isDevelopment,
	}, nil
}

// SendNotification sends a push notification to the iOS app
func (a *APNsService) SendNotification(deviceToken string, event *models.WebhookEvent) error {
	// Create the notification payload
	notification := &apns2.Notification{
		DeviceToken: deviceToken,
		Topic:       a.bundleID,
		Payload:     a.createPayload(event),
		Expiration:  time.Now().Add(24 * time.Hour),
		Priority:    apns2.PriorityHigh,
	}

	// Send the notification
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	res, err := a.client.PushWithContext(ctx, notification)
	if err != nil {
		return fmt.Errorf("failed to send notification: %w", err)
	}

	if res.StatusCode != 200 {
		return fmt.Errorf("APNs returned error: %s (reason: %s)", res.Status, res.Reason)
	}

	log.Printf("Successfully sent notification to device %s", maskDeviceToken(deviceToken))
	return nil
}

// SendBroadcast sends a notification to multiple device tokens
func (a *APNsService) SendBroadcast(deviceTokens []string, event *models.WebhookEvent) error {
	if len(deviceTokens) == 0 {
		return fmt.Errorf("no device tokens provided")
	}

	payload := a.createPayload(event)
	var errors []error

	for _, token := range deviceTokens {
		notification := &apns2.Notification{
			DeviceToken: token,
			Topic:       a.bundleID,
			Payload:     payload,
			Expiration:  time.Now().Add(24 * time.Hour),
			Priority:    apns2.PriorityHigh,
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		res, err := a.client.PushWithContext(ctx, notification)
		cancel()

		if err != nil {
			errors = append(errors, fmt.Errorf("device %s: %w", maskDeviceToken(token), err))
			continue
		}

		if res.StatusCode != 200 {
			errors = append(errors, fmt.Errorf("device %s: APNs error %s (%s)", 
				maskDeviceToken(token), res.Status, res.Reason))
			continue
		}

		log.Printf("Successfully sent notification to device %s", maskDeviceToken(token))
	}

	if len(errors) > 0 {
		return fmt.Errorf("failed to send to %d devices: %v", len(errors), errors)
	}

	return nil
}

// createPayload creates the APNs payload for the webhook event
func (a *APNsService) createPayload(event *models.WebhookEvent) *payload.Payload {
	p := payload.NewPayload()

	// Set badge count
	p.Badge(1)
	p.Sound("default")

	// Create alert based on event type
	switch event.EventType {
	case "push":
		if event.HasMarkdownChanges {
			p.Alert(&payload.Alert{
				Title: "Repository Updated",
				Body:  fmt.Sprintf("New changes in %s", event.RepositoryName),
			})
		}
	case "installation":
		if event.Action == "created" {
			p.Alert(&payload.Alert{
				Title: "GitHub App Installed",
				Body:  "MD TalkMan can now access your repositories",
			})
		} else if event.Action == "deleted" {
			p.Alert(&payload.Alert{
				Title: "GitHub App Removed",
				Body:  "MD TalkMan no longer has repository access",
			})
		}
	case "installation_repositories":
		if event.Action == "added" {
			p.Alert(&payload.Alert{
				Title: "Repository Access Added",
				Body:  fmt.Sprintf("Added access to %s", event.RepositoryName),
			})
		} else if event.Action == "removed" {
			p.Alert(&payload.Alert{
				Title: "Repository Access Removed", 
				Body:  fmt.Sprintf("Removed access to %s", event.RepositoryName),
			})
		}
	}

	// Add custom data for the iOS app
	p.Custom("event_type", event.EventType)
	p.Custom("repository_name", event.RepositoryName)
	p.Custom("installation_id", event.InstallationID)
	p.Custom("action", event.Action)
	
	if event.HasMarkdownChanges {
		p.Custom("has_markdown_changes", true)
		if len(event.ChangedFiles) > 0 {
			p.Custom("changed_files", event.ChangedFiles)
		}
	}

	return p
}

// maskDeviceToken masks a device token for logging (security)
func maskDeviceToken(token string) string {
	if len(token) < 8 {
		return "***"
	}
	return token[:4] + "..." + token[len(token)-4:]
}

// Close closes the APNs connection
func (a *APNsService) Close() {
	if a.client != nil {
		// APNs client doesn't have an explicit close method,
		// but we can set it to nil to help with garbage collection
		a.client = nil
	}
}