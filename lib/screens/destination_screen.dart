import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../services/navigation_service.dart';
import 'navigation_screen.dart';

class DestinationScreen extends StatefulWidget {
  const DestinationScreen({super.key});

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  final TextEditingController _latCtrl = TextEditingController();
  final TextEditingController _lngCtrl = TextEditingController();
  LatLng? _picked;
  bool _loading = false;

  static const _kAccent = Color(0xFF4A9EFF);

  @override
  void initState() {
    super.initState();
    context.read<NavService>().initLocation();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavService>();
    final pos = nav.currentPosition;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(title: const Text('SET DESTINATION')),
      body: Column(
        children: [
          // Map to pick destination
          SizedBox(
            height: 260,
            child: pos == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(pos.latitude, pos.longitude),
                      zoom: 14,
                    ),
                    onTap: (latlng) {
                      setState(() {
                        _picked = latlng;
                        _latCtrl.text = latlng.latitude.toStringAsFixed(6);
                        _lngCtrl.text = latlng.longitude.toStringAsFixed(6);
                      });
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('current'),
                        position: LatLng(pos.latitude, pos.longitude),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure),
                      ),
                      if (_picked != null)
                        Marker(
                          markerId: const MarkerId('dest'),
                          position: _picked!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed),
                        ),
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                  ),
          ),

          // Coordinate inputs
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TAP MAP TO SELECT OR ENTER COORDINATES',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF666666),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A3A6A),
                      foregroundColor: _kAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(
                          color: Color(0xFF3A6AB0), width: 0.5),
                    ),
                    onPressed: _loading ? null : _startNavigation,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('GET ROUTE & START',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                fontSize: 14)),
                  ),
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
        ],
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
    setState(() => _loading = false);

    if (nav.error.isEmpty && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NavigationScreen()),
      );
    }
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
                color: Color(0xFF666666),
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
            hintStyle: const TextStyle(color: Color(0xFF444444)),
            filled: true,
            fillColor: const Color(0xFF111115),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF2A2A30), width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF2A2A30), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4A9EFF), width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
