const io = require('socket.io-client');

const socket = io('http://jitsi.dialecticlabs.com:3001', {
  transports: ['websocket', 'polling']
});

socket.on('connect', () => {
  console.log('Connected! Socket ID:', socket.id);
  
  // Try joining a room with MediaSoup format
  socket.emit('join-room', {
    roomId: 'test-room',
    userId: 'test-user',
    role: 'audience',
    device: {
      name: 'Test Client',
      version: '1.0.0'
    }
  }, (response) => {
    console.log('Join response:', response);
  });
});

socket.on('error', (error) => {
  console.error('Socket error:', error);
});

socket.on('connect_error', (error) => {
  console.error('Connection error:', error.message);
});

// Listen for any event
socket.onAny((eventName, ...args) => {
  console.log('Event received:', eventName, args);
});

setTimeout(() => {
  console.log('Closing connection...');
  socket.close();
  process.exit(0);
}, 5000);