/// Shares work already in progress. Completed values are retained only when
/// the caller explicitly supplies a positive lifetime.
class AsyncCache<K, V> {
  AsyncCache({this.maximumEntries = 32, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final int maximumEntries;
  final DateTime Function() _now;
  final _values = <K, ({V value, DateTime expires})>{};
  final _pending = <K, Future<V>>{};
  int _generation = 0;

  Future<V> load(
    K key,
    Future<V> Function() fetch, {
    Duration lifetime = Duration.zero,
    bool refresh = false,
  }) {
    if (refresh) _values.remove(key);
    final cached = _values.remove(key);
    if (cached != null && cached.expires.isAfter(_now())) {
      _values[key] = cached;
      return Future<V>.value(cached.value);
    }
    final pending = _pending[key];
    if (pending != null) return pending;
    final generation = _generation;
    late final Future<V> future;
    future = Future<V>.sync(fetch)
        .then((value) {
          if (_generation == generation && lifetime > Duration.zero) {
            _values[key] = (value: value, expires: _now().add(lifetime));
            while (_values.length > maximumEntries) {
              _values.remove(_values.keys.first);
            }
          }
          return value;
        })
        .whenComplete(() {
          if (identical(_pending[key], future)) _pending.remove(key);
        });
    _pending[key] = future;
    return future;
  }

  /// Requests started before invalidation cannot populate this cache again.
  void clear() {
    _generation++;
    _values.clear();
    _pending.clear();
  }
}
