import 'dart:async';

import 'package:flutter/material.dart';

typedef RiderApiPageBuilder<T> =
    Widget Function(
      BuildContext context,
      T? data,
      Object? error,
      Future<void> Function() refresh,
    );

class RiderApiLoader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final RiderApiPageBuilder<T> builder;
  final Duration? refreshInterval;

  const RiderApiLoader({
    super.key,
    required this.load,
    required this.builder,
    this.refreshInterval,
  });

  @override
  State<RiderApiLoader<T>> createState() => _RiderApiLoaderState<T>();
}

class _RiderApiLoaderState<T> extends State<RiderApiLoader<T>>
    with WidgetsBindingObserver {
  late Future<T> _future;
  T? _data;
  Object? _error;
  Timer? _refreshTimer;
  bool _requestInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
    _startRefreshTimer();
  }

  Future<T> _load() async {
    _requestInFlight = true;
    try {
      final T data = await widget.load();
      _data = data;
      _error = null;
      return data;
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _requestInFlight = false;
    }
  }

  Future<void> _refresh() async {
    if (_requestInFlight) {
      return;
    }
    final Future<T> request = _load();
    if (mounted) {
      setState(() {
        _future = request;
      });
    } else {
      _future = request;
    }
    try {
      await request;
    } catch (_) {
      // The page builder receives this error and renders it in the screen.
    }
  }

  void _startRefreshTimer() {
    final Duration? interval = widget.refreshInterval;
    if (interval == null || interval <= Duration.zero) {
      return;
    }
    _refreshTimer = Timer.periodic(interval, (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
        if (snapshot.hasData) {
          _data = snapshot.data;
        }
        return widget.builder(
          context,
          _data,
          snapshot.error ?? _error,
          _refresh,
        );
      },
    );
  }
}
