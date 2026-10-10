import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> isOnline() async {
  final results = await Connectivity().checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
}