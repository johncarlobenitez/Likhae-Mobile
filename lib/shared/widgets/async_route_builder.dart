import 'dart:async';

import 'package:flutter/material.dart';

class RouteLoadingPage extends StatelessWidget {
  const RouteLoadingPage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const Center(child: CircularProgressIndicator()),
  );
}

/// Owns the request for one route, so parent/theme rebuilds never restart it.
/// Retained tabs can revalidate when activated without discarding page state.
class AsyncRouteBuilder<T> extends StatefulWidget {
  const AsyncRouteBuilder({
    super.key,
    required this.load,
    required this.builder,
    this.requestKey,
    this.refreshOnActivate = false,
  });

  final Future<T> Function() load;
  final AsyncWidgetBuilder<T> builder;
  final Object? requestKey;
  final bool refreshOnActivate;

  @override
  State<AsyncRouteBuilder<T>> createState() => _AsyncRouteBuilderState<T>();
}

class _AsyncRouteBuilderState<T> extends State<AsyncRouteBuilder<T>>
    with WidgetsBindingObserver {
  AsyncSnapshot<T> _snapshot = AsyncSnapshot<T>.nothing();
  int _generation = 0;
  bool _loading = false;
  bool _active = true;
  bool _wasCovered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load({bool replace = false}) async {
    if (_loading && !replace) return;
    final generation = ++_generation;
    _loading = true;
    _snapshot = replace
        ? AsyncSnapshot<T>.waiting()
        : _snapshot.inState(ConnectionState.waiting);
    try {
      final value = await widget.load();
      if (!mounted || generation != _generation) return;
      setState(
        () => _snapshot = AsyncSnapshot.withData(ConnectionState.done, value),
      );
    } catch (error, stack) {
      if (!mounted || generation != _generation) return;
      // Keep a usable page on refresh failure; an initial failure still reaches
      // the route's existing error UI. Pull-to-refresh remains available.
      final refreshing = _snapshot.hasData;
      setState(
        () => _snapshot = refreshing
            ? _snapshot.inState(ConnectionState.done)
            : AsyncSnapshot.withError(ConnectionState.done, error, stack),
      );
      if (refreshing && _active && !_wasCovered) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not refresh this page. Pull down to try again.',
            ),
          ),
        );
      }
    } finally {
      if (generation == _generation) _loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant AsyncRouteBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestKey != widget.requestKey) _load(replace: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    final covered = ModalRoute.of(context)?.isCurrent == false;
    final becameVisible = (!_active && active) || (_wasCovered && !covered);
    _active = active;
    _wasCovered = covered;
    if (becameVisible && widget.refreshOnActivate) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _active &&
        !_wasCovered &&
        widget.refreshOnActivate) {
      setState(() {
        unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.builder(context, _snapshot),
      if (_snapshot.hasData &&
          _snapshot.connectionState == ConnectionState.waiting)
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(child: LinearProgressIndicator(minHeight: 2)),
        ),
    ],
  );
}
