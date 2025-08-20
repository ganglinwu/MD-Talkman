package services

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"

	"mdtalkman-webhook/models"
)

// GitHubService handles GitHub-specific operations
type GitHubService struct {
	webhookSecret string
}

// NewGitHubService creates a new GitHub service instance
func NewGitHubService(webhookSecret string) *GitHubService {
	return &GitHubService{
		webhookSecret: webhookSecret,
	}
}

// VerifyWebhookSignature verifies the GitHub webhook signature
func (g *GitHubService) VerifyWebhookSignature(payload []byte, signature string) bool {
	// GitHub sends signature as "sha256=<hex_digest>"
	if !strings.HasPrefix(signature, "sha256=") {
		return false
	}
	
	// Remove the "sha256=" prefix
	receivedSignature := strings.TrimPrefix(signature, "sha256=")
	
	// Calculate expected signature
	mac := hmac.New(sha256.New, []byte(g.webhookSecret))
	mac.Write(payload)
	expectedSignature := hex.EncodeToString(mac.Sum(nil))
	
	// Use constant-time comparison to prevent timing attacks
	return hmac.Equal([]byte(receivedSignature), []byte(expectedSignature))
}

// ProcessWebhookEvent processes the webhook payload and returns relevant information
func (g *GitHubService) ProcessWebhookEvent(payload *models.GitHubWebhookPayload, eventType string) *models.WebhookEvent {
	event := &models.WebhookEvent{
		EventType:      eventType,
		RepositoryName: payload.Repository.Name,
		InstallationID: payload.Installation.ID,
		Action:         payload.Action,
	}
	
	// Check for markdown file changes in push events
	if eventType == "push" && len(payload.Commits) > 0 {
		var changedFiles []string
		hasMarkdownChanges := false
		
		for _, commit := range payload.Commits {
			// Collect all changed files
			changedFiles = append(changedFiles, commit.Added...)
			changedFiles = append(changedFiles, commit.Modified...)
			changedFiles = append(changedFiles, commit.Removed...)
			
			// Check for markdown files
			for _, file := range changedFiles {
				if isMarkdownFile(file) {
					hasMarkdownChanges = true
					break
				}
			}
		}
		
		event.HasMarkdownChanges = hasMarkdownChanges
		event.ChangedFiles = removeDuplicates(changedFiles)
	}
	
	return event
}

// isMarkdownFile checks if a file is a markdown file
func isMarkdownFile(filename string) bool {
	lowercaseFile := strings.ToLower(filename)
	return strings.HasSuffix(lowercaseFile, ".md") || strings.HasSuffix(lowercaseFile, ".markdown")
}

// removeDuplicates removes duplicate strings from a slice
func removeDuplicates(slice []string) []string {
	keys := make(map[string]bool)
	result := []string{}
	
	for _, item := range slice {
		if !keys[item] {
			keys[item] = true
			result = append(result, item)
		}
	}
	
	return result
}

// GetWebhookEvents returns the list of events this service handles
func (g *GitHubService) GetWebhookEvents() []string {
	return []string{
		"push",                       // Repository push events
		"installation",               // App installation events
		"installation_repositories",  // Repository access changes
	}
}

// ShouldNotifyApp determines if the iOS app should be notified
func (g *GitHubService) ShouldNotifyApp(event *models.WebhookEvent) bool {
	switch event.EventType {
	case "push":
		// Only notify for markdown file changes
		return event.HasMarkdownChanges
	case "installation":
		// Notify for installation changes (added/removed)
		return event.Action == "created" || event.Action == "deleted"
	case "installation_repositories":
		// Notify for repository access changes
		return event.Action == "added" || event.Action == "removed"
	default:
		return false
	}
}