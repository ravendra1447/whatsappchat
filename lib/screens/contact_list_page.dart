// lib/services/contact_service.dart
import 'dart:convert';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../models/contact.dart';

class ContactService {
  static Box<Contact> get _contactBox => Hive.box<Contact>('contacts');

  static const String baseUrl = "http://184.168.126.71/api";
  static const int _chunkSize = 200;
  static const int _parallel = 4;

  /// Fetch device contacts, check via batch API (chunked+parallel), update Hive
  static Future<List<Contact>> fetchPhoneContacts({int ownerUserId = 0}) async {
    // 1) permission
    if (!await fc.FlutterContacts.requestPermission()) return [];

    // 2) device contacts
    final deviceContacts = await fc.FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    // 3) normalize + dedupe (by phone)
    final Map<String, Contact> uniq = {};
    for (var c in deviceContacts) {
      for (var p in c.phones) {
        final phone = normalizePhone(p.number);
        if (phone.isEmpty) continue;
        // keep latest name seen
        uniq[phone] = Contact(
          contactId: 0,
          ownerUserId: ownerUserId,
          contactName: c.displayName,
          contactPhone: phone,
        );
      }
    }

    var allContacts = uniq.values.toList();
    if (allContacts.isEmpty) return [];

    // 4) build list of numbers
    final phoneNumbers = allContacts.map((c) => c.contactPhone).toList();

    // 5) chunking
    final chunks = <List<String>>[];
    for (var i = 0; i < phoneNumbers.length; i += _chunkSize) {
      final end = (i + _chunkSize > phoneNumbers.length) ? phoneNumbers.length : i + _chunkSize;
      chunks.add(phoneNumbers.sublist(i, end));
    }

    // 6) fire in parallel batches
    final allResults = <Map<String, dynamic>>[];
    int idx = 0;
    while (idx < chunks.length) {
      final batch = chunks.sublist(idx, (idx + _parallel > chunks.length) ? chunks.length : idx + _parallel);
      final futures = batch.map((chunk) => _checkNumbers(chunk)).toList();
      final batchRes = await Future.wait(futures);
      for (final r in batchRes) {
        allResults.addAll(r);
      }
      idx += _parallel;
    }

    // 7) build map from API
    final Map<String, Map<String, dynamic>> phoneMap = {};
    for (var r in allResults) {
      final ph = normalizePhone(r['phone_number']?.toString() ?? '');
      if (ph.isNotEmpty) phoneMap[ph] = r;
    }

    // 8) mark contacts according to API
    for (var c in allContacts) {
      final info = phoneMap[c.contactPhone];
      if (info != null && info['invite'] == false) {
        c.isOnApp = true;
        c.appUserId = info['user_id'] != null
            ? int.tryParse(info['user_id'].toString())
            : null;
      } else {
        c.isOnApp = false;
        c.appUserId = null;
      }
    }

    // 9) save/update Hive
    for (var contact in allContacts) {
      final existing = _contactBox.values.firstWhere(
            (x) => x.contactPhone == contact.contactPhone && x.ownerUserId == ownerUserId,
        orElse: () => Contact(
          contactId: 0,
          ownerUserId: ownerUserId,
          contactName: "",
          contactPhone: "",
          isOnApp: false,
        ),
      );

      if (existing.contactId == 0) {
        await _contactBox.add(contact);
      } else {
        existing.contactName = contact.contactName;
        existing.isOnApp = contact.isOnApp;
        existing.appUserId = contact.appUserId;
        await existing.save();
      }
    }

    // 10) return sorted
    allContacts.sort((a, b) => a.contactPhone.compareTo(b.contactPhone));
    return allContacts;
  }

  // ---- HTTP helper (one chunk) ----
  static Future<List<Map<String, dynamic>>> _checkNumbers(List<String> phones) async {
    try {
      final resp = await http.post(
        Uri.parse("$baseUrl/check_number.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_numbers': phones}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
        return results;
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  // ---- Helpers ----
  static String normalizePhone(String phone) {
    String digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 10 && digitsOnly.startsWith('91')) {
      digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
    }
    if (digitsOnly.length == 11 && digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.substring(1);
    }
    return digitsOnly.length == 10 ? digitsOnly : '';
  }

  static List<Contact> getLocalContacts({int ownerUserId = 0}) {
    final list = _contactBox.values.where((c) => c.ownerUserId == ownerUserId).toList();
    list.sort((a, b) => a.contactPhone.compareTo(b.contactPhone));
    return list;
  }

  static Future<void> clearLocalContacts({int ownerUserId = 0}) async {
    final toDelete = _contactBox.values.where((c) => c.ownerUserId == ownerUserId).toList();
    for (var c in toDelete) { await c.delete(); }
  }
}
