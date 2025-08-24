package models

import "time"

// GitHubWebhookPayload represents the structure of GitHub webhook payloads
// Reference: https://docs.github.com/en/developers/webhooks-and-events/webhooks/webhook-events-and-payloads#push
type GitHubWebhookPayload struct {
	Action       string       `json:"action,omitempty"`
	Repository   Repository   `json:"repository"`
	Installation Installation `json:"installation"`
	Pusher       User         `json:"pusher,omitempty"`
	Sender       User         `json:"sender"`
	Ref          string       `json:"ref,omitempty"`
	Commits      []Commit     `json:"commits,omitempty"`
}

// Repository represents a GitHub repository from webhook payload
// The webhook includes the full repository object as documented in the REST API
// Reference: https://docs.github.com/en/rest/repos/repos#get-a-repository
type Repository struct {
	ID       int    `json:"id"`
	Name     string `json:"name"`
	FullName string `json:"full_name"`
	Private  bool   `json:"private"`
	HTMLURL  string `json:"html_url"`
	CloneURL string `json:"clone_url"`
}

// Installation represents a GitHub App installation
// Reference: https://docs.github.com/en/rest/apps/installations#get-an-installation-for-the-authenticated-app
type Installation struct {
	ID      int `json:"id"`
	Account User `json:"account"`
}

// User represents a GitHub user or organization
// Reference: https://docs.github.com/en/rest/users/users#get-a-user
type User struct {
	ID       int    `json:"id"`
	Login    string `json:"login"`
	Type     string `json:"type"`
	HTMLURL  string `json:"html_url"`
	AvatarURL string `json:"avatar_url"`
}

// Commit represents a Git commit
// Reference: https://docs.github.com/en/developers/webhooks-and-events/webhooks/webhook-events-and-payloads#push
type Commit struct {
	ID        string    `json:"id"`
	Message   string    `json:"message"`
	Timestamp time.Time `json:"timestamp"`
	Author    CommitAuthor `json:"author"`
	Added     []string  `json:"added"`
	Modified  []string  `json:"modified"`
	Removed   []string  `json:"removed"`
}

// CommitAuthor represents the author of a commit
// Reference: https://docs.github.com/en/developers/webhooks-and-events/webhooks/webhook-events-and-payloads#push
type CommitAuthor struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Username string `json:"username,omitempty"`
}

// WebhookEvent represents the processed webhook event for iOS app
type WebhookEvent struct {
	EventType      string `json:"event_type"`
	RepositoryName string `json:"repository_name"`
	InstallationID int    `json:"installation_id"`
	Action         string `json:"action"`
	HasMarkdownChanges bool `json:"has_markdown_changes"`
	ChangedFiles   []string `json:"changed_files,omitempty"`
}