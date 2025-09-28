#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_REPLICAS=2
DEFAULT_PROFILE="default"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if .env file exists
check_env_file() {
    if [ ! -f ".env" ]; then
        print_error ".env file not found!"
        echo "Please create a .env file with your GitHub configuration."
        echo "You can copy .env.example and modify it:"
        echo "  cp .env.example .env"
        exit 1
    fi
    
    # Source the .env file to check required variables
    source .env
    
    if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_TOKEN" ]; then
        print_error "Required environment variables missing!"
        echo "Please ensure GITHUB_OWNER and GITHUB_TOKEN are set in .env"
        exit 1
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
GitHub Runner Manager

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  start [replicas]     Start runners (default: $DEFAULT_REPLICAS)
  stop                 Stop all runners
  restart [replicas]   Restart runners with optional replica count
  scale <replicas>     Scale runners to specific count
  status              Show runner status
  logs [service]       Show logs (default: all services)
  clean               Clean up stopped containers and volumes
  profiles            List available profiles

Profiles:
  default             Basic runners only
  enhanced            Include enhanced runners with extra tools
  cache              Include Docker registry cache
  monitoring         Include Portainer dashboard
  all                Include all services

Examples:
  $0 start 5                    # Start 5 basic runners
  $0 start 3 --profile enhanced # Start 3 enhanced runners
  $0 scale 10                   # Scale to 10 runners
  $0 logs github-runner         # Show runner logs
  $0 clean                      # Clean up resources

Environment Variables (set in .env):
  GITHUB_OWNER        GitHub username or organization (required)
  GITHUB_TOKEN        GitHub Personal Access Token (required)
  GITHUB_REPOSITORY   Repository name (optional, for repo runners)
  RUNNER_LABELS       Custom labels (optional)
  RUNNER_NAME_PREFIX  Runner name prefix (optional)
EOF
}

# Function to get compose command with profiles
get_compose_cmd() {
    local profiles="$1"
    local cmd="docker-compose"
    
    if [ -n "$profiles" ]; then
        IFS=',' read -ra PROFILE_ARRAY <<< "$profiles"
        for profile in "${PROFILE_ARRAY[@]}"; do
            cmd="$cmd --profile $profile"
        done
    fi
    
    echo "$cmd"
}

# Function to start runners
start_runners() {
    local replicas=${1:-$DEFAULT_REPLICAS}
    local profiles=${2:-}
    
    print_status "Starting $replicas GitHub runners..."
    
    check_env_file
    
    local compose_cmd=$(get_compose_cmd "$profiles")
    
    # Scale the service
    eval "$compose_cmd up -d --scale github-runner=$replicas"
    
    if [ $? -eq 0 ]; then
        print_success "Runners started successfully!"
        print_status "Waiting for runners to register..."
        sleep 10
        show_status
    else
        print_error "Failed to start runners"
        exit 1
    fi
}

# Function to stop runners
stop_runners() {
    print_status "Stopping all runners..."
    
    docker-compose down
    
    if [ $? -eq 0 ]; then
        print_success "All runners stopped"
    else
        print_error "Failed to stop runners"
        exit 1
    fi
}

# Function to restart runners
restart_runners() {
    local replicas=${1:-$DEFAULT_REPLICAS}
    local profiles=${2:-}
    
    print_status "Restarting runners..."
    stop_runners
    sleep 5
    start_runners "$replicas" "$profiles"
}

# Function to scale runners
scale_runners() {
    local replicas=$1
    
    if [ -z "$replicas" ]; then
        print_error "Please specify number of replicas"
        echo "Usage: $0 scale <replicas>"
        exit 1
    fi
    
    print_status "Scaling to $replicas runners..."
    
    docker-compose up -d --scale github-runner=$replicas
    
    if [ $? -eq 0 ]; then
        print_success "Scaled to $replicas runners"
        show_status
    else
        print_error "Failed to scale runners"
        exit 1
    fi
}

# Function to show status
show_status() {
    print_status "Runner Status:"
    echo
    
    # Docker Compose status
    docker-compose ps
    echo
    
    # Resource usage
    print_status "Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
        $(docker-compose ps -q) 2>/dev/null || echo "No running containers"
    echo
    
    # Count active runners
    local active_runners=$(docker-compose ps -q github-runner 2>/dev/null | wc -l)
    print_status "Active Runners: $active_runners"
}

# Function to show logs
show_logs() {
    local service=${1:-}
    
    if [ -n "$service" ]; then
        print_status "Showing logs for $service..."
        docker-compose logs -f "$service"
    else
        print_status "Showing logs for all services..."
        docker-compose logs -f
    fi
}

# Function to clean up
cleanup() {
    print_status "Cleaning up resources..."
    
    # Stop and remove containers
    docker-compose down -v
    
    # Remove unused images and volumes
    docker system prune -f
    docker volume prune -f
    
    print_success "Cleanup completed"
}

# Function to list profiles
list_profiles() {
    print_status "Available Profiles:"
    echo
    echo "  default     - Basic GitHub runners with Docker support"
    echo "  enhanced    - Runners with additional tools (AWS CLI, kubectl, etc.)"
    echo "  cache       - Docker registry cache for faster builds"
    echo "  monitoring  - Portainer dashboard for container management"
    echo "  all         - All services enabled"
    echo
    echo "Usage examples:"
    echo "  $0 start 3 --profile enhanced"
    echo "  $0 start 2 --profile enhanced,cache"
    echo "  $0 start 5 --profile all"
}

# Main script logic
main() {
    case "${1:-}" in
        start)
            shift
            local replicas=$1
            local profiles=""
            
            # Parse additional arguments
            shift
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --profile)
                        profiles="$2"
                        shift 2
                        ;;
                    *)
                        print_error "Unknown option: $1"
                        exit 1
                        ;;
                esac
            done
            
            start_runners "$replicas" "$profiles"
            ;;
        stop)
            stop_runners
            ;;
        restart)
            shift
            local replicas=$1
            local profiles=""
            
            shift
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --profile)
                        profiles="$2"
                        shift 2
                        ;;
                    *)
                        print_error "Unknown option: $1"
                        exit 1
                        ;;
                esac
            done
            
            restart_runners "$replicas" "$profiles"
            ;;
        scale)
            scale_runners "$2"
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "$2"
            ;;
        clean)
            cleanup
            ;;
        profiles)
            list_profiles
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Unknown command: ${1:-}"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"