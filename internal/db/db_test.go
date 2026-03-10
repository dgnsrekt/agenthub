package db

import (
	"testing"
)

func setupTestDB(t *testing.T) *DB {
	t.Helper()
	d, err := Open(":memory:")
	if err != nil {
		t.Fatalf("Open(:memory:): %v", err)
	}
	if err := d.Migrate(); err != nil {
		t.Fatalf("Migrate: %v", err)
	}
	t.Cleanup(func() { d.Close() })
	return d
}

func TestCreateAgent(t *testing.T) {
	d := setupTestDB(t)

	if err := d.CreateAgent("agent-1", "key-1"); err != nil {
		t.Fatalf("CreateAgent: %v", err)
	}

	// Duplicate ID should fail.
	if err := d.CreateAgent("agent-1", "key-2"); err == nil {
		t.Fatal("expected error on duplicate agent ID")
	}

	// Duplicate API key should fail.
	if err := d.CreateAgent("agent-2", "key-1"); err == nil {
		t.Fatal("expected error on duplicate API key")
	}
}

func TestGetAgentByAPIKey(t *testing.T) {
	d := setupTestDB(t)

	// Not found returns nil, nil.
	a, err := d.GetAgentByAPIKey("nonexistent")
	if err != nil {
		t.Fatalf("GetAgentByAPIKey: %v", err)
	}
	if a != nil {
		t.Fatal("expected nil for nonexistent key")
	}

	d.CreateAgent("agent-1", "key-1")

	a, err = d.GetAgentByAPIKey("key-1")
	if err != nil {
		t.Fatalf("GetAgentByAPIKey: %v", err)
	}
	if a == nil {
		t.Fatal("expected agent, got nil")
	}
	if a.ID != "agent-1" {
		t.Fatalf("expected ID agent-1, got %s", a.ID)
	}
	if a.APIKey != "key-1" {
		t.Fatalf("expected APIKey key-1, got %s", a.APIKey)
	}
}

func TestGetAgentByID(t *testing.T) {
	d := setupTestDB(t)

	// Not found returns nil, nil.
	a, err := d.GetAgentByID("nonexistent")
	if err != nil {
		t.Fatalf("GetAgentByID: %v", err)
	}
	if a != nil {
		t.Fatal("expected nil for nonexistent ID")
	}

	d.CreateAgent("agent-1", "key-1")

	a, err = d.GetAgentByID("agent-1")
	if err != nil {
		t.Fatalf("GetAgentByID: %v", err)
	}
	if a == nil {
		t.Fatal("expected agent, got nil")
	}
	if a.ID != "agent-1" {
		t.Fatalf("expected ID agent-1, got %s", a.ID)
	}
}

func TestCheckRateLimit(t *testing.T) {
	d := setupTestDB(t)
	d.CreateAgent("agent-1", "key-1")

	// No records yet — should be within limit.
	ok, err := d.CheckRateLimit("agent-1", "post", 5)
	if err != nil {
		t.Fatalf("CheckRateLimit: %v", err)
	}
	if !ok {
		t.Fatal("expected within rate limit with no records")
	}

	// Increment up to the limit.
	for i := 0; i < 5; i++ {
		if err := d.IncrementRateLimit("agent-1", "post"); err != nil {
			t.Fatalf("IncrementRateLimit: %v", err)
		}
	}

	// Should now be at/over limit.
	ok, err = d.CheckRateLimit("agent-1", "post", 5)
	if err != nil {
		t.Fatalf("CheckRateLimit: %v", err)
	}
	if ok {
		t.Fatal("expected rate limit exceeded after 5 increments with max 5")
	}

	// Different action should still be within limit.
	ok, err = d.CheckRateLimit("agent-1", "commit", 5)
	if err != nil {
		t.Fatalf("CheckRateLimit: %v", err)
	}
	if !ok {
		t.Fatal("expected within limit for different action")
	}

	// Different agent should still be within limit.
	ok, err = d.CheckRateLimit("agent-2", "post", 5)
	if err != nil {
		t.Fatalf("CheckRateLimit: %v", err)
	}
	if !ok {
		t.Fatal("expected within limit for different agent")
	}
}
