// Alternative Socket.IO configuration if OptionBuilder doesn't work
      _socket = io.io(serverUri, {
        'transports': ['polling'],
        'autoConnect': false, 
        'forceNew': true,
        'timeout': 30000,
        'polling': {
          'extraHeaders': {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          }
        },
        'upgrade': false,
        'rememberUpgrade': false,
        'tryAllTransports': false,
      });