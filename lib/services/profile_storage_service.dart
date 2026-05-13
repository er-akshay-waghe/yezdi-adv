import 'package:shared_preferences/shared_preferences.dart';

import '../models/rider_profile.dart';

class ProfileStorageService {
  static const _prefix = 'riderProfile.';

  Future<RiderProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RiderProfile.fromPrefs({
      'name': prefs.getString('${_prefix}name'),
      'email': prefs.getString('${_prefix}email'),
      'mobile': prefs.getString('${_prefix}mobile'),
      'bikeModel': prefs.getString('${_prefix}bikeModel'),
      'imagePath': prefs.getString('${_prefix}imagePath'),
    });
  }

  Future<void> save(RiderProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in profile.toPrefs().entries) {
      await prefs.setString('$_prefix${entry.key}', entry.value);
    }
  }
}
