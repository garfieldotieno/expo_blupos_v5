import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'http://localhost:5000'; // Default BluPOS URL
  static String? _bluposMasterUrl;

  // Set BluPOS master URL after discovery
  static void setMasterUrl(String url) {
    _bluposMasterUrl = url;
  }

  // Get current base URL (discovered or default)
  static String get baseUrlWithMaster {
    return _bluposMasterUrl ?? baseUrl;
  }

  // Generic GET request
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlWithMaster$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generic POST request
  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlWithMaster$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generic PUT request
  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrlWithMaster$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generic DELETE request
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrlWithMaster$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Auto-discover BluPOS master server
  static Future<String?> discoverMasterServer() async {
    // Common IP ranges to scan
    const commonPorts = [5000, 8080, 8000];
    const commonIPs = [
      '192.168.1.100', // Common router IP
      '192.168.0.1',
      '10.0.0.1',
      '192.168.1.1',
    ];

    for (final ip in commonIPs) {
      for (final port in commonPorts) {
        try {
          final testUrl = 'http://$ip:$port/api/status';
          final response = await http.get(
            Uri.parse(testUrl),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 2));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['status'] == 'blupos_master') {
              final masterUrl = 'http://$ip:$port';
              setMasterUrl(masterUrl);
              return masterUrl;
            }
          }
        } catch (e) {
          // Continue scanning
          continue;
        }
      }
    }

    // If no server found, keep default
    return null;
  }

  // Test connection to BluPOS master
  static Future<bool> testConnection() async {
    try {
      final response = await get('/api/status');
      return response['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }
}
