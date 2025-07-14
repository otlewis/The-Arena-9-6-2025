# Appwrite Functions Setup Instructions

## 1. Create the Timer Controller Function

### Using Appwrite Console:

1. Go to your Appwrite Console → Functions
2. Click "Create Function"
3. Fill in the details:
   - **Function ID**: `timer-controller`
   - **Name**: `Timer Controller`
   - **Runtime**: `Node.js 18.0`
   - **Entrypoint**: `src/main.js`
   - **Commands**: Leave empty (will use package.json)

4. **Environment Variables**:
   ```
   APPWRITE_DATABASE_ID=your_database_id
   ```

5. **Deploy the Function**:
   - Upload the `timer-controller` folder as a tar.gz file
   - Or use Appwrite CLI (recommended):
   ```bash
   cd appwrite/functions/timer-controller
   appwrite functions createDeployment \
     --functionId timer-controller \
     --code . \
     --activate true
   ```

### Function Permissions:
Set the following permissions for the timer-controller function:
- **Execute**: `users` (any authenticated user can call it)

## 2. Create the Timer Ticker Function

### Using Appwrite Console:

1. Create another function:
   - **Function ID**: `timer-ticker`
   - **Name**: `Timer Ticker`
   - **Runtime**: `Node.js 18.0`
   - **Entrypoint**: `src/main.js`

2. **Environment Variables**:
   ```
   APPWRITE_DATABASE_ID=your_database_id
   TIMER_CONTROLLER_FUNCTION_ID=timer-controller
   ```

3. **Schedule the Function**:
   - Go to Function → Executions → Execute now → Schedule
   - **Schedule**: `* * * * * *` (every second)
   - **Method**: `POST`
   - **Path**: `/tick`
   - **Body**: `{}`

4. **Deploy using CLI**:
   ```bash
   cd appwrite/functions/timer-ticker
   appwrite functions createDeployment \
     --functionId timer-ticker \
     --code . \
     --activate true
   ```

### Function Permissions:
- **Execute**: `admin` (only system can execute scheduled functions)

## 3. Set up Function Environment Variables

Add these to your Appwrite project environment:

```bash
# In Appwrite Console → Settings → Environment Variables
APPWRITE_DATABASE_ID=your_actual_database_id
TIMER_CONTROLLER_FUNCTION_ID=timer-controller
```

## 4. Configure Function API Keys

Both functions need an API key with these permissions:

### API Key Scopes:
- `databases.read`
- `databases.write` 
- `functions.read`
- `functions.write`

Create the API key in Appwrite Console → API Keys and add it to function environment variables as `APPWRITE_API_KEY`.

## 5. Testing the Functions

### Test Timer Controller:

```bash
# Using curl (replace with your function endpoint)
curl -X POST https://your-appwrite-endpoint/v1/functions/timer-controller/executions \
  -H "Content-Type: application/json" \
  -H "X-Appwrite-Project: your-project-id" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "action": "create",
    "data": {
      "roomId": "test-room",
      "roomType": "openDiscussion", 
      "timerType": "general",
      "durationSeconds": 300,
      "createdBy": "test-user"
    }
  }'
```

### Test Timer Ticker:

The ticker function will run automatically every second once scheduled. Check the function logs in Appwrite Console → Functions → timer-ticker → Executions.

## 6. Alternative Setup Using Appwrite CLI

### Install Appwrite CLI:
```bash
npm install -g appwrite-cli
```

### Initialize project:
```bash
appwrite init project
# Follow prompts to connect to your Appwrite project
```

### Deploy functions:
```bash
# Deploy timer controller
appwrite functions create \
  --functionId timer-controller \
  --name "Timer Controller" \
  --runtime node-18.0 \
  --execute users

appwrite functions createDeployment \
  --functionId timer-controller \
  --code appwrite/functions/timer-controller \
  --activate true

# Deploy timer ticker  
appwrite functions create \
  --functionId timer-ticker \
  --name "Timer Ticker" \
  --runtime node-18.0 \
  --execute admin

appwrite functions createDeployment \
  --functionId timer-ticker \
  --code appwrite/functions/timer-ticker \
  --activate true

# Schedule the ticker
appwrite functions createExecution \
  --functionId timer-ticker \
  --body '{}' \
  --async false \
  --path '/tick' \
  --method POST \
  --headers '{"Content-Type": "application/json"}'
```

## 7. Function Monitoring

### Check Function Health:
- Monitor execution logs in Appwrite Console
- Set up alerts for function failures
- Track execution duration (should be < 1000ms)

### Performance Optimization:
- The ticker function processes max 100 timers per execution
- For high-scale deployments, consider implementing batch processing
- Monitor database performance with many concurrent timer updates

## 8. Security Considerations

### Function Security:
- Timer controller function validates user permissions
- Only authenticated users can create/control timers
- Audit trail in timer_events collection
- Server-side validation prevents client manipulation

### Database Security Rules:
Add these to your Appwrite database permissions:

```javascript
// For timers collection
read: ["users"]
create: ["users"] 
update: ["users"]
delete: ["users"]

// For timer_events collection  
read: ["users"]
create: ["users"]
update: [] // No updates allowed
delete: [] // No deletions allowed
```

## 9. Troubleshooting

### Common Issues:

1. **Function not executing**: Check API key permissions and environment variables
2. **Timer not updating**: Verify ticker function is scheduled and running
3. **Permission errors**: Ensure proper database and function permissions
4. **High latency**: Consider reducing timer update frequency or optimizing database queries

### Debug Commands:

```bash
# Check function logs
appwrite functions listExecutions --functionId timer-controller --limit 10

# Test function manually
appwrite functions createExecution \
  --functionId timer-controller \
  --body '{"action": "tick"}' \
  --async false
```

Your Appwrite Functions are now set up for perfect timer synchronization across all devices!