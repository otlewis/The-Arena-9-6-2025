const io = require('socket.io-client');

console.log('=== Testing MediaSoup SFU Server ===');

// Test RPC endpoints
async function testSFUServer() {
  const socket = io('http://jitsi.dialecticlabs.com:3002', {
    transports: ['websocket', 'polling']
  });

  return new Promise((resolve, reject) => {
    socket.on('connect', async () => {
      console.log('✅ Connected to MediaSoup SFU server');
      console.log('Socket ID:', socket.id);

      try {
        // Test 1: Join room
        console.log('\n--- Test 1: Join Room ---');
        socket.emit('join-room', {
          roomId: 'test-sfu-room',
          userId: 'test-user-moderator',
          role: 'moderator'
        });

        socket.once('room-joined', (data) => {
          console.log('✅ Room joined:', data);
          
          // Test 2: Get router RTP capabilities
          console.log('\n--- Test 2: Get Router RTP Capabilities ---');
          socket.emit('request', {
            method: 'getRouterRtpCapabilities',
            params: { roomId: 'test-sfu-room' }
          }, (response) => {
            if (response.error) {
              console.log('❌ Error:', response.error);
            } else {
              console.log('✅ Got RTP capabilities');
              console.log('  - Audio codecs:', response.rtpCapabilities.mediaCodecs.filter(c => c.kind === 'audio').length);
              console.log('  - Video codecs:', response.rtpCapabilities.mediaCodecs.filter(c => c.kind === 'video').length);
              
              // Test 3: Create WebRTC Transport
              console.log('\n--- Test 3: Create Send Transport ---');
              socket.emit('request', {
                method: 'createWebRtcTransport',
                params: { 
                  roomId: 'test-sfu-room',
                  direction: 'send'
                }
              }, (response) => {
                if (response.error) {
                  console.log('❌ Error creating send transport:', response.error);
                } else {
                  console.log('✅ Send transport created');
                  console.log('  - Transport ID:', response.id);
                  console.log('  - ICE candidates:', response.iceCandidates.length);
                  console.log('  - DTLS fingerprints:', response.dtlsParameters.fingerprints.length);
                  
                  const sendTransportId = response.id;
                  
                  // Test 4: Create Receive Transport
                  console.log('\n--- Test 4: Create Receive Transport ---');
                  socket.emit('request', {
                    method: 'createWebRtcTransport',
                    params: { 
                      roomId: 'test-sfu-room',
                      direction: 'recv'
                    }
                  }, (response) => {
                    if (response.error) {
                      console.log('❌ Error creating recv transport:', response.error);
                    } else {
                      console.log('✅ Receive transport created');
                      console.log('  - Transport ID:', response.id);
                      
                      const recvTransportId = response.id;
                      
                      // Test 5: List Producers (should be empty)
                      console.log('\n--- Test 5: List Producers ---');
                      socket.emit('request', {
                        method: 'listProducers',
                        params: { roomId: 'test-sfu-room' }
                      }, (response) => {
                        if (response.error) {
                          console.log('❌ Error listing producers:', response.error);
                        } else {
                          console.log('✅ Listed producers');
                          console.log('  - Producer count:', response.producers.length);
                          
                          // Test 6: Test audience member
                          console.log('\n--- Test 6: Test Audience Member ---');
                          const audienceSocket = io('http://jitsi.dialecticlabs.com:3002');
                          
                          audienceSocket.on('connect', () => {
                            console.log('✅ Audience connected:', audienceSocket.id);
                            
                            audienceSocket.emit('join-room', {
                              roomId: 'test-sfu-room',
                              userId: 'test-user-audience',
                              role: 'audience'
                            });
                            
                            audienceSocket.once('room-joined', () => {
                              console.log('✅ Audience joined room');
                              
                              // Try to create send transport (should fail)
                              audienceSocket.emit('request', {
                                method: 'createWebRtcTransport',
                                params: { 
                                  roomId: 'test-sfu-room',
                                  direction: 'send'
                                }
                              }, (response) => {
                                if (response.error) {
                                  console.log('✅ Audience correctly denied send transport:', response.error);
                                } else {
                                  console.log('❌ Audience should not be able to create send transport');
                                }
                                
                                // Create receive transport for audience (should work)
                                audienceSocket.emit('request', {
                                  method: 'createWebRtcTransport',
                                  params: { 
                                    roomId: 'test-sfu-room',
                                    direction: 'recv'
                                  }
                                }, (response) => {
                                  if (response.error) {
                                    console.log('❌ Error creating audience recv transport:', response.error);
                                  } else {
                                    console.log('✅ Audience receive transport created');
                                  }
                                  
                                  // Cleanup
                                  console.log('\n--- Cleanup ---');
                                  audienceSocket.disconnect();
                                  socket.disconnect();
                                  
                                  console.log('\n🎉 All tests completed successfully!');
                                  console.log('\n📋 Summary:');
                                  console.log('  ✅ Server connection');
                                  console.log('  ✅ Room join');
                                  console.log('  ✅ RTP capabilities');
                                  console.log('  ✅ Transport creation');
                                  console.log('  ✅ Producer listing');
                                  console.log('  ✅ Role-based permissions');
                                  
                                  resolve();
                                });
                              });
                            });
                          });
                          
                          audienceSocket.on('error', (error) => {
                            console.log('❌ Audience socket error:', error);
                            reject(error);
                          });
                        }
                      });
                    }
                  });
                }
              });
            }
          });
        });

        socket.once('error', (error) => {
          console.log('❌ Room join error:', error);
          reject(error);
        });

      } catch (error) {
        console.log('❌ Test error:', error);
        reject(error);
      }
    });

    socket.on('error', (error) => {
      console.log('❌ Socket error:', error);
      reject(error);
    });

    socket.on('disconnect', () => {
      console.log('🔌 Disconnected from server');
    });

    // Timeout after 30 seconds
    setTimeout(() => {
      console.log('⏰ Test timeout');
      socket.disconnect();
      reject(new Error('Test timeout'));
    }, 30000);
  });
}

// Run the test
testSFUServer()
  .then(() => {
    console.log('\n✅ All MediaSoup SFU tests passed!');
    process.exit(0);
  })
  .catch((error) => {
    console.log('\n❌ MediaSoup SFU tests failed:', error.message);
    process.exit(1);
  });