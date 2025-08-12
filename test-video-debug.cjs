const io = require('socket.io-client');

console.log('=== Testing Video Debug ===');

// Connect as moderator first (should publish video)
const moderator = io('http://jitsi.dialecticlabs.com:3001/signaling', {
  transports: ['websocket', 'polling']
});

// Connect as audience second (should receive video)
const audience = io('http://jitsi.dialecticlabs.com:3001/signaling', {
  transports: ['websocket', 'polling']
});

moderator.on('connect', () => {
  console.log('Moderator Connected! Socket ID:', moderator.id);
  
  moderator.emit('join-room', {
    roomId: 'debug-video-test',
    userId: 'moderator-video-test',
    role: 'moderator'
  });
});

moderator.on('room-joined', (data) => {
  console.log('Moderator ✅ ROOM-JOINED:', data);
  
  // After moderator joins, connect audience
  setTimeout(() => {
    console.log('\n--- Audience joining ---');
    audience.emit('join-room', {
      roomId: 'debug-video-test',
      userId: 'audience-video-test',
      role: 'audience'
    });
  }, 1000);
});

moderator.on('peer-joined', (data) => {
  console.log('Moderator 👤 PEER-JOINED:', data);
});

audience.on('connect', () => {
  console.log('Audience Connected! Socket ID:', audience.id);
});

audience.on('room-joined', (data) => {
  console.log('Audience ✅ ROOM-JOINED:', data);
});

audience.on('peer-joined', (data) => {
  console.log('Audience 👤 PEER-JOINED (should see moderator):', data);
});

// Listen for WebRTC signaling events
moderator.on('offer', (data) => {
  console.log('Moderator 📤 Received OFFER from:', data.from);
});

moderator.on('answer', (data) => {
  console.log('Moderator 📥 Received ANSWER from:', data.from);
});

moderator.on('ice-candidate', (data) => {
  console.log('Moderator 🧊 Received ICE from:', data.from);
});

audience.on('offer', (data) => {
  console.log('Audience 📤 Received OFFER from:', data.from);
});

audience.on('answer', (data) => {
  console.log('Audience 📥 Received ANSWER from:', data.from);
});

audience.on('ice-candidate', (data) => {
  console.log('Audience 🧊 Received ICE from:', data.from);
});

// Listen for all events
moderator.onAny((eventName, ...args) => {
  console.log('Moderator 📨 Event:', eventName, args);
});

audience.onAny((eventName, ...args) => {
  console.log('Audience 📨 Event:', eventName, args);
});

setTimeout(() => {
  console.log('\n=== Test Summary ===');
  console.log('If peer-joined events are working, both clients should see each other');
  console.log('Next step: Check if WebRTC offers contain video tracks');
  
  console.log('Closing connections...');
  moderator.close();
  audience.close();
  process.exit(0);
}, 10000);