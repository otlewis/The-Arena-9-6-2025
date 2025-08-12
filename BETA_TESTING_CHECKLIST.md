# 🧪 Arena Beta Testing Checklist

## 📱 For Beta Testers - Please Test These Features

### 🔴 CRITICAL - Audio System (Priority #1)
**Arena Rooms:**
- [ ] Join an Arena room as different roles (debater, judge, audience)
- [ ] Speak and verify others can hear you clearly
- [ ] Listen and verify you can hear others
- [ ] Test mute/unmute button functionality
- [ ] Test with phone speaker
- [ ] Test with wired headphones
- [ ] Test with Bluetooth headphones/earbuds
- [ ] Stay in room for 5+ minutes to test stability
- [ ] Test audio when switching between WiFi and cellular data
- [ ] Test audio when app goes to background (minimize app)

**Report any issues:**
- No sound at all?
- Sound cutting in/out?
- Echo or feedback?
- Delays in audio?
- Audio stops when minimizing app?

---

### 🟡 Core Features Testing

#### 1. Account & Authentication
- [ ] Sign up with new account
- [ ] Verify email (if required)
- [ ] Login with existing account
- [ ] Logout and login again
- [ ] Try "Forgot Password" flow
- [ ] Edit profile (name, bio, avatar)
- [ ] Check if profile changes save correctly

#### 2. Arena (Challenge Debates)
- [ ] Create a new Arena room
- [ ] Join existing Arena room as:
  - [ ] Affirmative debater
  - [ ] Negative debater
  - [ ] Judge
  - [ ] Audience member
- [ ] Test debate timer (shows countdown?)
- [ ] Test voting/scoring system (judges)
- [ ] Test chat during Arena
- [ ] Leave Arena and rejoin
- [ ] Check if Arena ends properly when moderator leaves

#### 3. Debates & Discussions
- [ ] Create a new discussion room
- [ ] Join as moderator
- [ ] Join as speaker
- [ ] Join as audience
- [ ] Request to speak (raise hand)
- [ ] Moderator approve/deny speaker requests
- [ ] Test audio for all speakers
- [ ] Use room chat
- [ ] Leave and rejoin room

#### 4. Open Discussions
- [ ] Create open discussion room
- [ ] Join open discussion
- [ ] Test speaking freely (no moderation)
- [ ] Test multiple people speaking
- [ ] Use chat during discussion
- [ ] Test room capacity limits

#### 5. Messaging & Chat
- [ ] Send messages in room chat
- [ ] Receive messages from others
- [ ] Check if messages persist after rejoining
- [ ] Test instant messaging (if available)
- [ ] Check notification bell for new messages
- [ ] Test emoji support in chat

#### 6. Timer System
- [ ] Verify timer starts correctly
- [ ] Check timer synchronization (all users see same time)
- [ ] Test 30-second warning sound
- [ ] Test timer expiration sound
- [ ] Check if timer pauses/resumes properly

---

### 🟢 Mobile-Specific Testing

#### Device Orientation
- [ ] Use app in portrait mode
- [ ] Use app in landscape mode
- [ ] Rotate during active call
- [ ] Check UI elements don't overlap

#### Network Conditions
- [ ] Test on strong WiFi
- [ ] Test on weak WiFi
- [ ] Test on 5G/4G
- [ ] Test on slow 3G
- [ ] Switch from WiFi to cellular during call
- [ ] Test in airplane mode (should show error)

#### Background Behavior
- [ ] Minimize app during voice call
- [ ] Switch to another app and return
- [ ] Receive phone call during Arena session
- [ ] Lock screen during active session
- [ ] Test with Do Not Disturb mode on

#### Permissions
- [ ] Grant microphone permission when asked
- [ ] Grant camera permission when asked
- [ ] Grant notification permission
- [ ] Test denying permissions (app should handle gracefully)

#### Performance
- [ ] Note any lag or slowness
- [ ] Check battery drain during 30-min session
- [ ] Monitor phone heating
- [ ] Test with low battery mode on
- [ ] Check app storage usage after use

---

### 🔵 Platform-Specific

#### iOS Testing
- [ ] Test on iPhone (various models)
- [ ] Test on iPad if available
- [ ] Test with iOS 14, 15, 16, 17
- [ ] Check Face ID/Touch ID if implemented
- [ ] Test with AirPods
- [ ] Test CarPlay if in vehicle

#### Android Testing
- [ ] Test on different Android versions (10, 11, 12, 13, 14)
- [ ] Test on Samsung devices
- [ ] Test on Google Pixel
- [ ] Test on budget Android phones
- [ ] Test split-screen mode
- [ ] Test with Android Auto if in vehicle

---

### 🐛 Bug Reporting Template

When you find an issue, please report with:

```
ISSUE: [Brief description]
DEVICE: [iPhone 14 Pro / Samsung S23 / etc]
OS VERSION: [iOS 17.0 / Android 14]
APP VERSION: [1.0.14]
STEPS TO REPRODUCE:
1. [First step]
2. [Second step]
3. [What happened vs what should happen]

FREQUENCY: [Always / Sometimes / Once]
SEVERITY: [App crash / Feature broken / Minor issue]
SCREENSHOT/VIDEO: [Attach if possible]
```

---

### 📊 Feedback Questions

After testing, please answer:

**Functionality:**
1. Did audio work in all room types?
2. Were you able to join/create rooms easily?
3. Did the timer system work correctly?
4. Any features that didn't work as expected?

**Performance:**
1. How was the app's speed/responsiveness?
2. Did you experience any crashes?
3. Battery drain acceptable?
4. Any heating issues?

**User Experience:**
1. Was navigation intuitive?
2. Any confusing features?
3. Text readable on your screen?
4. Buttons easy to tap?

**Audio Quality:**
1. Rate audio quality (1-10)
2. Any echo or feedback?
3. Could you hear everyone clearly?
4. Did others hear you clearly?

**Overall:**
1. Would you use this app regularly?
2. Would you recommend to others?
3. Most liked feature?
4. Most frustrating issue?
5. Missing features you'd want?

---

### 📅 Testing Timeline

**Week 1 (Days 1-7):**
- Focus on CRITICAL audio testing
- Test core room functionality
- Report blocking issues immediately

**Week 2 (Days 8-14):**
- Test all features thoroughly
- Try edge cases
- Submit detailed feedback

---

### 💬 How to Report

**Urgent Issues** (app crashes, no audio):
- Report IMMEDIATELY via email/message

**Regular Feedback**:
- Daily summary of issues found
- Use bug reporting template above
- Include screenshots when possible

**Contact:**
- Email: [your-email]
- Discord/Slack: [if applicable]

---

## 🎯 Priority Focus Areas

1. **🔴 AUDIO IN ARENA ROOMS** - Most critical
2. **🟡 Room creation/joining flow**
3. **🟢 Timer synchronization**
4. **🔵 Chat functionality**
5. **⚪ UI/UX polish**

---

Thank you for helping test Arena! Your feedback is invaluable for making this app great. 🚀