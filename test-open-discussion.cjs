const io = require('socket.io-client');

// Test with the exact same format as Flutter app
console.log('Connecting to: http://jitsi.dialecticlabs.com:3001/signaling');
const socket = io('http://jitsi.dialecticlabs.com:3001/signaling', {
  transports: ['websocket', 'polling']
});

socket.on('connect', () => {
  console.log('Connected! Socket ID:', socket.id);
  
  // Use the correct join format for signaling namespace
  socket.emit('join-room', {
    roomId: 'open-discussion-688c239499e31fdbdcc5',
    userId: '686c2422838a343e00ea',
    role: 'moderator'
  });
});

socket.on('error', (error) => {
  console.error('Socket error:', error);
});

socket.on('connect_error', (error) => {
  console.error('Connection error:', error.message);
});

// Listen for specific events that signaling namespace sends
socket.on('room-joined', (data) => {
  console.log('✅ ROOM-JOINED event:', data);
});

socket.on('existing-peers', (data) => {
  console.log('👥 EXISTING-PEERS event:', data);
});

socket.on('peer-joined', (data) => {
  console.log('👤 PEER-JOINED event:', data);
});

// Listen for any event
socket.onAny((eventName, ...args) => {
  console.log('📨 Event received:', eventName, args);
});

setTimeout(() => {
  console.log('Closing connection...');
  socket.close();
  process.exit(0);
}, 5000);