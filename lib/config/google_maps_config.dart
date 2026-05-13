const String googleMapsApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: '',
);

bool get hasGoogleMapsApiKey => googleMapsApiKey.trim().isNotEmpty;
