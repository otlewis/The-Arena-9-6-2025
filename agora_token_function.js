const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

// Agora credentials (set these in Appwrite Function Environment Variables)
const APP_ID = process.env.AGORA_APP_ID || '3ccc264b24df4b5f91fa35741ea6e0b8';
const APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE; // You'll need to get this from Agora Console

/**
 * Appwrite Function to generate Agora RTC tokens
 * 
 * Expected payload:
 * {
 *   "channel": "arena",
 *   "uid": 0,
 *   "role": "publisher", // "publisher" or "subscriber"
 *   "expireTime": 3600   // seconds (optional, defaults to 1 hour)
 * }
 */
module.exports = async ({ req, res, log, error }) => {
  try {
    log('🚀 Agora Token Generator function started');
    
    // Get environment variables
    const appId = process.env.AGORA_APP_ID;
    const appCertificate = process.env.AGORA_APP_CERTIFICATE;
    
    log(`App ID: ${appId ? 'Set (' + appId.substring(0, 8) + '...)' : 'Missing'}`);
    log(`App Certificate: ${appCertificate ? 'Set (' + appCertificate.substring(0, 8) + '...)' : 'Missing'}`);
    
    if (!appId || !appCertificate) {
      error('Missing AGORA_APP_ID or AGORA_APP_CERTIFICATE environment variables');
      return res.json({
        success: false,
        error: 'Server configuration error - missing credentials'
      }, 500);
    }

    // Parse request data - try multiple sources
    let requestData = {};
    
    log('Raw req object keys: ' + Object.keys(req).join(', '));
    log('Request method: ' + req.method);
    
    // Try different ways to get the request data
    if (req.body) {
      log('Found req.body (length: ' + (typeof req.body === 'string' ? req.body.length : 'object') + ')');
      try {
        requestData = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
        log('Parsed req.body successfully: ' + JSON.stringify(requestData));
      } catch (e) {
        log('Error parsing req.body: ' + e.message);
      }
    } else {
      log('No req.body found');
    }
    
    if (req.payload) {
      log('Found req.payload: ' + JSON.stringify(req.payload));
      requestData = { ...requestData, ...req.payload };
    }
    
    if (req.variables) {
      log('Found req.variables: ' + JSON.stringify(req.variables));
      requestData = { ...requestData, ...req.variables };
    }
    
    // Check query parameters for GET requests
    if (req.query) {
      log('Found req.query: ' + JSON.stringify(req.query));
      requestData = { ...requestData, ...req.query };
    }
    
    log('Final merged request data: ' + JSON.stringify(requestData));
    
    // Use provided data or defaults
    const channelName = requestData.channelName || 'arena';
    const uid = requestData.uid || 12345;
    const role = requestData.role || 'publisher';
    
    log(`Using values - Channel: ${channelName}, UID: ${uid}, Role: ${role}`);
    
    // Set role for Agora
    const userRole = role === 'publisher' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;
    log(`Agora role enum: ${userRole} (${role === 'publisher' ? 'PUBLISHER' : 'SUBSCRIBER'})`);
    
    // Token expires in 24 hours
    const expirationTimeInSeconds = Math.floor(Date.now() / 1000) + (24 * 60 * 60);
    log(`Token expiration: ${expirationTimeInSeconds} (${new Date(expirationTimeInSeconds * 1000).toISOString()})`);
    
    // Generate token
    log(`About to generate token with: appId=${appId.substring(0, 8)}..., channel=${channelName}, uid=${uid}`);
    
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      userRole,
      expirationTimeInSeconds
    );

    log(`Successfully generated token (${token.length} chars): ${token.substring(0, 50)}...`);

    const response = {
      success: true,
      token: token,
      expiration: expirationTimeInSeconds,
      channelName: channelName,
      uid: uid,
      role: role,
      debug: {
        receivedData: requestData,
        appIdPresent: !!appId,
        appCertificatePresent: !!appCertificate,
        tokenLength: token.length,
        timestamp: new Date().toISOString()
      }
    };
    
    log('Returning successful response: ' + JSON.stringify({...response, token: token.substring(0, 50) + '...'}));
    
    return res.json(response);

  } catch (err) {
    error('Error generating Agora token: ' + err.message);
    log('Full error details: ' + err.stack);
    return res.json({
      success: false,
      error: 'Failed to generate token: ' + err.message,
      timestamp: new Date().toISOString()
    }, 500);
  }
}; 