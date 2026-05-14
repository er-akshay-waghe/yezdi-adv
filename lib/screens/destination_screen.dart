import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../services/navigation_service.dart';
import '../utils/app_theme.dart';
import '../widgets/google_dashboard_map.dart';
import '../widgets/premium_components.dart';
import 'navigation_screen.dart';

class DestinationScreen extends StatefulWidget {
  const DestinationScreen({super.key});

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  final TextEditingController _latCtrl = TextEditingController();
  final TextEditingController _lngCtrl = TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _picked;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    context.read<NavService>().initLocation();
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavService>();
    final pos = nav.currentPosition;

    return Scaffold(
      appBar: AppBar(title: const Text('SET DESTINATION')),
      body: AdventureBackdrop(
        child: Column(
          children: [
            SizedBox(
              height: 280,
              child: pos == null
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: GoogleDashboardMap(
                            center: LatLng(pos.latitude, pos.longitude),
                            zoom: 14,
                            currentLocation:
                                LatLng(pos.latitude, pos.longitude),
                            destination: _picked,
                            onMapCreated: (controller) =>
                                _mapController = controller,
                            onTap: (latlng) {
                              setState(() {
                                _picked = latlng;
                                _latCtrl.text =
                                    latlng.latitude.toStringAsFixed(6);
                                _lngCtrl.text =
                                    latlng.longitude.toStringAsFixed(6);
                              });
                            },
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: MapZoomControls(
                            onZoomIn: () => _zoomBy(1),
                            onZoomOut: () => _zoomBy(-1),
                          ),
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: PremiumPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TAP MAP TO SELECT OR ENTER COORDINATES',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                            letterSpacing: 1,
                            fontFamily: 'monospace')),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _CoordField(
                          controller: _latCtrl,
                          label: 'LATITUDE',
                          hint: '12.971599',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CoordField(
                          controller: _lngCtrl,
                          label: 'LONGITUDE',
                          hint: '77.594566',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : GradientActionButton(
                            icon: Icons.navigation,
                            label: 'Get route and start',
                            expanded: true,
                            onPressed: _startNavigation,
                          ),
                    if (nav.error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(nav.error,
                            style: const TextStyle(
                                color: Color(0xFFFF4A4A), fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNavigation() async {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid coordinates')));
      return;
    }

    setState(() => _loading = true);
    final nav = context.read<NavService>();
    await nav.fetchRoute(LatLng(lat, lng));
    if (!mounted) return;
    setState(() => _loading = false);

    if (nav.error.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NavigationScreen()),
      );
    }
  }

  void _zoomBy(double amount) {
    _mapController?.animateCamera(CameraUpdate.zoomBy(amount));
  }
}

class _CoordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _CoordField(
      {required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                color: AppColors.muted,
                fontFamily: 'monospace')),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
              signed: true, decimal: true),
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 13, color: Color(0xFFE0DDD8)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.muted),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                const BorderSide(color: AppColors.border, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                const BorderSide(color: AppColors.border, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.amber, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
