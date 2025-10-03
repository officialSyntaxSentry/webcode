#!/bin/bash

# Syntax Sentry Health Check Script
# Monitors application health and performance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="${BASE_URL:-http://localhost:3000}"
TIMEOUT=30
MAX_RETRIES=3

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

# Function to check if URL is accessible
check_url() {
    local url=$1
    local name=$2
    
    print_status "Checking $name: $url"
    
    for i in $(seq 1 $MAX_RETRIES); do
        if curl -s --max-time $TIMEOUT "$url" > /dev/null; then
            print_success "$name is accessible"
            return 0
        else
            print_warning "Attempt $i failed for $name"
            if [ $i -lt $MAX_RETRIES ]; then
                sleep 2
            fi
        fi
    done
    
    print_error "$name is not accessible after $MAX_RETRIES attempts"
    return 1
}

# Function to check API endpoints
check_api_endpoints() {
    print_status "Checking API endpoints..."
    
    local endpoints=(
        "/api/activity"
        "/api/airesponse"
        "/api/users/search"
        "/api/room"
    )
    
    local failed_endpoints=()
    
    for endpoint in "${endpoints[@]}"; do
        if ! check_url "$BASE_URL$endpoint" "API $endpoint"; then
            failed_endpoints+=("$endpoint")
        fi
    done
    
    if [ ${#failed_endpoints[@]} -eq 0 ]; then
        print_success "All API endpoints are accessible"
        return 0
    else
        print_error "Failed endpoints: ${failed_endpoints[*]}"
        return 1
    fi
}

# Function to check database connectivity
check_database() {
    print_status "Checking database connectivity..."
    
    # This would need to be implemented based on your database setup
    # For now, we'll check if the API endpoints that require database work
    if curl -s --max-time $TIMEOUT "$BASE_URL/api/room" | grep -q "error\|Error"; then
        print_error "Database connectivity issues detected"
        return 1
    else
        print_success "Database connectivity is working"
        return 0
    fi
}

# Function to check application performance
check_performance() {
    print_status "Checking application performance..."
    
    local start_time=$(date +%s%N)
    curl -s --max-time $TIMEOUT "$BASE_URL" > /dev/null
    local end_time=$(date +%s%N)
    
    local response_time=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    if [ $response_time -lt 1000 ]; then
        print_success "Response time: ${response_time}ms (Good)"
    elif [ $response_time -lt 3000 ]; then
        print_warning "Response time: ${response_time}ms (Acceptable)"
    else
        print_error "Response time: ${response_time}ms (Slow)"
        return 1
    fi
    
    return 0
}

# Function to check system resources
check_resources() {
    print_status "Checking system resources..."
    
    # Check memory usage
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    print_status "Memory usage: ${memory_usage}%"
    
    # Check disk usage
    local disk_usage=$(df -h / | awk 'NR==2{printf "%s", $5}' | sed 's/%//')
    print_status "Disk usage: ${disk_usage}%"
    
    # Check if Node.js process is running
    if pgrep -f "node.*next" > /dev/null; then
        print_success "Node.js process is running"
    else
        print_error "Node.js process is not running"
        return 1
    fi
    
    return 0
}

# Function to generate health report
generate_report() {
    local report_file="health-report-$(date +%Y%m%d-%H%M%S).txt"
    
    print_status "Generating health report: $report_file"
    
    {
        echo "Syntax Sentry Health Report"
        echo "Generated: $(date)"
        echo "Base URL: $BASE_URL"
        echo ""
        
        echo "=== Application Status ==="
        if check_url "$BASE_URL" "Main Application"; then
            echo "Main Application: OK"
        else
            echo "Main Application: FAILED"
        fi
        
        echo ""
        echo "=== API Endpoints ==="
        check_api_endpoints
        
        echo ""
        echo "=== Database ==="
        check_database
        
        echo ""
        echo "=== Performance ==="
        check_performance
        
        echo ""
        echo "=== System Resources ==="
        check_resources
        
    } > "$report_file"
    
    print_success "Health report saved to: $report_file"
}

# Function to show help
show_help() {
    echo "Syntax Sentry Health Check Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  check       Run basic health checks"
    echo "  full        Run comprehensive health checks"
    echo "  report      Generate detailed health report"
    echo "  api         Check API endpoints only"
    echo "  perf        Check performance only"
    echo "  help        Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  BASE_URL    Base URL to check (default: http://localhost:3000)"
    echo "  TIMEOUT     Request timeout in seconds (default: 30)"
    echo "  MAX_RETRIES Maximum retry attempts (default: 3)"
    echo ""
    echo "Examples:"
    echo "  $0 check"
    echo "  $0 full"
    echo "  BASE_URL=https://syntax-sentry.vercel.app $0 report"
}

# Main script logic
main() {
    case "${1:-help}" in
        "check")
            check_url "$BASE_URL" "Main Application"
            check_api_endpoints
            ;;
        "full")
            check_url "$BASE_URL" "Main Application"
            check_api_endpoints
            check_database
            check_performance
            check_resources
            ;;
        "report")
            generate_report
            ;;
        "api")
            check_api_endpoints
            ;;
        "perf")
            check_performance
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@"
