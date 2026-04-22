'use client';

import { useEffect, useRef, useCallback, useState } from 'react';
import { io, Socket } from 'socket.io-client';

// =====================================================================
// WEBSOCKET HOOK - Real-time connection to ERP WebSocket service
// Provides auto-reconnect, auth, event subscription, and online presence
// =====================================================================

interface UseWebSocketOptions {
  userId: string;
  role: string;
  unitId?: string;
  userName?: string;
  authToken?: string;
  enabled?: boolean;
}

interface UseWebSocketReturn {
  socket: Socket | null;
  isConnected: boolean;
  onlineCount: number;
  onlineUserIds: string[];
  emit: (event: string, data: any) => void;
  on: (event: string, handler: (...args: any[]) => void) => void;
  off: (event: string, handler: (...args: any[]) => void) => void;
}

// Singleton socket to prevent multiple connections
let _socket: Socket | null = null;
let _lastAuthData: { userId: string; role: string; unitId: string; userName: string; authToken: string } | null = null;
let _refCount = 0;

function getOrCreateSocket(): Socket {
  if (_socket) return _socket;

  _socket = io('/?XTransformPort=3004', {
    path: '/',
    transports: ['websocket', 'polling'],
    reconnection: true,
    reconnectionAttempts: 10,
    reconnectionDelay: 2000,
    reconnectionDelayMax: 10000,
    timeout: 20000,
    autoConnect: true,
  });

  // Graceful fallback: stop reconnecting after max attempts exhausted
  _socket.on('reconnect_failed', () => {
    console.warn(
      '[WS] Max reconnection attempts reached. WebSocket service may be unavailable on this deployment.',
    );
    console.info(
      '[WS] Real-time features are disabled. You can refresh the page to retry.',
    );
  });

  // Global connection logging — re-auth on reconnect
  _socket.on('connect', () => {
    console.log('[WS] Connected:', _socket?.id);
    if (_lastAuthData) {
      _socket?.emit('register', {
        userId: _lastAuthData.userId,
        roles: [_lastAuthData.role],
        unitId: _lastAuthData.unitId,
        userName: _lastAuthData.userName,
      });
    }
  });

  _socket.on('disconnect', (reason) => {
    console.log('[WS] Disconnected:', reason);
  });

  _socket.on('connect_error', (err) => {
    console.warn('[WS] Connection error:', err.message);
    // If we've exhausted reconnection attempts, disable further attempts
    if (_socket && !_socket.connected) {
      const activeReconnect = _socket.io?.opts?.reconnection;
      if (activeReconnect && _socket.io?.engine?.reconnectAttemptsRemaining === 0) {
        console.warn('[WS] Connection failed after max retries. Disabling reconnection.');
        _socket.io.opts.reconnection = false;
      }
    }
  });

  return _socket;
}

/** Force-disconnect the singleton socket (e.g., on logout) */
export function disconnectWebSocket(): void {
  if (_socket) {
    console.log('[WS] Force disconnecting singleton socket');
    _socket.disconnect();
    _socket = null;
    _lastAuthData = null;
    _refCount = 0;
  }
}

export function useWebSocket(options: UseWebSocketOptions): UseWebSocketReturn {
  const { userId, role, unitId = '', userName = '', authToken = '', enabled = true } = options;
  const [isConnected, setIsConnected] = useState(false);
  const [onlineCount, setOnlineCount] = useState(0);
  const [onlineUserIds, setOnlineUserIds] = useState<string[]>([]);
  // Support multiple handlers per event using Set
  const handlersRef = useRef<Map<string, Set<(...args: any[]) => void>>>(new Map());

  useEffect(() => {
    if (!enabled || !userId) return;

    const socket = getOrCreateSocket();
    _refCount++;

    // Store auth data for reconnection
    _lastAuthData = { userId, role, unitId, userName, authToken };

    // Register with server using 'register' event (matches server-side listener)
    const registerWithServer = () => {
      socket.emit('register', {
        userId,
        roles: [role],
        unitId,
        userName,
      });
    };

    // Auth immediately if connected, otherwise the global 'connect' handler will do it
    if (socket.connected) {
      registerWithServer();
    }

    // Track connection state
    const onConnect = () => {
      setIsConnected(true);
      // Re-auth on every reconnection
      registerWithServer();
    };
    const onDisconnect = () => setIsConnected(false);
    const onPresence = (data: { onlineCount: number; onlineUserIds: string[] }) => {
      setOnlineCount(data.onlineCount);
      setOnlineUserIds(data.onlineUserIds);
    };

    socket.on('connect', onConnect);
    socket.on('disconnect', onDisconnect);
    socket.on('presence:update', onPresence);

    // Re-attach all registered handlers
    handlersRef.current.forEach((handlerSet, event) => {
      handlerSet.forEach(handler => socket.on(event, handler));
    });

    return () => {
      _refCount--;
      socket.off('connect', onConnect);
      socket.off('disconnect', onDisconnect);
      socket.off('presence:update', onPresence);

      // Remove all registered handlers
      handlersRef.current.forEach((handlerSet, event) => {
        handlerSet.forEach(handler => socket.off(event, handler));
      });

      if (_refCount <= 0 && _socket) {
        console.log('[WS] Destroying singleton socket');
        _socket.disconnect();
        _socket = null;
        _lastAuthData = null;
        _refCount = 0;
      }
    };
  }, [enabled, userId, role, unitId, userName, authToken]);

  const emit = useCallback((event: string, data: any) => {
    if (_socket?.connected) {
      _socket.emit(event, data);
    }
  }, []);

  const on = useCallback((event: string, handler: (...args: any[]) => void) => {
    // Support multiple handlers per event
    if (!handlersRef.current.has(event)) {
      handlersRef.current.set(event, new Set());
    }
    handlersRef.current.get(event)!.add(handler);
    if (_socket?.connected) {
      _socket.on(event, handler);
    }
  }, []);

  const off = useCallback((event: string, handler: (...args: any[]) => void) => {
    const handlerSet = handlersRef.current.get(event);
    if (handlerSet) {
      handlerSet.delete(handler);
      if (handlerSet.size === 0) {
        handlersRef.current.delete(event);
      }
    }
    if (_socket?.connected) {
      _socket.off(event, handler);
    }
  }, []);

  return {
    socket: _socket,
    isConnected,
    onlineCount,
    onlineUserIds,
    emit,
    on,
    off,
  };
}
