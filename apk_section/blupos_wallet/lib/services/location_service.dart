import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  final StreamController<bool> _locationStateController = StreamController.broadcast();
  final StreamController<String> _addressController = StreamController.broadcast();

  String _address = 'Location Not Set';
  bool _hasLocation = false;

  LocationService() {
    _initializeLocation();
  }

  Stream<bool> get onLocationStateChanged => _locationStateController.stream;
  Stream<String> get onAddressChanged => _addressController.stream;

  String get address => _address;
  bool get hasLocation => _hasLocation;

  Future<void> _initializeLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _updateLocationState(false);
        _updateAddress('Location services disabled');
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied) {
          _updateLocationState(false);
          _updateAddress('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _updateLocationState(false);
        _updateAddress('Location permission permanently denied');
        return;
      }

      // Check if we have a saved location
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        await _updateLocationWithPosition(position);
      } else {
        // Get current location
        final currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await _updateLocationWithPosition(currentPosition);
      }
    } catch (e) {
      _updateLocationState(false);
      _updateAddress('Error getting location: $e');
    }
  }

  Future<void> _updateLocationWithPosition(Position position) async {
    try {
      // Since geocoding package is not available, use coordinates as address
      final address = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
      _updateLocationState(true);
      _updateAddress(address);
    } catch (e) {
      _updateLocationState(true);
      _updateAddress('Location found');
    }
  }

  void _updateLocationState(bool hasLocation) {
    _hasLocation = hasLocation;
    _locationStateController.add(hasLocation);
  }

  void _updateAddress(String address) {
    _address = address;
    _addressController.add(address);
  }

  Future<String> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission != LocationPermission.whileInUse && newPermission != LocationPermission.always) {
          return 'Location permission denied';
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _updateLocationWithPosition(position);
      return _address;
    } catch (e) {
      _updateAddress('Error getting location: $e');
      return 'Error: $e';
    }
  }

  Future<String> checkLocationStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'Location services disabled';
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        return 'Location permission denied';
      }

      if (permission == LocationPermission.deniedForever) {
        return 'Location permission permanently denied';
      }

      if (_hasLocation) {
        return 'Location enabled';
      }

      return 'Location not checked';
    } catch (e) {
      return 'Error checking location: $e';
    }
  }

  Future<void> requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      // Permission granted, try to get location
      await getCurrentLocation();
    } else {
      _updateLocationState(false);
      _updateAddress('Location permission denied');
    }
  }

  void dispose() {
    _locationStateController.close();
    _addressController.close();
  }
}