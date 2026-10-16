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
    this.refreshInterval = const Duration(seconds: 30),
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
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          ModalRoute.of(context)?.isCurrent != false) {
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

        if (_data == null &&
            snapshot.connectionState == ConnectionState.waiting) {
          return _statusPage(
            children: const <Widget>[
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Color(0xFF561C17),
                  strokeWidth: 3,
                  semanticsLabel: 'Loading rider data',
                ),
              ),
              SizedBox(height: 14),
              Text('Loading rider data...', textAlign: TextAlign.center),
            ],
          );
        }

        final Object? error = snapshot.error ?? _error;
        if (_data == null && error != null) {
          return _statusPage(
            children: <Widget>[
              const Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: Color(0xFF561C17),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to load rider data',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B211B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString().replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => unawaited(_refresh()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          );
        }

        return widget.builder(context, _data, error, _refresh);
      },
    );
  }

  Widget _statusPage({required List<Widget> children}) {
    // These states replace the screen's Scaffold, so provide a Material text
    // style here too (otherwise Flutter shows its red/yellow fallback style).
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Color(0xFF987865),
                fontSize: 14,
                height: 1.5,
                decoration: TextDecoration.none,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ),
    );
  }
}
