import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  final Map<String, String> headers = {
    'Content-Type': 'application/json',
  };

  ApiService({required this.baseUrl});

  Future<Map<String, dynamic>> recognizeFace(String imageBase64) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recognize'),
        headers: headers,
        body: json.encode({
          'image': imageBase64,
          'device_id': 'flutter_app',
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to recognize face: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> addFace(String name, String imageBase64) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add_face'),
        headers: headers,
        body: json.encode({
          'name': name,
          'image': imageBase64,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to add face: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<dynamic>> getKnownFaces() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/faces'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get faces: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> reloadFaces() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reload_faces'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to reload faces: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> getServerStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/status'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Helper method to convert image file to base64
  Future<String> imageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      return base64Image;
    } catch (e) {
      throw Exception('Failed to convert image to base64: $e');
    }
  }

  // Test server connection
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}