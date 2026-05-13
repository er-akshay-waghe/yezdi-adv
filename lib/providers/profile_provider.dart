import 'package:flutter/foundation.dart';

import '../models/rider_profile.dart';
import '../services/profile_storage_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileStorageService _storage;

  ProfileProvider({ProfileStorageService? storage})
      : _storage = storage ?? ProfileStorageService();

  RiderProfile _profile = const RiderProfile();
  bool _isLoaded = false;

  RiderProfile get profile => _profile;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    _profile = await _storage.load();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> save(RiderProfile profile) async {
    _profile = profile;
    await _storage.save(profile);
    notifyListeners();
  }
}
