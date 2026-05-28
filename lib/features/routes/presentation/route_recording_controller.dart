import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/geo_utils.dart';
import '../domain/models/transit_route.dart';

enum RouteRecordingStartResult {
  started,
  alreadyRecording,
  permissionDenied,
  locationServiceDisabled,
}

class RouteRecordingController extends ChangeNotifier {
  StreamSubscription<Position>? _positionSubscription;

  bool _isRecording = false;
  final List<LatLng> _recordedPoints = [];
  DateTime? _startedAt;
  DateTime? _endedAt;
  double _currentSpeedKmh = 0;
  bool _needsTransportConfirmation = false;

  bool get isRecording => _isRecording;
  List<LatLng> get recordedPoints => List.unmodifiable(_recordedPoints);
  int get pointsCount => _recordedPoints.length;
  DateTime? get startedAt => _startedAt;
  DateTime? get endedAt => _endedAt;
  double get currentSpeedKmh => _currentSpeedKmh;
  bool get needsTransportConfirmation => _needsTransportConfirmation;

  double get averageSpeedKmh {
    final start = _startedAt;
    final end = _endedAt ?? DateTime.now();
    if (start == null || _recordedPoints.length < 2) return 0;
    final distanceKm =
        GeoUtils.polylineDistanceInMeters(_recordedPoints) / 1000;
    final hours = end.difference(start).inSeconds / 3600;
    if (hours <= 0) return 0;
    return distanceKm / hours;
  }

  double get averageSpeedForSaving {
    final avg = averageSpeedKmh;
    return avg > 0 ? avg : 18;
  }

  Future<RouteRecordingStartResult> start() async {
    if (_isRecording) return RouteRecordingStartResult.alreadyRecording;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return RouteRecordingStartResult.locationServiceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return RouteRecordingStartResult.permissionDenied;
    }

    _isRecording = true;
    _startedAt = DateTime.now();
    _endedAt = null;
    _recordedPoints.clear();
    _currentSpeedKmh = 0;
    _needsTransportConfirmation = false;
    notifyListeners();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen(_addPosition, onError: (_) => unawaited(stop()));

    return RouteRecordingStartResult.started;
  }

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isRecording = false;
    _endedAt = DateTime.now();
    notifyListeners();
  }

  void confirmTransportType(TransportType type) {
    _needsTransportConfirmation = false;
    notifyListeners();
  }

  void dismissTransportConfirmation() {
    _needsTransportConfirmation = false;
    notifyListeners();
  }

  LocationSettings _buildLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 12,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Ruta Facil esta grabando',
          notificationText:
              'El recorrido seguira registrandose hasta que presiones Terminar.',
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 12,
        activityType: ActivityType.automotiveNavigation,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 12,
    );
  }

  void _addPosition(Position position) {
    final point = LatLng(position.latitude, position.longitude);
    final speedKmh = (position.speed * 3.6).clamp(0, 160).toDouble();

    _currentSpeedKmh = speedKmh;
    if (_recordedPoints.isEmpty ||
        GeoUtils.distanceInMeters(_recordedPoints.last, point) >= 10) {
      _recordedPoints.add(point);
    }

    if (speedKmh >= 12 && !_needsTransportConfirmation) {
      _needsTransportConfirmation = true;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
