enum DashboardAlertType { call, sms, app, system }

class DashboardAlert {
  final DashboardAlertType type;
  final String title;
  final String body;
  final DateTime timestamp;

  const DashboardAlert({
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
  });
}
