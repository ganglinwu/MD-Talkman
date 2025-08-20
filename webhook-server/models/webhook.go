package models

import "time"

// GitHubWebhookPayload represents the structure of GitHub webhook payloads
type GitHubWebhookPayload struct {
	Action       string       `json:"action,omitempty"`
	Repository   Repository   `json:"repository"`
	Installation Installation `json:"installation"`
	Pusher       User         `json:"pusher,omitempty"`
	Sender       User         `json:"sender"`
	Ref          string       `json:"ref,omitempty"`
	Commits      []Commit     `json:"commits,omitempty"`
}

// Repository represents a GitHub repository
type Repository struct {
	ID       int    `json:"id"`
	Name     string `json:"name"`
	FullName string `json:"full_name"`
	Private  bool   `json:"private"`
	HTMLURL  string `json:"html_url"`
	CloneURL string `json:"clone_url"`
}

// Installation represents a GitHub App installation
type Installation struct {
	ID      int `json:"id"`
	Account User `json:"account"`
}

// User represents a GitHub user or organization
type User struct {
	ID       int    `json:"id"`
	Login    string `json:"login"`
	Type     string `json:"type"`
	HTMLURL  string `json:"html_url"`
	AvatarURL string `json:"avatar_url"`
}

// Commit represents a Git commit
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