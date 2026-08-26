import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ApiService {
  // ⚠️ DEPLOY: Change this URL to your Railway backend URL before building APK
  // LOCAL (emulator):   "http://10.0.2.2:8000/api"
  // PRODUCTION:         "https://erp-project.up.railway.app/api"
  static const String baseUrl = "http://10.0.2.2:8000/api";
  // TODO: Change above to Railway URL before: flutter build apk --release

  // Increased from 5s to 15s for slow mobile networks and file uploads
  static const Duration defaultTimeout = Duration(seconds: 15);

  // ---------- Auth headers helper ----------
  static Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final token = await getToken();
    return {
      if (json) "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // ---------- LOGIN ----------
  static Future<Map<String, dynamic>> facultyLogin(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/faculty/login"),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      ).timeout(defaultTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveSession(data['token'], data['user'], "faculty");
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": data['message'] ?? "Login failed"};
      }
    } catch (e) {
      return {"success": false, "message": "Server connection failed. Check your network."};
    }
  }

  static Future<Map<String, dynamic>> studentLogin(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/student/login"),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      ).timeout(defaultTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveSession(data['token'], data['user'], "student");
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": data['message'] ?? "Login failed"};
      }
    } catch (e) {
      return {"success": false, "message": "Server connection failed. Check your network."};
    }
  }

  static Future<void> _saveSession(
    String token,
    Map<String, dynamic> user,
    String role,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", token);
    await prefs.setString("user", jsonEncode(user));
    await prefs.setString("role", role);
  }

  // ---------- SESSION ----------
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString("token") != null;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString("token");
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString("role");
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString("user");
      if (userStr == null) return null;
      return jsonDecode(userStr);
    } catch (_) {
      return null;
    }
  }

  // Fixed: calls server to invalidate Sanctum token before clearing local session
  static Future<void> logout() async {
    try {
      final headers = await _authHeaders();
      await http.post(
        Uri.parse("$baseUrl/logout"),
        headers: headers,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Even if server call fails, still clear local session
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
  }

  // ---------- Fresh user data from server ----------
  static Future<Map<String, dynamic>?> getStudentMe() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse("$baseUrl/student/me"),
        headers: headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Update local cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("user", jsonEncode(data));
        return data;
      }
    } catch (_) {}
    // Fall back to cached user on error
    return getUser();
  }

  static Future<Map<String, dynamic>?> getFacultyMe() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse("$baseUrl/faculty/me"),
        headers: headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("user", jsonEncode(data));
        return data;
      }
    } catch (_) {}
    return getUser();
  }

  // ---------- Timetable ----------
  static Future<List<dynamic>> getFacultyTimetable(int facultyId) async {
    try {
      final headers = await _authHeaders(json: false);
      final response = await http.get(
        Uri.parse("$baseUrl/timetables?faculty_id=$facultyId"),
        headers: headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) return list;
      }

      // Fallback: Fetch timetables for all subjects assigned to this faculty
      final subjects = await getFacultySubjects(facultyId);
      if (subjects.isNotEmpty) {
        final List<dynamic> subjectTimetables = [];
        for (var sub in subjects) {
          final sId = sub['id'];
          final subRes = await http.get(
            Uri.parse("$baseUrl/timetables?subject_id=$sId"),
            headers: headers,
          ).timeout(defaultTimeout);
          if (subRes.statusCode == 200) {
            final tList = jsonDecode(subRes.body) as List<dynamic>;
            subjectTimetables.addAll(tList);
          }
        }
        if (subjectTimetables.isNotEmpty) return subjectTimetables;
      }

      // Fallback: Fetch all timetables
      final resAll = await http.get(
        Uri.parse("$baseUrl/timetables"),
        headers: headers,
      ).timeout(defaultTimeout);
      if (resAll.statusCode == 200) {
        return jsonDecode(resAll.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // ---------- Faculty Profile ----------
  static Future<Map<String, dynamic>> updateFacultyProfile(
    int id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http.put(
        Uri.parse("$baseUrl/faculty/$id"),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(defaultTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("user", jsonEncode(data['faculty']));
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": data['message'] ?? "Update failed", "errors": data['errors']};
      }
    } catch (e) {
      return {"success": false, "message": "Connection error or timeout"};
    }
  }

  // ---------- Faculty Photo ----------
  static Future<Map<String, dynamic>> uploadFacultyPhoto(
    int id,
    File imageFile,
  ) async {
    try {
      final uri = Uri.parse("$baseUrl/faculty/$id/photo");
      final request = http.MultipartRequest("POST", uri);
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = "Bearer $token";
      request.files.add(await http.MultipartFile.fromPath("photo", imageFile.path));

      final streamedResponse = await request.send().timeout(defaultTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("user", jsonEncode(data['faculty']));
        return {"success": true, "photo_url": data['photo_url']};
      } else {
        return {"success": false, "message": data['message'] ?? "Upload failed"};
      }
    } catch (e) {
      return {"success": false, "message": "Upload timed out or server unavailable"};
    }
  }

  // ---------- Student Photo ----------
  static Future<Map<String, dynamic>> uploadStudentPhoto(
    int id,
    File imageFile,
  ) async {
    try {
      final uri = Uri.parse("$baseUrl/profile-photo");
      final request = http.MultipartRequest("POST", uri);
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = "Bearer $token";
      request.fields['type'] = 'student';
      request.fields['id'] = id.toString();
      request.files.add(await http.MultipartFile.fromPath("photo", imageFile.path));

      final streamedResponse = await request.send().timeout(defaultTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final url = data['url'] ?? data['photo_url'];
        final prefs = await SharedPreferences.getInstance();
        final rawUser = prefs.getString("user");
        if (rawUser != null) {
          final uMap = jsonDecode(rawUser) as Map<String, dynamic>;
          uMap['profile_photo_url'] = url;
          await prefs.setString("user", jsonEncode(uMap));
        }
        return {"success": true, "photo_url": url};
      } else {
        return {"success": false, "message": data['message'] ?? "Upload failed"};
      }
    } catch (e) {
      return {"success": false, "message": "Upload timed out or server unavailable"};
    }
  }

  static String fixPhotoUrl(String? url) {
    if (url == null || url.isEmpty) return "";
    return url.replaceFirst(
      RegExp(r'^https?://(localhost|127\.0\.0\.1)(:\d+)?'),
      'http://10.0.2.2:8000',
    );
  }

  // ---------- Faculty Subjects ----------
  static Future<List<dynamic>> getFacultySubjects(int facultyId) async {
    try {
      final headers = await _authHeaders(json: false);
      final response = await http.get(
        Uri.parse("$baseUrl/subjects?faculty_id=$facultyId"),
        headers: headers,
      ).timeout(defaultTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // ---------- Students ----------
  static Future<List<dynamic>> getStudents(int deptId, String year) async {
    try {
      final headers = await _authHeaders(json: false);
      final response = await http.get(
        Uri.parse("$baseUrl/students?dept_id=$deptId&year=$year"),
        headers: headers,
      ).timeout(defaultTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // ---------- Attendance ----------
  static Future<Map<String, dynamic>> submitAttendance({
    required int subjectId,
    required String classDate,
    required int periodNo,
    required int markedBy,
    required List<Map<String, dynamic>> records,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/attendance"),
        headers: headers,
        body: jsonEncode({
          "subject_id": subjectId,
          "class_date": classDate,
          "period_no": periodNo,
          "marked_by": markedBy,
          "records": records,
        }),
      ).timeout(defaultTimeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {"success": true, "message": data["message"]};
      }
      return {
        "success": false,
        "message": data["errors"] != null
            ? data["errors"].values.first[0]
            : (data["message"] ?? "Failed to save attendance")
      };
    } catch (e) {
      return {"success": false, "message": "Connection timeout or server error"};
    }
  }

  // ---------- CT Marks ----------
  static Future<Map<String, dynamic>> submitCtMarks({
    required int subjectId,
    required int ctNumber,
    required double maxMarks,
    required String academicYear,
    required int uploadedBy,
    required List<Map<String, dynamic>> records,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/ct-marks"),
        headers: headers,
        body: jsonEncode({
          "subject_id": subjectId,
          "ct_number": ctNumber,
          "max_marks": maxMarks,
          "academic_year": academicYear,
          "uploaded_by": uploadedBy,
          "records": records,
        }),
      ).timeout(defaultTimeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {"success": true, "message": data["message"]};
      }
      return {
        "success": false,
        "message": data["errors"] != null
            ? data["errors"].values.first[0]
            : (data["message"] ?? "Failed to save marks")
      };
    } catch (e) {
      return {"success": false, "message": "Connection timeout or server error"};
    }
  }

  static Future<List<dynamic>> getCtMarks({int? subjectId, int? ctNumber}) async {
    try {
      final params = <String, String>{};
      if (subjectId != null) params['subject_id'] = subjectId.toString();
      if (ctNumber != null) params['ct_number'] = ctNumber.toString();
      final uri = Uri.parse("$baseUrl/ct-marks").replace(queryParameters: params);
      final headers = await _authHeaders(json: false);
      final response = await http.get(uri, headers: headers).timeout(defaultTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> finalizeAttendance({
    required int subjectId,
    required String classDate,
    required int periodNo,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/attendance/finalize"),
        headers: headers,
        body: jsonEncode({
          "subject_id": subjectId,
          "class_date": classDate,
          "period_no": periodNo,
        }),
      ).timeout(defaultTimeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {"success": true, "message": data["message"]};
      }
      return {"success": false, "message": data["message"] ?? "Failed to finalize"};
    } catch (e) {
      return {"success": false, "message": "Connection error or timeout"};
    }
  }

  // ---------- Generic GET with auth ----------
  static Future<List<dynamic>> getRaw(String url) async {
    try {
      final headers = await _authHeaders(json: false);
      final response = await http.get(Uri.parse(url), headers: headers).timeout(defaultTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // ---------- Departments ----------
  static Future<List<dynamic>> getDepartments() async {
    try {
      final headers = await _authHeaders(json: false);
      final response = await http.get(
        Uri.parse("$baseUrl/departments"),
        headers: headers,
      ).timeout(defaultTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // ---------- Student Profile ----------
  static Future<Map<String, dynamic>> updateStudentProfile(
    int id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http.put(
        Uri.parse("$baseUrl/students/$id"),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(defaultTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        final updatedUser = data['student'] ?? data;
        await prefs.setString("user", jsonEncode(updatedUser));
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": data['message'] ?? "Update failed"};
      }
    } catch (e) {
      return {"success": false, "message": "Connection error or timeout"};
    }
  }

  static Future<Map<String, dynamic>> changeStudentPassword(
    int id,
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http.put(
        Uri.parse("$baseUrl/students/$id"),
        headers: headers,
        body: jsonEncode({"password": newPassword}),
      ).timeout(defaultTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "message": "Password updated successfully."};
      } else {
        return {"success": false, "message": data['message'] ?? "Password update failed"};
      }
    } catch (e) {
      return {"success": false, "message": "Connection error or timeout"};
    }
  }

  // ---------- Notices ----------
  static Future<List<dynamic>> getStudentNotifications() async {
    try {
      final headers = await _authHeaders(json: false);
      final response = await http.get(
        Uri.parse("$baseUrl/notices"),
        headers: headers,
      ).timeout(defaultTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // ---------- System Settings ----------
  static Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final headers = await _authHeaders(json: false);
      final response = await http.get(
        Uri.parse("$baseUrl/system-settings"),
        headers: headers,
      ).timeout(defaultTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }
}