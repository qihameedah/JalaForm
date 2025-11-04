import 'dart:async';

/// Simple in-memory cache with TTL (Time To Live) support
///
/// Provides caching with automatic expiration based on time.
/// Useful for caching API responses, computed values, etc.
class CacheManager<K, V> {
  final Map<K, _CacheEntry<V>> _cache = {};
  final Duration defaultTtl;

  CacheManager({this.defaultTtl = const Duration(minutes: 5)});

  /// Get a value from cache
  ///
  /// Returns null if key doesn't exist or has expired
  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    return entry.value;
  }

  /// Put a value in cache
  ///
  /// [ttl] overrides the default TTL for this specific entry
  void put(K key, V value, {Duration? ttl}) {
    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  /// Check if cache has a non-expired value for the key
  bool has(K key) {
    final entry = _cache[key];
    if (entry == null) return false;

    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }

    return true;
  }

  /// Remove a specific key from cache
  void remove(K key) {
    _cache.remove(key);
  }

  /// Clear all cache entries
  void clear() {
    _cache.clear();
  }

  /// Remove all expired entries
  void cleanupExpired() {
    _cache.removeWhere((key, entry) => entry.isExpired);
  }

  /// Get or compute a value
  ///
  /// If the key exists in cache and is not expired, returns the cached value.
  /// Otherwise, computes the value using [compute], caches it, and returns it.
  Future<V> getOrCompute(K key, Future<V> Function() compute, {Duration? ttl}) async {
    final cached = get(key);
    if (cached != null) return cached;

    final value = await compute();
    put(key, value, ttl: ttl);
    return value;
  }

  /// Get cache statistics
  CacheStats get stats {
    int expired = 0;
    int active = 0;

    for (var entry in _cache.values) {
      if (entry.isExpired) {
        expired++;
      } else {
        active++;
      }
    }

    return CacheStats(
      totalEntries: _cache.length,
      activeEntries: active,
      expiredEntries: expired,
    );
  }

  /// Get the number of entries in cache (including expired)
  int get size => _cache.length;

  /// Start automatic cleanup timer
  ///
  /// Runs cleanup every [interval] to remove expired entries
  Timer startAutoCleanup({Duration interval = const Duration(minutes: 1)}) {
    return Timer.periodic(interval, (_) => cleanupExpired());
  }
}

/// Internal cache entry with expiration
class _CacheEntry<V> {
  final V value;
  final DateTime expiresAt;

  _CacheEntry({required this.value, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Cache statistics
class CacheStats {
  final int totalEntries;
  final int activeEntries;
  final int expiredEntries;

  const CacheStats({
    required this.totalEntries,
    required this.activeEntries,
    required this.expiredEntries,
  });

  double get hitRate => totalEntries > 0 ? activeEntries / totalEntries : 0.0;

  @override
  String toString() {
    return 'CacheStats(total: $totalEntries, active: $activeEntries, expired: $expiredEntries, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
  }
}
