import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP client for calling the RIHLAH NestJS backend.
///
/// Automatically attaches the Firebase Auth ID token as a Bearer token
/// and refreshes it when expired. All API repositories use this.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  /// Change this to your deployed Cloud Run URL in production.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  final _client = http.Client();

  Future<Map<String, dynamic>> get(String path) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.get(
      uri,
      headers: _headers(token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.patch(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> getList(String path) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.get(
      uri,
      headers: _headers(token),
    );
    final data = _handleResponse(response);
    if (data['data'] is List) return data['data'] as List<dynamic>;
    if (data is List) return data as List<dynamic>;
    return [];
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<String> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final token = await user.getIdToken(true); // force refresh if needed
    if (token == null) throw Exception('Failed to get ID token');
    return token;
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final body = response.body.isNotEmpty ? response.body : 'Unknown error';
    throw ApiException(response.statusCode, body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
