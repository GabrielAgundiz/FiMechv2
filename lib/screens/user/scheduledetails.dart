import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fimech/model/appointment.dart';
import 'package:fimech/model/car.dart';
import 'package:fimech/screens/user/widgets/sectionheading.dart';
import 'package:fimech/screens/user/widgets/whatsappbutton.dart';

class ScheduleDetailsPage extends StatefulWidget {
  final Appointment _appointment;

  const ScheduleDetailsPage(this._appointment, {super.key});

  @override
  State<ScheduleDetailsPage> createState() => _ScheduleDetailsPageState();
}

class _ScheduleDetailsPageState extends State<ScheduleDetailsPage> {
  late final Future<Car?> _carFuture;

  @override
  void initState() {
    super.initState();
    _carFuture = _loadCar();
  }

  Future<Car?> _loadCar() async {
    if (widget._appointment.carId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('cars')
          .doc(widget._appointment.carId)
          .get();
      if (doc.exists) return Car.fromJson(doc.id, doc.data()!);
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xF3FFF8F2),
        title: const Text(
          'Detalles',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar:
          WhatsappButton(widget._appointment.id, widget._appointment.auto),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading(
                  title: "Detalles de la cita",
                  showActionButton: false,
                ),
                const SizedBox(height: 20),

                // ── Vehicle card ──────────────────────────────────────────
                FutureBuilder<Car?>(
                  future: _carFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(color: Colors.green),
                        ),
                      );
                    }
                    final car = snapshot.data;
                    if (car != null) {
                      return _VehicleCard(car: car);
                    }
                    // Fallback when carId is empty or car not found
                    return _FallbackVehicleCard(name: widget._appointment.auto);
                  },
                ),

                const SizedBox(height: 20),
                const Divider(color: Colors.black12),
                const SizedBox(height: 14),

                // ── Appointment details ───────────────────────────────────
                _DetailRow(
                  label: 'Motivo',
                  value: widget._appointment.motivo,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Fecha',
                  value: DateFormat('dd/MM/yyyy').format(widget._appointment.date),
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Hora',
                  value: DateFormat.jm().format(widget._appointment.date),
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Taller Mecánico',
                  value: widget._appointment.workshopName,
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Dirección del taller',
                  value: widget._appointment.workshopAddress,
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Estado',
                  value: widget._appointment.status,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Vehicle card (full data) ─────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final Car car;

  const _VehicleCard({required this.car});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: Colors.green[400],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${car.brand} ${car.model}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        car.year,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        car.plates,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                    if (car.inService) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'En servicio',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.palette_outlined,
                    label: 'Color',
                    value: car.color,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.pin_outlined,
                    label: 'Serie',
                    value: car.serial,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fallback card when car data is unavailable ────────────────────────────────

class _FallbackVehicleCard extends StatelessWidget {
  final String name;

  const _FallbackVehicleCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.directions_car,
                color: Colors.green[400],
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared info item (icon + label + value) ───────────────────────────────────

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Label/value row for appointment fields ────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;

  const _DetailRow({
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            '$label:',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
