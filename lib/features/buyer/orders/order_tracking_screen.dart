import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'orders_screen.dart';

class OrderTrackingScreen extends StatelessWidget {
  final BuyerOrderData order;

  final VoidCallback? onBack;

  const OrderTrackingScreen({super.key, required this.order, this.onBack});

  static const Color _maroon = Color(0xFF7A2430);
  static const Color _text = Color(0xFF2D2926);
  static const Color _muted = Color(0xFF766C65);

  static const LatLng _defaultCenter = LatLng(14.5995, 120.9842);

  List<BuyerOrderLocation> get _locations {
    return <BuyerOrderLocation>[
      if (order.orderLocation != null) order.orderLocation!,
    ];
  }

  LatLng get _center {
    final BuyerOrderLocation? location = order.orderLocation;
    return location == null
        ? _defaultCenter
        : LatLng(location.latitude, location.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F2),
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: const Text('Track Order'),
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _locations.isEmpty ? 11 : 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.likhae.app',
                ),
                if (_locations.isNotEmpty)
                  MarkerLayer(markers: _locations.map(_buildMarker).toList()),
              ],
            ),
          ),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Marker _buildMarker(BuyerOrderLocation location) {
    const Color color = _maroon;

    return Marker(
      point: LatLng(location.latitude, location.longitude),
      width: 54,
      height: 62,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          CustomPaint(
            size: const Size(10, 7),
            painter: _MarkerTipPainter(color),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final bool hasOrderLocation = order.orderLocation != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order #${order.id}',
            style: const TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasOrderLocation
                ? 'Current order location is available.'
                : 'Current order location is not available yet.',
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          if (!hasOrderLocation) ...[
            const SizedBox(height: 4),
            const Text(
              'The map will update when the order receives GPS coordinates.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [_LegendDot(color: _maroon, label: 'Order location')],
          ),
          const SizedBox(height: 10),
          const Text(
            'Map data © OpenStreetMap contributors',
            style: TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;

  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF766C65)),
        ),
      ],
    );
  }
}

class _MarkerTipPainter extends CustomPainter {
  final Color color;

  const _MarkerTipPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MarkerTipPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
