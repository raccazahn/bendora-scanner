import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/event_pack_model.dart';
import '../models/ticket_model.dart';
import '../models/scan_record_model.dart';

class ApiService {
  static final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000';
  static const String _tokenKey = 'auth_token';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Future<Map<String, String>> get _authHeaders async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login/'),
        headers: _headers,
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['access'] != null) {
          await saveToken(data['access']);
          return data;
        }
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getAssignment() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/scanner/assignments/'),
        headers: await _authHeaders,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Assignment error: $e');
      return null;
    }
  }

  static Future<EventPackModel?> getEventPack(int currentVersion) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/scanner/event-pack/'),
        headers: await _authHeaders,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['version'] <= currentVersion) {
          return null; // Already up to date
        }
        
        final tickets = (data['tickets'] as List)
            .map((t) => TicketModel.fromMap(t))
            .toList();
            
        return EventPackModel.fromMap({
          'version': data['version'],
          'event_id': data['event']['id'],
          'event_name': data['event']['name'],
          'gate_id': data['gate']['id'],
          'gate_name': data['gate']['name'],
          'public_key': data['public_key'],
          'generated_at': data['generated_at'],
        }, tickets);
      }
      return null;
    } catch (e) {
      print('Event pack error: $e');
      return null;
    }
  }

  static Future<bool> syncScans(List<ScanRecordModel> scans) async {
    if (scans.isEmpty) return true;
    
    try {
      final payload = {
        'scans': scans.map((s) => {
          'local_scan_id': s.localScanId,
          'ticket_public_id': s.ticketPublicId,
          'scanned_at': s.scannedAt.toIso8601String(),
          'scan_result': s.scanResult,
          'event_id': s.eventId,
          'gate_id': s.gateId,
        }).toList(),
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/scanner/scans/bulk-sync/'),
        headers: await _authHeaders,
        body: jsonEncode(payload),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Sync error: $e');
      return false;
    }
  }
}
