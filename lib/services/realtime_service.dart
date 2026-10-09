import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../core/storage/token_storage.dart';

class RealtimeEvent {
  final String name;
  final String channel;
  final Map<String, dynamic> data;

  const RealtimeEvent({
    required this.name,
    required this.channel,
    required this.data,
  });
}

class RealtimeSubscription {
  final Stream<RealtimeEvent> events;
  final Future<void> Function() _close;

  const RealtimeSubscription(this.events, this._close);

  Future<void> cancel() => _close();
}

class LikhaeRealtimeService {
  LikhaeRealtimeService._();

  static WebSocketChannel? _socket;
  static String? _socketId;
  static Future<void>? _connecting;
  static Timer? _reconnectTimer;
  static int _reconnectAttempt = 0;
  static Completer<void>? _handshake;
  static final Map<String, _ChannelState> _channels =
      <String, _ChannelState>{};

  static Future<RealtimeSubscription> subscribe(String channel) async {
    final String logicalChannel = _normalizeChannel(channel);
    if (!AppConfig.realtimeEnabled) {
      throw const RealtimeUnavailableException(
        'Realtime is not configured. Supply REVERB_APP_KEY at build time.',
      );
    }

    final _ChannelState state = _channels.putIfAbsent(
      logicalChannel,
      () => _ChannelState(logicalChannel),
    );
    state.references++;

    try {
      await _ensureConnected();
      await _subscribeChannel(state);
    } catch (_) {
      state.references--;
      if (state.references <= 0) {
        _channels.remove(logicalChannel);
        await state.controller.close();
      }
      rethrow;
    }

    return RealtimeSubscription(
      state.controller.stream,
      () => _release(logicalChannel, state),
    );
  }

  static Future<void> _release(String channel, _ChannelState state) async {
    if (state.closed) return;
    state.references--;
    if (state.references > 0) return;

    _channels.remove(channel);
    if (state.subscribed) {
      _send(<String, dynamic>{
        'event': 'pusher:unsubscribe',
        'data': <String, dynamic>{'channel': state.wireName},
      });
    }
    state.closed = true;
    await state.controller.close();
    if (_channels.isEmpty) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      await _socket?.sink.close();
      _socket = null;
      _socketId = null;
    }
  }

  static String _normalizeChannel(String channel) {
    final String value = channel.trim();
    return value.startsWith('private-') ? value.substring(8) : value;
  }

  static Future<void> _ensureConnected() {
    if (_socketId != null && _socket != null) {
      return Future<void>.value();
    }
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  static Future<void> _connect() async {
    final String? token = await TokenStorage.readToken();
    if (token == null || token.trim().isEmpty) {
      throw const RealtimeUnavailableException(
        'A signed-in account is required for realtime updates.',
      );
    }

    final bool secure = AppConfig.reverbScheme.toLowerCase() == 'https';
    final Uri uri = Uri(
      scheme: secure ? 'wss' : 'ws',
      host: AppConfig.reverbHost,
      port: (secure && AppConfig.reverbPort == 443)
          ? null
          : AppConfig.reverbPort,
      path: '/app/${AppConfig.reverbAppKey}',
      queryParameters: const <String, String>{
        'protocol': '7',
        'client': 'likhae_flutter',
        'version': '1.0',
        'flash': 'false',
      },
    );

    final WebSocketChannel socket = WebSocketChannel.connect(uri);
    _socket = socket;
    final Completer<void> handshake = Completer<void>();
    _handshake = handshake;
    socket.stream.listen(
      _handleMessage,
      onError: (Object error, StackTrace stack) {
        if (!handshake.isCompleted) handshake.completeError(error, stack);
        _handleDisconnect();
      },
      onDone: () {
        if (!handshake.isCompleted) {
          handshake.completeError(const RealtimeUnavailableException('Realtime connection closed.'));
        }
        _handleDisconnect();
      },
      cancelOnError: false,
    );

    try {
      await socket.ready;
      await handshake.future.timeout(const Duration(seconds: 12));
      _reconnectAttempt = 0;
    } catch (_) {
      await socket.sink.close();
      _handleDisconnect();
      rethrow;
    } finally {
      if (identical(_handshake, handshake)) _handshake = null;
    }
  }

  static void _handleMessage(dynamic raw) {
    final Map<String, dynamic>? packet = _asMap(raw);
    if (packet == null) return;

    final String event = packet['event']?.toString() ?? '';
    final String channel = packet['channel']?.toString() ?? '';
    final Map<String, dynamic> data = _decodeData(packet['data']);

    if (event == 'pusher:connection_established') {
      _socketId = data['socket_id']?.toString();
      if (_socketId == null || _socketId!.isEmpty) {
        _handshake?.completeError(
          const RealtimeUnavailableException('Reverb did not return a socket id.'),
        );
        return;
      }
      if (!(_handshake?.isCompleted ?? true)) _handshake!.complete();
      for (final _ChannelState state in _channels.values.toList()) {
        unawaited(_subscribeChannel(state).catchError((Object _) {}));
      }
      return;
    }

    if (event == 'pusher:ping') {
      _send(<String, dynamic>{'event': 'pusher:pong', 'data': <String, dynamic>{}});
      return;
    }

    if (event == 'pusher:subscription_succeeded') {
      _channels[_normalizeChannel(channel)]?.subscribed = true;
      return;
    }

    final _ChannelState? state = _channels[_normalizeChannel(channel)];
    if (state != null && !state.closed) {
      state.controller.add(
        RealtimeEvent(name: event, channel: _normalizeChannel(channel), data: data),
      );
    }
  }

  static Future<void> _subscribeChannel(_ChannelState state) async {
    if (state.closed || state.subscribed || state.authenticating || _socketId == null) return;
    state.authenticating = true;

    try {
      final Response<dynamic> response = await ApiClient.post(
        AppConfig.resolveApiUrl('broadcasting/auth'),
        <String, dynamic>{
          'socket_id': _socketId,
          'channel_name': state.wireName,
        },
      );
      final int statusCode = response.statusCode ?? 500;
      if (statusCode < 200 || statusCode >= 300 || response.data is! Map) {
        throw RealtimeUnavailableException(
          'Unable to authorize realtime channel ${state.logicalName}.',
        );
      }

      final Map<String, dynamic> payload =
          Map<String, dynamic>.from(response.data as Map);
      final String auth = payload['auth']?.toString() ?? '';
      if (auth.isEmpty) {
        throw const RealtimeUnavailableException(
          'Realtime channel authorization was empty.',
        );
      }
      _send(<String, dynamic>{
        'event': 'pusher:subscribe',
        'data': <String, dynamic>{'auth': auth, 'channel': state.wireName},
      });
    } finally {
      state.authenticating = false;
    }
  }

  static void _send(Map<String, dynamic> packet) {
    try {
      _socket?.sink.add(jsonEncode(packet));
    } catch (_) {
      _handleDisconnect();
    }
  }

  static void _handleDisconnect() {
    _socket = null;
    _socketId = null;
    for (final _ChannelState state in _channels.values) {
      state.subscribed = false;
    }
    if (_channels.isEmpty || _reconnectTimer != null) return;
    final int exponent = _reconnectAttempt.clamp(0, 4).toInt();
    final int seconds = (1 << exponent).clamp(1, 16).toInt();
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      unawaited(_ensureConnected().catchError((Object _) {}));
    });
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final dynamic decoded = jsonDecode(value);
        return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Map<String, dynamic> _decodeData(dynamic value) {
    final Map<String, dynamic>? map = _asMap(value);
    return map ?? <String, dynamic>{'value': value};
  }
}

class RealtimeUnavailableException implements Exception {
  final String message;

  const RealtimeUnavailableException(this.message);

  @override
  String toString() => message;
}

class _ChannelState {
  final String logicalName;
  final StreamController<RealtimeEvent> controller =
      StreamController<RealtimeEvent>.broadcast();
  int references = 0;
  bool subscribed = false;
  bool authenticating = false;
  bool closed = false;

  _ChannelState(this.logicalName);

  String get wireName => 'private-$logicalName';
}
