import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as geocoding;

class DistanceService {
  static const String _googleApiKey = 'AIzaSyB4_iKSum_8cH_fcEGn4Uix2ViY49UtQNg';
  static const String _directionsApiUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  /// Calculate real road distance between two addresses using Google Maps Directions API
  static Future<String> calculateRoadDistance(String fromAddress, String toAddress) async {
    try {
      // First, get coordinates for both addresses
      final fromCoords = await _getCoordinates(fromAddress);
      final toCoords = await _getCoordinates(toAddress);

      if (fromCoords == null || toCoords == null) {
        return 'N/A';
      }

      // Get road distance using Google Maps Directions API
      final url = '$_directionsApiUrl?origin=${fromCoords.latitude},${fromCoords.longitude}&destination=${toCoords.latitude},${toCoords.longitude}&key=$_googleApiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['status'] == 'OK' && jsonResponse['routes'].isNotEmpty) {
          final route = jsonResponse['routes'][0];
          final leg = route['legs'][0];
          final distanceInMeters = leg['distance']['value'];
          final distanceInKm = distanceInMeters / 1000;
          
          return '${distanceInKm.toStringAsFixed(2)} km';
        }
      }
      
      return 'N/A';
    } catch (e) {
      print('Error calculating road distance: $e');
      return 'N/A';
    }
  }

  /// Calculate real road distance between coordinates using Google Maps Directions API
  static Future<String> calculateRoadDistanceFromCoords(double fromLat, double fromLng, double toLat, double toLng) async {
    try {
      final url = '$_directionsApiUrl?origin=$fromLat,$fromLng&destination=$toLat,$toLng&key=$_googleApiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['status'] == 'OK' && jsonResponse['routes'].isNotEmpty) {
          final route = jsonResponse['routes'][0];
          final leg = route['legs'][0];
          final distanceInMeters = leg['distance']['value'];
          final distanceInKm = distanceInMeters / 1000;
          
          return '${distanceInKm.toStringAsFixed(2)} km';
        }
      }
      
      return 'N/A';
    } catch (e) {
      print('Error calculating road distance from coordinates: $e');
      return 'N/A';
    }
  }

  /// Get coordinates for an address
  static Future<LatLng?> _getCoordinates(String address) async {
    try {
      final locations = await geocoding.locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      print('Error getting coordinates for address: $address, Error: $e');
    }
    return null;
  }

  /// Get detailed route information including distance and duration
  static Future<Map<String, dynamic>?> getRouteDetails(String fromAddress, String toAddress) async {
    try {
      final fromCoords = await _getCoordinates(fromAddress);
      final toCoords = await _getCoordinates(toAddress);

      if (fromCoords == null || toCoords == null) {
        return null;
      }

      final url = '$_directionsApiUrl?origin=${fromCoords.latitude},${fromCoords.longitude}&destination=${toCoords.latitude},${toCoords.longitude}&key=$_googleApiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['status'] == 'OK' && jsonResponse['routes'].isNotEmpty) {
          final route = jsonResponse['routes'][0];
          final leg = route['legs'][0];
          
          return {
            'distance': leg['distance']['value'], // in meters
            'distanceText': leg['distance']['text'],
            'duration': leg['duration']['value'], // in seconds
            'durationText': leg['duration']['text'],
            'startLocation': leg['start_location'],
            'endLocation': leg['end_location'],
          };
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting route details: $e');
      return null;
    }
  }
}

class LatLng {
  final double latitude;
  final double longitude;
  
  LatLng(this.latitude, this.longitude);
}
