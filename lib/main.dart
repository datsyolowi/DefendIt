import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/title_repository.dart';
import 'app.dart';
import 'data/local/app_database.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/consultation_repository.dart';
import 'data/repositories/group_repository.dart';
import 'data/repositories/slot_repository.dart';
import 'data/sync/sync_service.dart';
import 'features/auth/auth_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // sqflite is the app's offline store, so Firestore's own cache is switched
  // off to keep the two layers clearly separate.
  FirebaseFirestore.instance.settings =
  const Settings(persistenceEnabled: false);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>(create: (_) => AuthRepository()),
        ChangeNotifierProvider<AuthProvider>(
          create: (c) => AuthProvider(c.read<AuthRepository>()),
        ),
        Provider<GroupRepository>(create: (_) => GroupRepository()),
        Provider<SlotRepository>(create: (_) => SlotRepository()),
        Provider<AppDatabase>(create: (_) => AppDatabase()),
        ChangeNotifierProvider<SyncService>(
          create: (c) => SyncService(
            c.read<AppDatabase>(),
            FirebaseFirestore.instance,
            c.read<GroupRepository>(),
          ),
        ),
        Provider<ConsultationRepository>(
          create: (c) => ConsultationRepository(
              c.read<AppDatabase>(), c.read<SyncService>()),
        ),
        Provider<TitleRepository>(create: (_) => TitleRepository()),
      ],
      child: const ThesisTrackApp(),
    ),

  );
}