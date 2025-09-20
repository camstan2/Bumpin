#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Running comprehensive build check..."

# Project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_LOG="$PROJECT_DIR/build-output.log"

# Clean previous build artifacts
echo "🧹 Cleaning build folder..."
xcodebuild clean -project "$PROJECT_DIR/Bumpin.xcodeproj" -scheme Bumpin > /dev/null 2>&1

# Build project and capture output
echo "🏗️ Building project..."
xcodebuild build \
    -project "$PROJECT_DIR/Bumpin.xcodeproj" \
    -scheme Bumpin \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    2>&1 | tee "$BUILD_LOG"

# Check build status
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
else
    echo -e "${RED}❌ Build failed! Analyzing errors...${NC}\n"

    # Common error patterns
    echo -e "${YELLOW}Common Error Analysis:${NC}"
    
    # Missing imports
    IMPORT_ERRORS=$(grep -i "cannot find" "$BUILD_LOG" | sort | uniq -c)
    if [ ! -z "$IMPORT_ERRORS" ]; then
        echo -e "\n${YELLOW}Missing Import Errors:${NC}"
        echo "$IMPORT_ERRORS"
    fi
    
    # Type errors
    TYPE_ERRORS=$(grep -i "type.*does not conform to protocol" "$BUILD_LOG" | sort | uniq -c)
    if [ ! -z "$TYPE_ERRORS" ]; then
        echo -e "\n${YELLOW}Type Conformance Errors:${NC}"
        echo "$TYPE_ERRORS"
    fi
    
    # Property errors
    PROPERTY_ERRORS=$(grep -i "value of type.*has no member" "$BUILD_LOG" | sort | uniq -c)
    if [ ! -z "$PROPERTY_ERRORS" ]; then
        echo -e "\n${YELLOW}Missing Property Errors:${NC}"
        echo "$PROPERTY_ERRORS"
    fi
    
    # SwiftUI view errors
    VIEW_ERRORS=$(grep -i "type-check.*expression.*reasonable time" "$BUILD_LOG" | sort | uniq -c)
    if [ ! -z "$VIEW_ERRORS" ]; then
        echo -e "\n${YELLOW}SwiftUI View Complexity Errors:${NC}"
        echo "$VIEW_ERRORS"
    fi
fi

# Check for warnings
WARNINGS=$(grep -i "warning:" "$BUILD_LOG" | sort | uniq -c)
if [ ! -z "$WARNINGS" ]; then
    echo -e "\n${YELLOW}⚠️ Warnings Found:${NC}"
    echo "$WARNINGS"
fi

# Cleanup
rm "$BUILD_LOG"

echo -e "\n📋 Build check complete!"
