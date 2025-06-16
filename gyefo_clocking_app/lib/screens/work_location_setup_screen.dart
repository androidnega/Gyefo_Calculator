import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gyefo_clocking_app/services/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WorkLocationSetupScreen extends StatefulWidget {
  final String? userId; // If null, sets company-wide location
  final String? userName;
  
  const WorkLocationSetupScreen({
    super.key,
    this.userId,
    this.userName,
  });

  @override
  State<WorkLocationSetupScreen> createState() => _WorkLocationSetupScreenState();
}

class _WorkLocationSetupScreenState extends State<WorkLocationSetupScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  double _radiusMeters = 100.0;
  bool _isLoading = false;
  Map<String, dynamic>? _currentWorkLocation;

  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _loadExistingLocation();
  }

  Future<void> _loadExistingLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      _currentWorkLocation = await LocationService.getWorkLocation(userId);
      
      if (_currentWorkLocation != null) {
        _selectedLocation = LatLng(
          _currentWorkLocation!['latitude'],
          _currentWorkLocation!['longitude'],
        );
        _radiusMeters = _currentWorkLocation!['radiusMeters'] ?? 100.0;
        _updateMapMarkers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading location: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Position? position = await LocationService.getCurrentPosition();
      if (position != null) {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _updateMapMarkers();
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation!, 16.0),
        );
      } else {
        _showError('Unable to get current location');
      }
    } catch (e) {
      _showError('Error getting location: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _updateMapMarkers();
  }

  void _updateMapMarkers() {
    if (_selectedLocation == null) return;

    _markers.clear();
    _circles.clear();

    _markers.add(
      Marker(
        markerId: const MarkerId('work_location'),
        position: _selectedLocation!,
        infoWindow: InfoWindow(
          title: widget.userId != null 
              ? '${widget.userName ?? "Worker"} Workplace'
              : 'Company Workplace',
          snippet: 'Radius: ${_radiusMeters.round()}m',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    _circles.add(
      Circle(
        circleId: const CircleId('work_zone'),
        center: _selectedLocation!,
        radius: _radiusMeters,
        fillColor: Colors.blue.withValues(alpha: 0.2),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      ),
    );

    setState(() {});
  }

  Future<void> _saveLocation() async {
    if (_selectedLocation == null) {
      _showError('Please select a location on the map');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool success;
      if (widget.userId != null) {
        // Set user-specific location
        success = await LocationService.setUserWorkLocation(
          widget.userId!,
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
          _radiusMeters,
        );
      } else {
        // Set company-wide location
        // For now, we'll use the current user's company ID
        // In a real app, you'd get this from the manager's profile
        String companyId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
        success = await LocationService.setCompanyWorkLocation(
          companyId,
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
          _radiusMeters,
        );
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Work location saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        _showError('Failed to save location');
      }
    } catch (e) {
      _showError('Error saving location: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.userId != null 
              ? 'Set Worker Location'
              : 'Set Company Location',
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (_selectedLocation != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveLocation,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info Panel
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userId != null 
                            ? 'Set workplace location for ${widget.userName ?? "worker"}'
                            : 'Set company-wide workplace location',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap on the map to set the workplace location. Workers will be required to clock in/out within the specified radius.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      
                      // Radius Slider
                      Text(
                        'Allowed Radius: ${_radiusMeters.round()}m',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Slider(
                        value: _radiusMeters,
                        min: 50.0,
                        max: 500.0,
                        divisions: 18,
                        label: '${_radiusMeters.round()}m',
                        onChanged: (value) {
                          setState(() {
                            _radiusMeters = value;
                          });
                          _updateMapMarkers();
                        },
                      ),
                    ],
                  ),
                ),
                
                // Map
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation ?? const LatLng(5.6037, -0.1870), // Default to Accra
                      zoom: 16.0,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      if (_selectedLocation != null) {
                        controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_selectedLocation!, 16.0),
                        );
                      }
                    },
                    onTap: _onMapTap,
                    markers: _markers,
                    circles: _circles,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                  ),
                ),
                
                // Bottom Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _getCurrentLocation,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Use Current Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _selectedLocation == null || _isLoading ? null : _saveLocation,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
