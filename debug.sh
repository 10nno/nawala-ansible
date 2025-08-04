#!/bin/bash

echo "=== COMPREHENSIVE GAME REDIRECT DEBUGGING ==="
echo ""

# Configuration
FRESH_DOMAIN="unovegasidn1.com"
ORIGIN_DOMAIN="unovegasgo.space"
TEST_SUBDOMAIN="test123"

# Function to trace redirects with details
trace_game_redirect() {
    local url="$1"
    local description="$2"
    
    echo "========================================="
    echo "Test: $description"
    echo "URL: $url"
    echo "-----------------------------------------"
    
    # Step 1: Get initial response without following redirects
    echo "1. Initial Response (no redirects followed):"
    response=$(curl -s -I -k --max-redirs 0 "$url" 2>&1)
    
    status=$(echo "$response" | grep -E "^HTTP" | tail -1 | awk '{print $2}')
    location=$(echo "$response" | grep -i "^location:" | sed 's/location: //i' | tr -d '\r')
    
    echo "   Status: $status"
    if [ -n "$location" ]; then
        echo "   Location: $location"
        
        # Analyze the redirect
        if [[ "$location" =~ wkydrsumjh\.net|pragmaticplaylive\.net|ppgames\.net|pgsoft-games\.com ]]; then
            echo "   ✓ SUCCESS: Redirecting to game provider domain"
        elif [[ "$location" =~ $FRESH_DOMAIN ]]; then
            echo "   ⚠ WARNING: Redirecting to fresh domain (should go to game provider)"
        elif [[ "$location" =~ $ORIGIN_DOMAIN ]]; then
            echo "   ✗ ERROR: Redirecting to origin domain"
        else
            echo "   ? Unknown redirect target"
        fi
    else
        echo "   No Location header (might be 200 OK or error)"
    fi
    
    # Step 2: Get all response headers
    echo ""
    echo "2. All Response Headers:"
    echo "$response" | grep -E "^[A-Za-z-]+:" | head -10
    
    # Step 3: Follow redirects and see final destination
    echo ""
    echo "3. Following All Redirects:"
    
    # Use curl with verbose redirect following
    final_result=$(curl -s -k -L -w "\n===FINAL_INFO===\nFINAL_URL: %{url_effective}\nFINAL_STATUS: %{http_code}\nREDIRECT_COUNT: %{num_redirects}\n" \
        -o /dev/null "$url" 2>&1)
    
    echo "$final_result" | grep -A3 "===FINAL_INFO==="
    
    # Step 4: Test with different curl options
    echo ""
    echo "4. Testing with Different Options:"
    
    # Test with explicit Host header
    echo "   a) With explicit Host header:"
    curl -s -I -k --max-redirs 0 -H "Host: $ORIGIN_DOMAIN" "$url" | grep -E "^(HTTP|Location)" | head -2
    
    # Test with follow location but limit redirects
    echo "   b) Following max 2 redirects:"
    curl -s -I -k -L --max-redirs 2 "$url" | grep -E "^HTTP" | tail -1
    
    echo ""
}

# Test various game URLs
echo "Testing Different Game URL Patterns:"
echo ""

# Test 1: Direct game launch URL
trace_game_redirect \
    "https://$TEST_SUBDOMAIN.$FRESH_DOMAIN/gs2c/html5Game.do?jackpotid=0&gname=Jackpot%20Blaze&symbol=vs10jpblaze" \
    "Direct HTML5 Game Launch"

# Test 2: Play game with token
trace_game_redirect \
    "https://$TEST_SUBDOMAIN.$FRESH_DOMAIN/gs2c/playGame.do?key=token%3Dcf557c11ac0d5cf6f1178c6d9c80c472" \
    "Play Game with Token"

# Test 3: Generic game path
trace_game_redirect \
    "https://$TEST_SUBDOMAIN.$FRESH_DOMAIN/game/launch?provider=pragmatic" \
    "Generic Game Launch Path"

# Check nginx configuration
echo ""
echo "========================================="
echo "NGINX CONFIGURATION CHECK:"
echo "-----------------------------------------"

# Check if proxy_redirect is set correctly
echo "1. Checking proxy_redirect settings in game location:"
grep -A5 -B5 "location.*gs2c\|game\|play" /etc/nginx/sites-available/*fresh*.conf | grep -E "proxy_redirect|location" | head -10

echo ""
echo "2. Checking proxy_intercept_errors settings:"
grep -A2 -B2 "proxy_intercept_errors" /etc/nginx/sites-available/*fresh*.conf | head -10

# Test nginx configuration
echo ""
echo "3. Testing nginx configuration:"
nginx -t 2>&1

# Check recent logs
echo ""
echo "========================================="
echo "RECENT LOG ANALYSIS:"
echo "-----------------------------------------"

echo "1. Recent game-related access logs:"
tail -50 /var/log/nginx/*access.log | grep -E "gs2c|playGame|html5Game|wkydrsumjh" | tail -5 || echo "No recent game requests"

echo ""
echo "2. Recent redirect-related logs:"
tail -100 /var/log/nginx/*access.log | grep -E "302|301" | grep -E "gs2c|game" | tail -5 || echo "No recent game redirects"

echo ""
echo "3. Any errors:"
tail -50 /var/log/nginx/*error.log | grep -v "SSL" | tail -5 || echo "No recent errors"

# Create a minimal test
echo ""
echo "========================================="
echo "MINIMAL REDIRECT TEST:"
echo "-----------------------------------------"

# Save current config
echo "Creating minimal test configuration..."

cat > /tmp/test_game_redirect.conf << 'EOF'
server {
    listen 8888;
    server_name localhost;
    
    # Test location that should NOT rewrite external redirects
    location /test-game {
        proxy_pass http://unovegasgo.space/gs2c/html5Game.do;
        proxy_set_header Host unovegasgo.space;
        proxy_redirect off;  # This is key - don't rewrite ANY redirects
    }
    
    # Test location that SHOULD rewrite internal redirects
    location /test-normal {
        proxy_pass http://unovegasgo.space/;
        proxy_set_header Host unovegasgo.space;
        proxy_redirect http://unovegasgo.space/ http://localhost:8888/;
    }
}
EOF

echo "Test configuration created at /tmp/test_game_redirect.conf"
echo ""
echo "To test manually:"
echo "1. nginx -t -c /tmp/test_game_redirect.conf"
echo "2. nginx -c /tmp/test_game_redirect.conf"
echo "3. curl -I http://localhost:8888/test-game?gname=TestGame"
echo "4. nginx -s stop -c /tmp/test_game_redirect.conf"

echo ""
echo "========================================="
echo "RECOMMENDATIONS:"
echo "-----------------------------------------"
echo "1. The key setting is 'proxy_redirect off;' in the game location block"
echo "2. This prevents nginx from rewriting ANY redirects for game URLs"
echo "3. External game provider redirects will pass through unchanged"
echo "4. Make sure proxy_intercept_errors is OFF for game URLs"
echo ""
