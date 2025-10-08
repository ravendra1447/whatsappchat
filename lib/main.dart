import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:whatsappchat/models/chat_model.dart';
import 'package:whatsappchat/models/contact.dart';
import 'package:whatsappchat/services/local_auth_service.dart';
import 'package:whatsappchat/services/chat_service.dart';
import 'package:whatsappchat/services/my_firebase_messaging_service.dart';
import 'package:whatsappchat/screens/chat_home.dart' hide Contact;
import 'package:whatsappchat/screens/phone_otp_login.dart';
import 'package:whatsappchat/screens/verify_mpin_page.dart';
import 'package:whatsappchat/utils/sound_utils.dart';

// ----------------- Hive Models -----------------
@HiveType(typeId: 3)
class Chat {
  @HiveField(0)
  final int chatId;
  @HiveField(1)
  final List<int> userIds;
  @HiveField(2)
  final String chatTitle;
  @HiveField(3)
  final int? contactId;

  Chat({
    required this.chatId,
    required this.userIds,
    required this.chatTitle,
    this.contactId,
  });
}

class MessageAdapter extends TypeAdapter<Message> {
  @override
  final int typeId = 0;

  @override
  Message read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Message(
      messageId: fields[0] as String,
      chatId: fields[1] as int,
      senderId: fields[2] as int,
      receiverId: fields[3] as int,
      messageContent: fields[4] as String,
      messageType: fields[5] as String,
      isRead: fields[6] as int,
      timestamp: fields[7] as DateTime,
      isDelivered: fields[8] as int,
      senderName: fields[9] as String?,
      receiverName: fields[10] as String?,
      senderPhoneNumber: fields[11] as String?,
      receiverPhoneNumber: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Message obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.messageId)
      ..writeByte(1)
      ..write(obj.chatId)
      ..writeByte(2)
      ..write(obj.senderId)
      ..writeByte(3)
      ..write(obj.receiverId)
      ..writeByte(4)
      ..write(obj.messageContent)
      ..writeByte(5)
      ..write(obj.messageType)
      ..writeByte(6)
      ..write(obj.isRead)
      ..writeByte(7)
      ..write(obj.timestamp)
      ..writeByte(8)
      ..write(obj.isDelivered)
      ..writeByte(9)
      ..write(obj.senderName)
      ..writeByte(10)
      ..write(obj.receiverName)
      ..writeByte(11)
      ..write(obj.senderPhoneNumber)
      ..writeByte(12)
      ..write(obj.receiverPhoneNumber);
  }
}

class ContactAdapter extends TypeAdapter<Contact> {
  @override
  final int typeId = 4;

  @override
  Contact read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Contact(
      contactId: fields[0] as int,
      ownerUserId: fields[1] as int,
      contactName: fields[2] as String,
      contactPhone: fields[3] as String,
      isOnApp: fields[4] as bool,
      appUserId: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Contact obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.contactId)
      ..writeByte(1)
      ..write(obj.ownerUserId)
      ..writeByte(2)
      ..write(obj.contactName)
      ..writeByte(3)
      ..write(obj.contactPhone)
      ..writeByte(4)
      ..write(obj.isOnApp)
      ..writeByte(5)
      ..write(obj.appUserId);
  }
}

class ChatAdapter extends TypeAdapter<Chat> {
  @override
  final int typeId = 3;

  @override
  Chat read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Chat(
      chatId: fields[0] as int,
      userIds: (fields[1] as List).cast<int>(),
      chatTitle: fields[2] as String,
      contactId: fields[3] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Chat obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.chatId)
      ..writeByte(1)
      ..write(obj.userIds)
      ..writeByte(2)
      ..write(obj.chatTitle)
      ..writeByte(3)
      ..write(obj.contactId);
  }
}

// ----------------- Global NavigatorKey -----------------
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ----------------- Local Notifications -----------------
final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
fln.FlutterLocalNotificationsPlugin();

// ✅ Notification Channel Setup
const String channelId = 'chat_channel';
const String channelName = 'Chat Notifications';

// ----------------- FCM Background Handler -----------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 🛑 अब public method को call करें
  await MyFirebaseMessagingService.handleBackgroundMessage(message);
}

// ----------------- MAIN -----------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase Init
  await Firebase.initializeApp();

  // Hive Init
  await Hive.initFlutter();
  Hive.registerAdapter(MessageAdapter());
  Hive.registerAdapter(ContactAdapter());
  Hive.registerAdapter(ChatAdapter());
  await Hive.openBox<Message>('messages');
  await Hive.openBox<Chat>('chatList');
  await Hive.openBox<Contact>('contacts');
  await Hive.openBox('meta');
  await Hive.openBox('authBox');

  // FCM Background Handler Registration
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local Notifications Init
  const fln.AndroidInitializationSettings initializationSettingsAndroid =
  fln.AndroidInitializationSettings('@mipmap/ic_launcher');

  const fln.DarwinInitializationSettings initializationSettingsIOS =
  fln.DarwinInitializationSettings();

  const fln.InitializationSettings initializationSettings =
  fln.InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Notification Channel Create
  final fln.AndroidFlutterLocalNotificationsPlugin? androidPlugin =
  flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
      fln.AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(
      const fln.AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Chat app notifications',
        importance: fln.Importance.max,
        playSound: true,
        sound: fln.RawResourceAndroidNotificationSound('default'),
        showBadge: true,
      ),
    );
  }

  // Other Services Init
  await ChatService.init();
  await SoundUtils.init();
  ChatService.ensureConnected();

  // FCM Service Init
  //await MyFirebaseMessagingService.initialize();

  runApp(const MyApp());
}

// ----------------- App UI -----------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Chatting App',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        primaryColor: const Color(0xFF075E54),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF075E54),
          primary: const Color(0xFF075E54),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF075E54),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        primaryColor: const Color(0xFF075E54),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF075E54),
          primary: const Color(0xFF075E54),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF075E54),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: const SplashGate(),
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _decideRoute();
  }

  Future<void> _decideRoute() async {
    await Future.delayed(const Duration(seconds: 2));

    final hasUser = LocalAuthService.isLoggedIn();
    final userId = LocalAuthService.getUserId();

    if (!mounted) return;

    if (!hasUser) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PhoneLoginPage()),
      );
    } else {
      final hasMpin = LocalAuthService.hasMpin();
      if (hasMpin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VerifyMpinPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ChatHomePage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF075E54),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            const Text(
              'Chatting App',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 20,
              height: 20,
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}