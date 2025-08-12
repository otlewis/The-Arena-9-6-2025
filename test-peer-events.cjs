const io = require('socket.io-client');

console.log('=== Testing Peer Events ===');

// Connect two clients to test peer-joined events
const client1 = io('http://jitsi.dialecticlabs.com:3001/signaling', {
  transports: ['websocket', 'polling']
});

const client2 = io('http://jitsi.dialecticlabs.com:3001/signaling', {
  transports: ['websocket', 'polling']
});

client1.on('connect', () => {
  console.log('Client1 Connected! Socket ID:', client1.id);
  
  client1.emit('join-room', {
    roomId: 'test-peer-events',
    userId: 'user1-moderator',
    role: 'moderator'
  });
});

client1.on('room-joined', (data) => {
  console.log('Client1 ✅ ROOM-JOINED:', data);
  
  // After client1 joins, connect client2
  setTimeout(() => {
    console.log('\n--- Client2 joining ---');
    client2.emit('join-room', {
      roomId: 'test-peer-events', 
      userId: 'user2-audience',
      role: 'audience'
    });
  }, 1000);
});

client1.on('peer-joined', (data) => {
  console.log('Client1 👤 PEER-JOINED:', data);
});

client2.on('connect', () => {
  console.log('Client2 Connected! Socket ID:', client2.id);
});

client2.on('room-joined', (data) => {
  console.log('Client2 ✅ ROOM-JOINED:', data);
  
  // Add delay to see if Client2 gets peer-joined events about Client1
  setTimeout(() => {
    console.log('--- Waiting for Client2 peer-joined events ---');
  }, 500);
});

client2.on('peer-joined', (data) => {
  console.log('Client2 👤 PEER-JOINED:', data);
});

// Listen for all events
client1.onAny((eventName, ...args) => {
  console.log('Client1 📨 Event:', eventName, args);
});

client2.onAny((eventName, ...args) => {
  console.log('Client2 📨 Event:', eventName, args);
});

setTimeout(() => {
  console.log('Closing connections...');
  client1.close();
  client2.close();
  process.exit(0);
}, 8000);