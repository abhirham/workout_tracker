import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_service.g.dart';

/// Provider that exposes a stream of connectivity status
@riverpod
Stream<bool> connectivityStream(ConnectivityStreamRef ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    // Check if any connection is not none
    return results.any((result) => result != ConnectivityResult.none);
  });
}

/// Provider for current connectivity status
@riverpod
class ConnectivityStatus extends _$ConnectivityStatus {
  @override
  Future<bool> build() async {
    // Listen to connectivity stream and update state
    ref.listen(connectivityStreamProvider, (_, next) {
      next.whenData((isConnected) {
        state = AsyncValue.data(isConnected);
      });
    });

    // Get initial connectivity status
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}

/// Service to monitor network connectivity
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Check if device is currently online
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  /// Stream that emits connectivity changes
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((results) {
      return results.any((result) => result != ConnectivityResult.none);
    });
  }
}

@riverpod
ConnectivityService connectivityService(ConnectivityServiceRef ref) {
  return ConnectivityService();
}
