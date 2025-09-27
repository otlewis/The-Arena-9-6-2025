#!/bin/bash

echo "🧪 Arena App - Comprehensive Test Suite"
echo "======================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test file
run_test() {
    local test_file=$1
    local test_name=$2

    echo -e "${YELLOW}Running: ${test_name}${NC}"

    if flutter test "$test_file" --no-pub; then
        echo -e "${GREEN}✓ ${test_name} passed${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗ ${test_name} failed${NC}"
        ((FAILED_TESTS++))
    fi

    ((TOTAL_TESTS++))
    echo ""
}

# Function to run integration tests
run_integration_test() {
    local test_file=$1
    local test_name=$2

    echo -e "${YELLOW}Running Integration: ${test_name}${NC}"

    if flutter test "$test_file" --no-pub; then
        echo -e "${GREEN}✓ ${test_name} passed${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗ ${test_name} failed${NC}"
        ((FAILED_TESTS++))
    fi

    ((TOTAL_TESTS++))
    echo ""
}

# Clean and get dependencies
echo "📦 Preparing test environment..."
flutter clean
flutter pub get
echo ""

# Generate mocks if needed
echo "🔨 Generating mocks..."
flutter pub run build_runner build --delete-conflicting-outputs
echo ""

# Run unit tests
echo "🔬 Unit Tests"
echo "-------------"
run_test "test/services/appwrite_service_test.dart" "AppwriteService Tests"
run_test "test/services/livekit_service_test.dart" "LiveKitService Tests"
run_test "test/services/timer_service_test.dart" "TimerService Tests"
run_test "test/services/disposal_tracking_system_test.dart" "DisposalTrackingSystem Tests"

# Run widget tests
echo "🎨 Widget Tests"
echo "---------------"
run_test "test/widgets/arena_participants_panel_test.dart" "ArenaParticipantsPanel Tests"
run_test "test/widgets/timer_widget_test.dart" "TimerWidget Tests"
run_test "test/widgets/chat_panel_test.dart" "ChatPanel Tests"

# Run screen tests
echo "📱 Screen Tests"
echo "---------------"
run_test "test/screens/arena_screen_test.dart" "ArenaScreen Tests"
run_test "test/screens/debates_discussions_screen_test.dart" "DebatesDiscussionsScreen Tests"
run_test "test/screens/home_screen_test.dart" "HomeScreen Tests"

# Run provider tests
echo "🔄 Provider Tests"
echo "-----------------"
run_test "test/providers/arena_provider_test.dart" "ArenaProvider Tests"
run_test "test/providers/user_provider_test.dart" "UserProvider Tests"

# Run integration tests (if device/emulator is available)
echo "🚀 Integration Tests"
echo "--------------------"
if flutter devices | grep -q "chrome\|emulator\|simulator"; then
    run_integration_test "test/integration/arena_flow_test.dart" "Arena Flow Integration"
else
    echo -e "${YELLOW}⚠️  No device/emulator available for integration tests${NC}"
    echo ""
fi

# Generate coverage report
echo "📊 Generating Coverage Report..."
flutter test --coverage --no-pub
if command -v lcov &> /dev/null; then
    lcov --remove coverage/lcov.info \
        'lib/generated/*' \
        'lib/*.g.dart' \
        'lib/*.freezed.dart' \
        -o coverage/lcov.info

    genhtml coverage/lcov.info -o coverage/html
    echo -e "${GREEN}✓ Coverage report generated in coverage/html/index.html${NC}"
else
    echo -e "${YELLOW}⚠️  lcov not installed, skipping HTML coverage report${NC}"
fi
echo ""

# Run flutter analyze
echo "🔍 Running Flutter Analyze..."
if flutter analyze --no-pub; then
    echo -e "${GREEN}✓ No issues found${NC}"
else
    echo -e "${RED}✗ Analysis issues found${NC}"
fi
echo ""

# Summary
echo "======================================="
echo "📈 Test Summary"
echo "======================================="
echo -e "Total Tests:  ${TOTAL_TESTS}"
echo -e "Passed:       ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Failed:       ${RED}${FAILED_TESTS}${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some tests failed. Please review the output above.${NC}"
    exit 1
fi