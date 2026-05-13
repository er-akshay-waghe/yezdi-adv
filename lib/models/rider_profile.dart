class RiderProfile {
  final String name;
  final String email;
  final String mobile;
  final String bikeModel;
  final String imagePath;

  const RiderProfile({
    this.name = '',
    this.email = '',
    this.mobile = '',
    this.bikeModel = 'Yezdi Adventure',
    this.imagePath = '',
  });

  static const bikeModels = [
    'Yezdi Adventure',
    'Yezdi Roadster',
    'Yezdi Scrambler',
    'Jawa 42',
    'Jawa Perak',
  ];

  RiderProfile copyWith({
    String? name,
    String? email,
    String? mobile,
    String? bikeModel,
    String? imagePath,
  }) {
    return RiderProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      bikeModel: bikeModel ?? this.bikeModel,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, String> toPrefs() => {
        'name': name,
        'email': email,
        'mobile': mobile,
        'bikeModel': bikeModel,
        'imagePath': imagePath,
      };

  factory RiderProfile.fromPrefs(Map<String, String?> values) {
    return RiderProfile(
      name: values['name'] ?? '',
      email: values['email'] ?? '',
      mobile: values['mobile'] ?? '',
      bikeModel: values['bikeModel'] ?? 'Yezdi Adventure',
      imagePath: values['imagePath'] ?? '',
    );
  }
}
