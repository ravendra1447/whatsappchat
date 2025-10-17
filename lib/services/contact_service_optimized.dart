import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/contact.dart';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:developer';
import '../config.dart';

// --- (HELPER FUNCTIONS: measureExecutionTime, _normalizePhone) ---

/// Helper function: kisi bhi function ke execution time ko measure kare
Future<T> measureExecutionTime<T>(String label, Future<T> Function() task) async {
  final start = DateTime.now();
  log('⏳ Start: $label');
  final result = await task();
  final end = DateTime.now();
  final duration = end.difference(start).inMilliseconds;
  log('✅ Done: $label (${duration}ms)');
  return result;
}

// Helper function (outside class) to normalize phone numbers
String _normalizePhone(String phone) {
  // केवल अंक रखें
  String digitsOnly = phone.replaceAll(RegExp(r'\D'), '');

  // अगर '91' से शुरू होता है और 10 अंक से ज़्यादा है (भारतीय कोड)
  if (digitsOnly.length > 10 && digitsOnly.startsWith('91')) {
    // आख़िरी 10 अंक लें
    digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
  }

  // अगर '0' से शुरू होता है और 11 अंक का है (लीडिंग ज़ीरो हटाना)
  if (digitsOnly.length == 11 && digitsOnly.startsWith('0')) {
    digitsOnly = digitsOnly.substring(1);
  }

  // अगर अंत में 10 अंक का नंबर है तो ही return करें, अन्यथा खाली स्ट्रिंग
  return digitsOnly.length == 10 ? digitsOnly : '';
}

// ----------------------------------------------------------------------
// 1. ISOLATE ENTRY POINT FUNCTION
// ----------------------------------------------------------------------

Future<void> fetchPhoneContactsInIsolate(Map<String, dynamic> args) async {
  // ✅ ADDED: Ensure Flutter environment is initialized in the isolate
  WidgetsFlutterBinding.ensureInitialized();

  final ownerUserId = args['ownerUserId'] as int;
  final rootIsolateToken = args['rootIsolateToken'] as RootIsolateToken?;

  if (rootIsolateToken != null) {
    try {
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
      log('✅ BinaryMessenger initialized in Isolate.spawn worker.');
    } catch (e) {
      log('❌ BinaryMessenger initialization failed in Isolate.spawn worker: $e');
    }
  }

  if (!Hive.isAdapterRegistered(4)) { // ContactAdapter का typeId
    Hive.registerAdapter(ContactAdapter());
  }

  // Ensure we can access the boxes opened in the main isolate
  // Hive will handle access to the boxes that were opened in main().

  await measureExecutionTime('TOTAL Contact Sync in Isolate', () async {
    // Sync से पहले, एक बार Map को बिल्ड करें ताकि data-access methods काम करें।
    // buildContactMapAsync अब UI को नोटिफाई नहीं करेगा।
    await ContactServiceOptimized.buildContactMapAsync(incremental: false);

    await ContactServiceOptimized.syncContacts(
      ownerUserId: ownerUserId,
      minThrottleSeconds: 60 * 60 * 24, // 24 hours throttle
    );
  });
}

// ----------------------------------------------------------------------
// 2. ISOLATE HELPER FOR DEVICE CONTACT FETCH (Used by compute)
// ----------------------------------------------------------------------

Future<Map<String, Map<String, dynamic>>> _fetchDevicePhonesInIsolate(
    RootIsolateToken token) async {

  try {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    log('✅ BinaryMessenger initialized in compute worker.');
  } catch (e) {
    log('❌ BinaryMessenger initialization failed in compute: $e');
    return {};
  }

  final allDeviceContacts = await fc.FlutterContacts.getContacts(
    withProperties: true,
    withPhoto: false,
  );

  final Map<String, Map<String, dynamic>> devicePhonesData = {};

  for (var c in allDeviceContacts) {
    final contactJson = c.toJson();

    for (var p in c.phones) {
      final phone = _normalizePhone(p.number);
      if (phone.isNotEmpty) {
        if (!devicePhonesData.containsKey(phone)) {
          devicePhonesData[phone] = {
            'name': c.displayName,
            'contactJson': contactJson,
          };
        }
      }
    }
  }
  return devicePhonesData;
}


// ----------------------------------------------------------------------
// 3. ISOLATE HELPER FOR MAP CONSTRUCTION (NEW FIX)
// ----------------------------------------------------------------------

/// NEW HELPER: HIVE JSON LIST को पूरा Dart Contact Map में बदलता है।
/// यह heavy JSON -> Object conversion को Isolate में करता है।
Map<String, Contact> _buildFinalContactMapInIsolate(List<Map<String, dynamic>> contactListJson) {
  final map = <String, Contact>{};
  for (var cJson in contactListJson) {
    try {
      final contact = Contact.fromJson(cJson);
      final key = '${contact.ownerUserId}_${contact.contactPhone}';
      map[key] = contact;
    } catch (e) {
      log('Error deserializing contact JSON in isolate: $e');
    }
  }
  return map;
}

// ----------------------------------------------------------------------
// 4. MAIN SERVICE CLASS
// ----------------------------------------------------------------------

class ContactServiceOptimized {
  static ValueNotifier<int> contactChangeNotifier = ValueNotifier(0);
  static Box<Contact> get _contactBox => Hive.box<Contact>('contacts');
  static Box get _metaBox => Hive.box('meta');

  static bool _isSyncing = false;

  static const String baseUrl = Config.basePhpApiUrl;
  static const String secureEndpoint = "$baseUrl/check_number.php";

  static Map<String, Contact> _contactMap = {};

  static Map<String, Contact> get contactMapForCompute => _contactMap;

  static String _key(int ownerUserId, String contactPhone) {
    return '${ownerUserId}_$contactPhone';
  }

  static final Uint8List _keyBytes = _hexToBytes(
    'b1b2b3b4b5b6b7b8b9babbbcbdbebff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff00',
  );
  static final _algo = AesGcm.with256bits();
  static final _secretKey = SecretKey(_keyBytes);



  // --- (buildContactMapAsync FIX) ---

  static Future<void> buildContactMapAsync({required bool incremental}) async {
    // FIX: जब मैप पहले से पॉप्युलेटेड है और incremental TRUE है, तो हम सिर्फ़ exit करते हैं।
    // UI को नोटिफाई करने का काम syncContacts के अंत में होगा।
    if (incremental && _contactMap.isNotEmpty) {
      log("⏭️ Skipping full map build (Incremental mode and map is populated).");
      // ❌ Hata diya: contactChangeNotifier.value++;
      return;
    }

    await measureExecutionTime("Fetch Hive contacts & Build Map (FULL ISOLATE)", () async {
      final contactsJson = _contactBox.values.map((c) => c.toJson()).toList();
      log("📦 Total contacts (JSON) loaded: ${contactsJson.length}");

      final newMap = await measureExecutionTime("Build final contact map in Isolate (CPU)", () async {
        return await compute(_buildFinalContactMapInIsolate, contactsJson);
      });

      // 3. Result को Main Thread पर _contactMap में असाइन करें
      _contactMap = newMap;
    });

    // ❌ Hata diya: contactChangeNotifier.value++;
    log("🔔 Full map build complete (Internal Map updated, UI notification suppressed).");
  }

  // NOTE: _buildMapInIsolateJson को हटा दिया गया है, क्योंकि अब हम सीधे Contact Object Map बना रहे हैं।


  /// Device contacts fetch करता है, API से check करता है, और Hive में update करता है।
  static Future<void> syncContacts({
    int ownerUserId = 0,
    int chunkSize = 200,
    int batchSize = 7,
    bool force = false,
    // NEW: केवल तभी सिंक करें जब यह इस समय अंतराल (second) से ज़्यादा पुराना हो
    int minThrottleSeconds = 0, // Default: no throttle
  }) async {
    if (_isSyncing) {
      log('⚠️ Sync already running — skipped duplicate trigger.');
      return;
    }

    // ⚡ 1. THROTTE CHECK
    if (minThrottleSeconds > 0 && !force) {
      final lastSyncedAt = _metaBox.get('last_synced_at');
      if (lastSyncedAt is DateTime) {
        final elapsed = DateTime.now().difference(lastSyncedAt).inSeconds;
        if (elapsed < minThrottleSeconds) {
          log('⏭️ Sync throttled. Last sync was ${elapsed}s ago (Required: ${minThrottleSeconds}s).');
          // Map already exists, just notify listeners to ensure UI is up-to-date
          contactChangeNotifier.value++;
          return;
        }
      }
    }

    _isSyncing = true; // Sync शुरू करें

    try {
      await measureExecutionTime("🌐 Full contact sync (TOTAL)", () async {

        // 0. Permission Check
        if (!await fc.FlutterContacts.requestPermission()) {
          log("❌ Contact permission not granted.");
          return;
        }

        final RootIsolateToken? rootIsolateToken = RootIsolateToken.instance;

        if (rootIsolateToken == null) {
          log("❌ RootIsolateToken is null. Cannot run plugin code in isolate.");
          return;
        }

        // 1. Fetch all device contacts and normalize phones using compute (THE 13-SECOND STEP)
        final Map<String, Map<String, dynamic>> devicePhonesData = await measureExecutionTime(
            '1. Device Contacts Fetch & Normalize in Isolate (I/O)', () async {
          return await compute(_fetchDevicePhonesInIsolate, rootIsolateToken);
        });

        // 2. Fetch all Hive contacts for the current user and create a lookup map
        final hiveContacts = _contactBox.values
            .where((c) => c.ownerUserId == ownerUserId)
            .toList();

        final Map<String, Contact> hiveContactLookup = {
          for (var c in hiveContacts) c.contactPhone: c,
        };

        final Set<String> devicePhones = devicePhonesData.keys.toSet();

        // 3. Mark deleted contacts (if not in device list)
        await measureExecutionTime('3. Mark Deleted Contacts I/O Batch', () async {
          final List<Future<void>> deleteSaveFutures = [];
          for (var hc in hiveContacts) {
            if (!devicePhones.contains(hc.contactPhone) && !hc.isDeleted) {
              hc.isDeleted = true;
              deleteSaveFutures.add(hc.save());
            }
          }
          if (deleteSaveFutures.isNotEmpty) {
            await Future.wait(deleteSaveFutures);
            log('✅ ${deleteSaveFutures.length} contacts marked as deleted and saved in batch.');
          }
        });


        // 4, 5, 6. Identify changed/new contacts, prepare objects, and split into chunks
        final Map<String, dynamic> cpuProcessingResult = await measureExecutionTime(
            '4-6. Identify Changes, Prepare Objects, & Chunking (CPU)', () async {

          // 4. Identify changed contacts (new or updated name/phone)
          final Set<String> changedPhones = {};

          for(var phone in devicePhonesData.keys) {
            final contactData = devicePhonesData[phone]!;
            final existing = hiveContactLookup[phone];

            final deviceName = contactData['name'] as String;

            if (existing == null) {
              changedPhones.add(phone); // New contact
            } else if (existing.contactName != deviceName || existing.isDeleted == true) {
              changedPhones.add(phone);
            }
          }

          // If no changes and no throttle, we skip further API calls
          if (changedPhones.isEmpty) {
            // 🎯 CRITICAL: If no changes, update last_synced_at to reset throttle
            await _metaBox.put('last_synced_at', DateTime.now());
            return {'contactsToSync': <Contact>[], 'chunks': <List<String>>[], 'isNoChange': true};
          }

          // 5. Prepare unique Contact objects for syncing
          final List<Contact> contactsToSync = [];
          final Set<String> addedToSyncList = {};

          for (var phone in changedPhones) {
            if (!addedToSyncList.contains(phone)) {
              final contactData = devicePhonesData[phone]!;
              final existingContact = hiveContactLookup[phone];

              contactsToSync.add(Contact(
                contactId: existingContact?.contactId ?? 0,
                ownerUserId: ownerUserId,
                contactName: contactData['name'] as String,
                contactPhone: phone,
                updatedAt: DateTime.now(),
                lastMessageTime: existingContact?.lastMessageTime ?? DateTime(2000),
                isDeleted: false,
                isOnApp: existingContact?.isOnApp ?? false,
                appUserId: existingContact?.appUserId,
              ));
              addedToSyncList.add(phone);
            }
          }

          if (contactsToSync.isEmpty) {
            await _metaBox.put('last_synced_at', DateTime.now());
            return {'contactsToSync': <Contact>[], 'chunks': <List<String>>[], 'isNoChange': true};
          }

          // 6. Split phones into chunks (using chunkSize) for API call
          final phones = contactsToSync.map((c) => c.contactPhone).toList();
          final chunks = <List<String>>[];
          for (var i = 0; i < phones.length; i += chunkSize) {
            chunks.add(
              phones.sublist(i, (i + chunkSize > phones.length) ? phones.length : i + chunkSize),
            );
          }

          return {
            'contactsToSync': contactsToSync,
            'chunks': chunks,
            'isNoChange': false,
          };
        });

        // ----------------------------------------------------------------------
        // 7. Network & Final Data Processing
        // ----------------------------------------------------------------------

        final List<Contact> contactsToSync = cpuProcessingResult['contactsToSync'];
        final List<List<String>> chunks = cpuProcessingResult['chunks'];
        final bool isNoChange = cpuProcessingResult['isNoChange'] as bool;

        if (isNoChange) {
          log('✅ Contact sync finished: No changes.');
          return;
        }

        // 7a. Process chunks concurrently (using batchSize)
        final results = await measureExecutionTime('7a. API Network Processing (Total)', () async {
          return _processChunks(batchSize, chunks);
        });

        // 7b. Map API results back to contacts (continued - CPU)
        await measureExecutionTime('7b. Map API Results to Contact Objects (CPU)', () async {
          final Map<String, Map<String, dynamic>> phoneMap = {};
          for (var r in results) {
            final ph = _normalizePhone(r['phone_number'].toString());
            if (ph.isNotEmpty) {
              phoneMap[ph] = r;
            }
          }

          for (var c in contactsToSync) {
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
        });


        // 8. Save/Update contacts in Hive (This now also updates the in-memory map)
        await measureExecutionTime('8. Hive Save/Update I/O (and Map Update)', () async {
          await saveOrUpdateContacts(contactsToSync);
        });

        // 🎯 CRITICAL: Sync सफल होने पर लास्ट सिंक टाइम अपडेट करें
        await _metaBox.put('last_synced_at', DateTime.now());

        // 🔔 UI को नोटिफाई करें (तेज़ अपडेट के लिए)
        // यह एकमात्र आवश्यक UI अपडेट है।
        contactChangeNotifier.value++;

        log('✅ Contact sync finished successfully. Total contacts synced/updated: ${contactsToSync.length}');

      });
    } catch (e) {
      log("❌ Error during contact sync: $e");
    } finally {
      _isSyncing = false;
    }
  }

  // --- (getContacts, getContactNameByPhoneNumber, _processChunks, _checkChunkSecure, _hexToBytes remain the same) ---

  // ✅ Used by the new ContactsTab logic
  static List<Contact> getContacts({int ownerUserId = 0}) {
    // NOTE: This uses the in-memory map for fast access and sorting
    final allContacts = _contactMap.values
        .where((c) => c.ownerUserId == ownerUserId && !c.isDeleted)
        .toList();

    return allContacts
      ..sort((a, b) => a.contactName.toLowerCase().compareTo(b.contactName.toLowerCase()));
  }

  static Future<String?> getContactNameByPhoneNumber(String phoneNumber, {int ownerUserId = 0}) async {
    try {
      final normalizedNumber = _normalizePhone(phoneNumber); // Use local helper
      if (normalizedNumber.isEmpty) return null;

      final key = _key(ownerUserId, normalizedNumber);
      final contact = _contactMap[key];

      return contact?.contactName.isNotEmpty == true ? contact!.contactName : null;
    } catch (e) {
      log("❌ Error getting contact name by phone number: $e");
    }
    return null;
  }

  // FIX: अब यह फंक्शन Hive I/O के साथ-साथ इन-मेमोरी _contactMap को भी incrementally अपडेट करता है।
  static Future<void> saveOrUpdateContacts(List<Contact> contacts) async {
    final Map<String, Contact> existingLookup = {
      for (var c in _contactBox.values) _key(c.ownerUserId, c.contactPhone): c,
    };

    final contactsToSave = <Contact>[];
    final List<Future<void>> updateSaveFutures = [];

    // इन-मेमोरी मैप अपडेट के लिए कॉन्टैक्ट्स की लिस्ट
    final Map<String, Contact> updatedContacts = {};

    for (final c in contacts) {
      final key = _key(c.ownerUserId, c.contactPhone);
      final existingContact = existingLookup[key];

      if (existingContact == null) {
        contactsToSave.add(c);
        updatedContacts[key] = c; // नए कॉन्टैक्ट को मैप अपडेट लिस्ट में जोड़ें
      } else {
        existingContact.contactName = c.contactName;
        existingContact.isOnApp = c.isOnApp;
        existingContact.appUserId = c.appUserId;
        existingContact.updatedAt = DateTime.now();
        existingContact.isDeleted = c.isDeleted;
        updateSaveFutures.add(existingContact.save());
        updatedContacts[key] = existingContact; // अपडेटेड कॉन्टैक्ट को मैप अपडेट लिस्ट में जोड़ें
      }
    }

    await measureExecutionTime('8a. Hive Update Batch (I/O)', () async {
      if (updateSaveFutures.isNotEmpty) {
        await Future.wait(updateSaveFutures);
        log('✅ ${updateSaveFutures.length} existing contacts updated and saved in batch.');
      }
    });

    await measureExecutionTime('8b. Hive Add All Batch (I/O)', () async {
      if (contactsToSave.isNotEmpty) {
        await _contactBox.addAll(contactsToSave);
        log('✅ ${contactsToSave.length} new contacts added in bulk.');
      }
    });

    // 🎯 CRITICAL FIX: In-memory map को Hive I/O के ठीक बाद incrementally अपडेट करें
    _contactMap.addAll(updatedContacts);
    log('✅ _contactMap incrementally updated with ${updatedContacts.length} changes.');
  }

  // ----------------------------------------------------------------------
  // PRIVATE HELPER METHODS
  // ----------------------------------------------------------------------

  /// API calls को batchSize के आधार पर एक साथ चलाता है (Concurrency control)
  static Future<List<Map<String, dynamic>>> _processChunks(
      int batchSize, List<List<String>> chunks) async {
    try {
      final results = <Map<String, dynamic>>[];
      for (var i = 0; i < chunks.length; i += batchSize) {
        final batch = chunks.sublist(
          i,
          (i + batchSize > chunks.length) ? chunks.length : i + batchSize,
        );

        final batchIndex = (i ~/ batchSize) + 1;
        final phonesInBatch = batch.map((c) => c.length).fold(0, (a, b) => a + b);


        final futures = batch.map((chunk) => _checkChunkSecure(chunk)).toList();

        final resultsList = await measureExecutionTime(
            'API Batch $batchIndex (${batch.length} concurrent calls, Phones: $phonesInBatch)',
                () => Future.wait(futures)
        );

        for (var r in resultsList) {
          results.addAll(r);
        }
      }
      return results;
    } catch (e) {
      log("Error processing chunks: $e");
      return [];
    }
  }

  /// एक chunk (phone number list) के लिए सुरक्षित API कॉल करता है।
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
      } else {
        log("API Error Status: ${resp.statusCode}, Body: ${resp.body}");
      }
    } catch (e) {
      log("Secure chunk error: $e");
    }
    return [];
  }

  /// Hex string को Uint8List में बदलने के लिए helper function
  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
