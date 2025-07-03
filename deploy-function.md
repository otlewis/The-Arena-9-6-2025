# Manual Function Update Instructions

Since the API deployment has auth issues, please manually update the Appwrite function:

## Steps:
1. Go to Appwrite Console: https://cloud.appwrite.io/console/project-683a6bab000562231eeb
2. Navigate to Functions > agora-token-generator
3. Go to Settings tab
4. Upload the file: `agora-function-uid-fix.tar.gz`
5. Set entry point: `src/main.js`
6. Click Deploy

## Key Fix:
The function now correctly handles UID by using:
```javascript
const uid = requestData.uid !== undefined ? requestData.uid : 0;
```

Instead of the incorrect:
```javascript
const uid = requestData.uid || 12345;
```

This ensures the token is generated with the exact UID (0) that the Flutter app expects, resolving the "ErrorCodeType.errInvalidToken" error.

## Environment Variables:
Ensure these are still set:
- AGORA_APP_ID: 3ccc264b24df4b5f91fa35741ea6e0b8
- AGORA_APP_CERTIFICATE: 46c66fcc3173422fa582a36044d1ce89 