package handlers

import (
	"encoding/json"
	"net/http"
	"time"
)

// HealthHandler provides health check endpoints
type HealthHandler struct {
	startTime time.Time
}

// NewHealthHandler creates a new health handler
func NewHealthHandler() *HealthHandler {
	return &HealthHandler{
		startTime: time.Now(),
	}
}

// HealthCheck returns the health status of the service
func (h *HealthHandler) HealthCheck(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	uptime := time.Since(h.startTime)
	
	response := struct {
		Status    string  `json:"status"`
		Timestamp string  `json:"timestamp"`
		Uptime    string  `json:"uptime"`
		Version   string  `json:"version"`
	}{
		Status:    "healthy",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Uptime:    uptime.String(),
		Version:   "1.0.0",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// ReadinessCheck checks if the service is ready to accept requests
func (h *HealthHandler) ReadinessCheck(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// In a more complex service, you might check database connections,
	// external service availability, etc.
	response := struct {
		Status string `json:"status"`
		Ready  bool   `json:"ready"`
	}{
		Status: "ready",
		Ready:  true,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}