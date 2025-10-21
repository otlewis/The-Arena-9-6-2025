# Credential Rotation Guide - Arena App

**Date**: October 5, 2025
**Status**: CRITICAL - Rotate Credentials Immediately
**Priority**: P0 - Before Production Deployment

---

## 🚨 WHY ROTATE CREDENTIALS?

All current API keys and secrets in the codebase should be considered **COMPROMISED** because:

1. They were hardcoded in source files
2. The repository may have been public or shared
3. They appeared in `.env.example` files
4. Code was analyzed by AI assistants (this session)

**Assume all secrets are known to attackers. Rotate immediately.**

---

## 📋 Credentials To Rotate

### 1. **Firebase API Keys** ⚠️ CRITICAL

**Location**: `lib/firebase_options.dart`

**What to rotate**:
- Web API Key: `AIzaSyB56i9YDqv1iFXQSU2eo8F1C_oPfSIwQIA`
- iOS/Android API Keys
- All Firebase project configurations

**How to rotate**:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (`arena-flutter`)
3. Project Settings → General
4. Delete existing app registrations
5. Add new app registrations (Web, iOS, Android)
6. Download new config files
7. Update `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
8. Update `firebase_options.dart` with new values
9. **DO NOT** commit new keys to git

**Alternative (Recommended)**:
- Create a new Firebase project entirely
- Migrate data to new project
- Use new credentials
- Delete old project after migration

---

### 2. **Appwrite Project** ⚠️ CRITICAL

**Location**: `lib/constants/appwrite.dart`, `.env.example`

**What to rotate**:
- Project ID: `683a37a8003719978879`
- Endpoint: `https://fra.cloud.appwrite.io/v1`
- API keys (if any client-side keys exist)

**How to rotate**:
1. Go to [Appwrite Console](https://cloud.appwrite.io)
2. Create a NEW project
3. Migrate collections and data:
   ```bash
   # Export from old project
   appwrite databases export --database-id arena_db --output ./backup.json

   # Import to new project
   appwrite login
   appwrite databases import --database-id arena_db --input ./backup.json
   ```
4. Update Function environment variables
5. Update client app configuration
6. Test thoroughly in staging
7. Delete old project after confirming migration

**Alternative (If Migration is Complex)**:
- Regenerate API keys in existing project
- Ensure no client-side API keys exist
- Only use server-side API keys in Appwrite Functions

---

### 3. **LiveKit Credentials** ⚠️ CRITICAL

**Location**: `.env.example`, Appwrite Function environment variables

**What to rotate**:
- API Key: (whatever is currently set)
- API Secret: (whatever is currently set)
- Server URL: May need to update

**How to rotate**:
1. Go to [LiveKit Cloud Console](https://cloud.livekit.io)
2. Settings → API Keys
3. Create new API key pair
4. Update Appwrite Function `generate-livekit-token` environment variables:
   ```bash
   appwrite functions updateVariable \
     --function-id generate-livekit-token \
     --key LIVEKIT_API_KEY \
     --value "NEW_API_KEY"

   appwrite functions updateVariable \
     --function-id generate-livekit-token \
     --key LIVEKIT_API_SECRET \
     --value "NEW_API_SECRET"
   ```
5. Delete old API key from LiveKit Console
6. **NEVER** put API secret in client code

---

### 4. **IONOS Storage Credentials** ⚠️ CRITICAL

**Location**: `.env.example`, Appwrite Function environment variables

**What to rotate**:
- Access Key: (current S3 access key)
- Secret Key: (current S3 secret key)
- Bucket: May need to create new bucket

**How to rotate**:
1. Go to IONOS S3 Console
2. Create new access key/secret key pair
3. Update Appwrite Function `generate-upload-url` environment variables:
   ```bash
   appwrite functions updateVariable \
     --function-id generate-upload-url \
     --key IONOS_ACCESS_KEY \
     --value "NEW_ACCESS_KEY"

   appwrite functions updateVariable \
     --function-id generate-upload-url \
     --key IONOS_SECRET_KEY \
     --value "NEW_SECRET_KEY"
   ```
4. Delete old credentials from IONOS Console
5. **NEVER** put credentials in client code

**Optional - Create New Bucket**:
1. Create new S3 bucket with different name
2. Update bucket name in function environment
3. Migrate existing recordings (if needed):
   ```bash
   aws s3 sync s3://old-bucket s3://new-bucket --profile ionos
   ```
4. Delete old bucket after migration complete

---

### 5. **RevenueCat API Keys** (If exposed)

**Location**: Various service files

**How to rotate**:
1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Project Settings → API keys
3. Generate new API keys
4. Update all services using RevenueCat
5. Revoke old API keys

---

## 📝 Rotation Checklist

### Immediate Actions (Within 24 Hours)
- [ ] Create new Firebase project and migrate data
- [ ] Create new Appwrite project and migrate collections
- [ ] Generate new LiveKit API key pair
- [ ] Generate new IONOS S3 credentials
- [ ] Update all Appwrite Function environment variables
- [ ] Remove ALL credentials from `.env.example`
- [ ] Add `.env` to `.gitignore` (if not already)
- [ ] Search codebase for any other hardcoded secrets
- [ ] Deploy updated Appwrite Functions with new credentials
- [ ] Test app with new credentials in staging
- [ ] Document which team members have access to secrets

### Short Term (Within 1 Week)
- [ ] Set up secrets management system (1Password, HashiCorp Vault, etc.)
- [ ] Implement secret rotation automation
- [ ] Set up monitoring for credential usage
- [ ] Review access logs for suspicious activity
- [ ] Implement alerts for failed authentication attempts
- [ ] Create incident response plan
- [ ] Train team on secure credential handling

### Long Term (Ongoing)
- [ ] Rotate credentials every 90 days
- [ ] Audit credential access quarterly
- [ ] Review and update this guide annually
- [ ] Monitor for credential leaks (GitHub scanning, etc.)
- [ ] Keep secrets management system updated

---

## 🔒 Secure Credential Storage

### For Development

**Use Environment Variables (NEVER commit to git)**:
```bash
# Create .env file (add to .gitignore!)
cp .env.example .env

# Edit .env with actual credentials
nano .env

# Load in app (flutter_dotenv)
await dotenv.load();
final apiKey = dotenv.env['API_KEY'];
```

**Recommended Tools**:
- **1Password** - Team password manager
- **Bitwarden** - Open-source alternative
- **macOS Keychain** - For local development
- **Windows Credential Manager** - For Windows developers

### For Production

**Appwrite Functions** (Server-side):
- Use Appwrite Console to set environment variables
- Variables are encrypted at rest
- Only accessible to functions, not clients

**Flutter App** (Client-side):
- **NEVER** store secrets in client code
- Always call server-side functions
- Use tokens/JWTs from server
- Tokens should be short-lived (< 1 hour)

---

## 🔍 How To Find Exposed Credentials

### Search Your Codebase
```bash
# Search for API keys
git grep -i "api.key" | grep -v ".md"

# Search for secrets
git grep -i "secret" | grep -v ".md"

# Search for passwords
git grep -i "password" | grep -v ".md"

# Search for tokens
git grep -i "token" | grep -v ".md"

# Check git history for secrets
git log -S "api_key" --all
```

### Check for Public Exposure
```bash
# Check if repo is public
gh repo view

# Check GitHub for leaked secrets
# Visit: https://github.com/settings/security_analysis

# Use gitleaks to scan history
gitleaks detect --source . --verbose
```

---

## 🚨 If Credentials Are Already Compromised

### Immediate Response (Within 1 Hour)
1. **Disable compromised credentials immediately**
   - Revoke API keys in respective consoles
   - Block suspicious IP addresses
   - Disable affected accounts

2. **Generate new credentials**
   - Follow rotation steps above
   - Use different values than before

3. **Deploy emergency patch**
   - Update all services with new credentials
   - Force app update if client credentials exposed

4. **Monitor for abuse**
   - Check Firebase/Appwrite usage metrics
   - Look for unusual API calls
   - Review billing for unexpected charges

### Investigation (Within 24 Hours)
1. **Determine scope of breach**
   - What credentials were exposed?
   - For how long?
   - Who had access?

2. **Check for unauthorized access**
   - Review authentication logs
   - Check database for unauthorized changes
   - Review storage for unexpected files

3. **Notify affected parties**
   - Users (if user data compromised)
   - Team members
   - Management
   - Legal (if required by GDPR/CCPA)

### Prevention (Ongoing)
1. Implement all items in "Rotation Checklist" above
2. Set up GitHub secret scanning
3. Use pre-commit hooks to block secrets
4. Regular security training for team
5. Periodic security audits

---

## 📚 Additional Resources

- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [1Password for Teams](https://1password.com/teams/)
- [Google Cloud Secret Manager](https://cloud.google.com/secret-manager)
- [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)

---

## 📞 Emergency Contacts

**In case of security incident**:
- Security Lead: [TBD]
- Development Team Lead: [TBD]
- Infrastructure Team: [TBD]
- After Hours: [TBD]

**Vendor Support**:
- Firebase Support: https://firebase.google.com/support
- Appwrite Support: https://appwrite.io/support
- LiveKit Support: support@livekit.io
- IONOS Support: https://www.ionos.com/help

---

**Document Version**: 1.0
**Last Updated**: October 5, 2025
**Next Review**: After credential rotation completion
