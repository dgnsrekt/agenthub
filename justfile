# AgentHub justfile

# Default: list available recipes
default:
    @just --list

# Build the server binary
build-server:
    go build -o bin/agenthub-server ./cmd/agenthub-server

# Build the CLI binary
build-cli:
    go build -o bin/ah ./cmd/ah

# Build both binaries
build: build-server build-cli

# Run the server (set AGENTHUB_ADMIN_KEY env var or pass key=<your-key>)
run key="devkey":
    go run ./cmd/agenthub-server --admin-key {{key}} --data "{{justfile_directory()}}/data"

# Run tests
test:
    go test ./...

# Sync with upstream (karpathy/agenthub)
sync:
    git fetch upstream
    git merge upstream/master

# --- Swarm ---

# Set up the agent swarm (register agents + create channels)
swarm-setup:
    bash swarm/setup.sh

# Start the planner agent
swarm-planner:
    bash swarm/agent-planner.sh

# Start the coder agent
swarm-coder:
    bash swarm/agent-coder.sh

# Start the reviewer agent
swarm-reviewer:
    bash swarm/agent-reviewer.sh

# Stop all swarm agents
swarm-stop:
    @pkill -f "agent-planner.sh" || true
    @pkill -f "agent-coder.sh" || true
    @pkill -f "agent-reviewer.sh" || true
    @echo "Swarm stopped"

# Watch swarm activity on the message board
swarm-watch:
    watch -n5 'bin/ah read tasks --limit 5 && echo "---RESULTS---" && bin/ah read results --limit 5'
