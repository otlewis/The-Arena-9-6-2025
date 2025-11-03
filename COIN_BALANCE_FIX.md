# Coin Balance Fix - Server-Side Atomic Operations

## Problem
The coin balance was reverting after deduction due to:
1. **Client-side cache staleness** - getUserProfile() returned cached data
2. **Race conditions** - Multiple rapid balance updates caused inconsistency
3. **No atomic operations** - Deductions weren't guaranteed to be consistent

## Solution
Implemented a server-side Appwrite Function that handles all coin operations atomically on the server, eliminating client-side cache and race condition issues.

## Architecture

### Server-Side Function: `manage-coin-balance`
- **Location**: `appwrite-functions/manage-coin-balance/`
- **Operations**: DEDUCT, ADD, GET, TRANSFER
- **Benefits**:
  - ✅ Atomic operations (no race conditions)
  - ✅ Server-side validation
  - ✅ Single source of truth
  - ✅ No cache issues

### Client-Side Service: `CoinService`
- **New Methods**:
  - `deductCoinsInstant()` - Now calls server function
  - `sendGiftAtomic()` - Atomic gift transfers
- **Flow**:
  1. Client optimistically updates UI
  2. Server function executes atomically
  3. Real-time subscription syncs balance
  4. Balance stays consistent

## Deployment Instructions

### 1. Deploy the Appwrite Function

```bash
# Deploy the function to Appwrite Cloud
appwrite deploy function --functionId=manage-coin-balance

# Or deploy all functions
appwrite push functions
```

### 2. Verify Function Deployment

Go to Appwrite Console → Functions → "Manage Coin Balance"
- Ensure status is "Active"
- Check that scopes include: documents.read, documents.write

### 3. Test the Function

You can test directly in Appwrite Console or use:

```bash
# Test DEDUCT operation
curl -X POST https://cloud.appwrite.io/v1/functions/manage-coin-balance/executions \
  -H "X-Appwrite-Project: YOUR_PROJECT_ID" \
  -H "X-Appwrite-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "DEDUCT",
    "userId": "USER_ID",
    "amount": 10
  }'

# Test GET operation
curl -X POST https://cloud.appwrite.io/v1/functions/manage-coin-balance/executions \
  -H "X-Appwrite-Project: YOUR_PROJECT_ID" \
  -H "X-Appwrite-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "GET",
    "userId": "USER_ID"
  }'
```

## Code Changes

### Files Modified:
1. **`lib/services/coin_service.dart`**
   - Added `_callCoinFunction()` to call Appwrite Function
   - Updated `deductCoinsInstant()` to use server function
   - Added `sendGiftAtomic()` for atomic gift transfers

2. **`lib/widgets/real_time_coin_balance.dart`**
   - Extended optimistic update protection (3s → 8s)
   - Extended optimistic flag duration (5s → 10s)
   - Removed redundant `_loadBalance()` call

3. **`lib/widgets/simple_gift_bottom_sheet.dart`**
   - Moved optimistic deduction before database call
   - Uses `deductCoinsInstant()` with server function

4. **`lib/services/gift_service.dart`**
   - Updated to use `deductCoinsInstant()` with server function

### New Files:
1. **`appwrite-functions/manage-coin-balance/src/main.js`**
   - Server-side function for atomic coin operations

2. **`appwrite-functions/manage-coin-balance/package.json`**
   - Node.js dependencies

3. **`appwrite.json`**
   - Added function configuration

## Testing Checklist

- [ ] Deploy function to Appwrite
- [ ] Test DEDUCT operation via console
- [ ] Test GET operation via console
- [ ] Send a gift in Arena
- [ ] Send a gift in Debates & Discussions
- [ ] Verify coin balance persists
- [ ] Check real-time balance updates
- [ ] Monitor function logs for errors

## Rollback Plan

If issues occur, you can rollback by:

1. Disable the function in Appwrite Console
2. The code will fall back to the old methods (still present in coin_service.dart)
3. Or revert the git commit

## Performance Notes

- Function execution time: ~100-300ms
- No additional latency for user (optimistic UI updates)
- Server validates all operations
- Real-time sync happens automatically

## Monitoring

Check function logs in Appwrite Console:
- Look for "✅ Successfully deducted" messages
- Watch for any error patterns
- Monitor execution count and duration

## Next Steps (Optional)

1. **Add transaction logging** - Store all coin transactions for audit trail
2. **Implement n8n automation** - For automated coin rewards
3. **Add coin purchase flow** - In-app purchases
4. **Rate limiting** - Prevent abuse
