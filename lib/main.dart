import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/slot_repository.dart';
import 'app.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/auth_provider.dart';
import 'firebase_options.dart';
import 'data/repositories/group_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>(create: (_) => AuthRepository()),
        ChangeNotifierProvider<AuthProvider>(
          create: (c) => AuthProvider(c.read<AuthRepository>()),
        ),
        Provider<GroupRepository>(create: (_) => GroupRepository()),
        Provider<SlotRepository>(create: (_) => SlotRepository()),
      ],
      child: const ThesisTrackApp(),
    ),
  );
}