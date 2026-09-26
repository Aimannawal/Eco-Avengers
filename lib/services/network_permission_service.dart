import 'package:shared_preferences/shared_preferences.dart';

class NetworkPermissionService {
  NetworkPermissionService._();
  static final NetworkPermissionService instance = NetworkPermissionService._();

  static const String _keyOnlinePermission = 'has_granted_online_permission';
  static const String _keyPermissionAsked = 'has_asked_online_permission';

  /// Check whether the user has granted online / wifi / mobile data permission
  Future<bool> isPermissionGranted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnlinePermission) ?? false;
  }

  /// Check whether the dialog has already been shown to the user
  Future<bool> hasAskedPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPermissionAsked) ?? false;
  }

  /// Save the user's choice
  Future<void> setPermissionGranted(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnlinePermission, granted);
    await prefs.setBool(_keyPermissionAsked, true);
  }
}
