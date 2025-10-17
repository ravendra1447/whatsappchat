// lib/services/contact_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../models/contact.dart';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import '../config.dart'; // ✅ Config import किया

Future<void> fetchPhoneContactsInIsolate(Map<String, dynamic> args) async {
  final ownerUserId = args['ownerUserId'] as int;
  final rootIsolateToken = args['rootIsolateToken'] as RootIsolateToken?;
  if (rootIsolateToken != null) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
  }
  await ContactService.fetchPhoneContacts(ownerUserId: ownerUserId);
}


class ContactService { // Class name unchanged
  static ValueNotifier<int> contactChangeNotifier = ValueNotifier(0);
  static Box<Contact> get _contactBox => Hive.box<Contact>('contacts');
  static Box get _metaBox => Hive.box('meta');

  // ✅ FIX 2: Saved Config से baseUrl का उपयोग
  static const String baseUrl = Config.basePhpApiUrl;
  static const String secureEndpoint = "$baseUrl/check_number.php";

  // ✅ New: Contact map for faster lookups (ChatsTab के लिए)
  static Map<String, Contact> _contactMap = {};

  // Getter for compute function (अगर ChatsTab इस नाम का उपयोग करता है)
  static Map<String, Contact> get contactMapForCompute => _contactMap;

  static final Uint8List _keyBytes = _hexToBytes(
    'b1b2b3b4b5b6b7b8b9babbbcbdbebff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff00',
  );

  static final _algo = AesGcm.with256bits();
  static final _secretKey = SecretKey(_keyBytes);

  // ✅ New method to build the internal map (ChatsTab के लिए)
  static void buildContactMap() {
    _contactMap.clear();
    for (var c in _contactBox.values) {
      _contactMap[c.contactPhone] = c;
    }
  }

  static Future<void> fetchPhoneContacts({
    int ownerUserId = 0,
    int chunkSize = 200,
    int batchSize = 7,
    bool force = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (!await fc.FlutterContacts.requestPermission()) {
        print("❌ Contact permission not granted.");
        return;
      }

      final DateTime? lastSyncedAt = force ? null : _metaBox.get('last_synced_at');
      final deviceContacts = await fc.FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      final Map<String, fc.Contact> devicePhones = {};
      for (var c in deviceContacts) {
        for (var p in c.phones) {
          final phone = normalizePhone(p.number);
          if (phone.isNotEmpty) {
            devicePhones[phone] = c;
          }
        }
      }
      final hiveContacts = _contactBox.values
          .where((c) => c.ownerUserId == ownerUserId)
          .toList();

      // ✅ FIX 3: Permanent deletion के बजाय isDeleted flag का उपयोग
      for (var hc in hiveContacts) {
        if (!devicePhones.containsKey(hc.contactPhone) && !hc.isDeleted) {
          hc.isDeleted = true;
          await hc.save();
        }
      }
      final changedFcContacts = deviceContacts.where((c) {
        if (lastSyncedAt == null) return true;
        final phoneNumbers = c.phones
            .map((p) => normalizePhone(p.number))
            .where((p) => p.isNotEmpty)
            .toList();

        for (var phone in phoneNumbers) {
          final existing = hiveContacts.firstWhere(
                (x) => x.contactPhone == phone,
            orElse: () => Contact(
              contactId: 0,
              ownerUserId: 0,
              contactName: "",
              contactPhone: "",
              lastMessageTime: DateTime(2000), // ✅ FIX 1: Required field
              isDeleted: false,                // ✅ Required field
            ),
          );
          if (existing.contactId == 0 ||
              existing.contactName != c.displayName ||
              (existing.updatedAt != null &&
                  existing.updatedAt!.isBefore(lastSyncedAt))) {
            return true;
          }
        }
        return false;
      }).toList();

      if (changedFcContacts.isEmpty) {

        stopwatch.stop();
        print('✅ Contact sync finished: No changes. Time taken: ${stopwatch.elapsedMilliseconds}ms');
        return;
      }
      await _metaBox.put('last_synced_at', DateTime.now());
      final List<Contact> contactsToSync = [];
      final Set<String> syncedPhones = {};
      for (var c in changedFcContacts) {
        for (var p in c.phones) {
          final phone = normalizePhone(p.number);
          if (phone.isNotEmpty && !syncedPhones.contains(phone)) {
            contactsToSync.add(Contact(
              contactId: 0,
              ownerUserId: ownerUserId,
              contactName: c.displayName,
              contactPhone: phone,
              updatedAt: DateTime.now(),
              lastMessageTime: DateTime(2000), // ✅ Required field
              isDeleted: false,                // ✅ Required field
            ));
            syncedPhones.add(phone);
          }
        }
      }
      if (contactsToSync.isEmpty) {
        stopwatch.stop();
        print('✅ Contact sync finished: No contacts to sync. Time taken: ${stopwatch.elapsedMilliseconds}ms');
        return;
      }
      final phones = contactsToSync.map((c) => c.contactPhone).toList();
      final chunks = <List<String>>[];
      for (var i = 0; i < phones.length; i += chunkSize) {
        chunks.add(
          phones.sublist(i, (i + chunkSize > phones.length) ? phones.length : i + chunkSize),
        );
      }
      final results = await _processChunks(batchSize, chunks);
      final Map<String, Map<String, dynamic>> phoneMap = {};
      for (var r in results) {
        final ph = normalizePhone(r['phone_number'].toString());
        phoneMap[ph] = r;
      }
      for (var c in contactsToSync) {
        final info = phoneMap[c.contactPhone];
        if (info != null && info['invite'] == false) {
          c.isOnApp = true;
          c.appUserId =
          info['user_id'] != null ? int.tryParse(info['user_id'].toString()) : null;
        } else {
          c.isOnApp = false;
          c.appUserId = null;
        }
      }
      await saveOrUpdateContacts(contactsToSync);

      stopwatch.stop();
      print('✅ Contact sync finished successfully. Total contacts synced: ${contactsToSync.length}. Time taken: ${stopwatch.elapsedMilliseconds}ms');

    } catch (e) {
      stopwatch.stop();
      print("❌ Error during contact sync: $e. Time elapsed before error: ${stopwatch.elapsedMilliseconds}ms");
    }
  }

  static Future<List<Map<String, dynamic>>> _processChunks(
      int batchSize, List<List<String>> chunks) async {
    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < chunks.length; i += batchSize) {
      final batch = chunks.sublist(
        i,
        (i + batchSize > chunks.length) ? chunks.length : i + batchSize,
      );
      final futures = batch.map((chunk) => _checkChunkSecure(chunk)).toList();
      final resultsList = await Future.wait(futures);
      for (var r in resultsList) {
        results.addAll(r);
      }
    }
    return results;
  }

  static Future<List<Map<String, dynamic>>> _checkChunkSecure(
      List<String> phones) async {
    try {
      final inner = jsonEncode({"phone_numbers": phones});
      final gz = gzip.encode(utf8.encode(inner));
      final nonce = _algo.newNonce();
      final secretBox = await _algo.encrypt(
        gz,
        secretKey: _secretKey,
        nonce: nonce,
      );
      final envelope = jsonEncode({
        "nonce": base64Encode(nonce),
        "ciphertext": base64Encode(secretBox.cipherText),
        "tag": base64Encode(secretBox.mac.bytes),
      });
      final resp = await http.post(
        Uri.parse(secureEndpoint),
        headers: {HttpHeaders.contentTypeHeader: "application/json"},
        body: envelope,
      );
      if (resp.statusCode == 200) {
        final obj = jsonDecode(resp.body);
        final n = base64Decode(obj['nonce']);
        final c = base64Decode(obj['ciphertext']);
        final t = base64Decode(obj['tag']);
        final sb = SecretBox(c, nonce: n, mac: Mac(t));
        final clear = await _algo.decrypt(sb, secretKey: _secretKey);
        final unzipped = gzip.decode(clear);
        final decoded = jsonDecode(utf8.decode(unzipped));
        return List<Map<String, dynamic>>.from(decoded['results'] ?? []);
      }
    } catch (e) {
      print("Secure chunk error: $e");
    }
    return [];
  }

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

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  static List<Contact> getLocalContacts({int ownerUserId = 0}) {
    final uniqueContacts = _contactBox.values
        .where((c) => c.ownerUserId == ownerUserId && !c.isDeleted) // ✅ isDeleted check जोड़ा गया
        .toList();

    // Map for deduplication is not needed if only one phone number per contact is stored,
    // but keeping it as per your original logic.
    final Map<String, Contact> uniqueMap = {};
    for (var c in uniqueContacts) {
      uniqueMap[c.contactPhone] = c;
    }

    final List<Contact> deduped = uniqueMap.values.toList();

    return deduped
      ..sort((a, b) => a.contactName.compareTo(b.contactName));
  }

  static Future<Contact?> getContactByAppUserId(int appUserId) async {
    final box = Hive.box<Contact>('contacts');
    final contact = box.values.firstWhere(
          (c) => c.appUserId == appUserId && !c.isDeleted, // isDeleted check
      orElse: () => Contact(
        contactId: 0,
        ownerUserId: 0,
        contactName: "",
        contactPhone: "",
        lastMessageTime: DateTime(2000), // ✅ Required field
        isDeleted: false,                // ✅ Required field
      ),
    );
    return contact.contactId == 0 ? null : contact;
  }

  static Future<String?> getContactNameByPhoneNumber(String phoneNumber) async {
    try {
      final normalizedNumber = normalizePhone(phoneNumber);
      if (normalizedNumber.isEmpty) return null;

      final contact = _contactBox.values.firstWhere(
            (c) => c.contactPhone == normalizedNumber && !c.isDeleted, // isDeleted check
        orElse: () => Contact(
          contactId: 0,
          ownerUserId: 0,
          contactName: "",
          contactPhone: "",
          lastMessageTime: DateTime(2000), // ✅ Required field
          isDeleted: false,                // ✅ Required field
        ),
      );

      return contact.contactName.isNotEmpty ? contact.contactName : null;
    } catch (e) {
      print("❌ Error getting contact name by phone number: $e");
    }
    return null;
  }

  static Future<void> saveOrUpdateContacts(List<Contact> contacts) async {
    // saveOrUpdateContacts में buildContactMap() कॉल नहीं है, इसलिए इसे जोड़ें
    // ताकि ChatsTab द्वारा उपयोग किया जाने वाला map अपडेट हो जाए।

    final contactsToSave = <Contact>[];
    for (final c in contacts) {
      final existingContact = _contactBox.values.firstWhere(
            (contactInHive) =>
        contactInHive.contactPhone == c.contactPhone &&
            contactInHive.ownerUserId == c.ownerUserId,
        orElse: () => Contact(
          contactId: 0,
          ownerUserId: c.ownerUserId,
          contactName: "",
          contactPhone: "",
          lastMessageTime: DateTime(2000), // ✅ Required field
          isDeleted: false,                // ✅ Required field
        ),
      );
      if (existingContact.contactId == 0) {
        contactsToSave.add(c);
      } else {
        existingContact.contactName = c.contactName;
        existingContact.isOnApp = c.isOnApp;
        existingContact.appUserId = c.appUserId;
        existingContact.updatedAt = DateTime.now();
        await existingContact.save();
      }
    }
    if (contactsToSave.isNotEmpty) {
      await _contactBox.addAll(contactsToSave);
    }
    // ✅ buildContactMap कॉल जोड़ा गया
    buildContactMap();
    contactChangeNotifier.value++;
  }

  static Future<void> clearLocalContacts({int ownerUserId = 0}) async {
    final toDelete =
    _contactBox.values.where((c) => c.ownerUserId == ownerUserId).toList();
    for (var c in toDelete) await c.delete();
    // ✅ buildContactMap कॉल जोड़ा गया
    buildContactMap();
    contactChangeNotifier.value++;
  }
}