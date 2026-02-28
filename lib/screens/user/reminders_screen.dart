import 'package:fimech/model/car.dart';
import 'package:fimech/screens/user/citeform.dart';
import 'package:fimech/services/car_service.dart';
import 'package:fimech/services/reminder_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late final Future<List<Car>> _carsFuture;
  String? isExpandedCarId;
  final Map<String, GlobalKey> _tileKeys = {};

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _carsFuture = CarService().getUserCars(userId);
  }

  void _onCarTap(String carId) {
    final isOpening = isExpandedCarId != carId;
    setState(() {
      isExpandedCarId = isOpening ? carId : null;
    });
    if (isOpening) {
      // Layout is immediately stable (no AnimatedSize), so one post-frame
      // callback is enough to get a reliable scroll target.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _tileKeys[carId]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.0,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xF3FFF8F2),
        title: const Text(
          'Recordatorios',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Mis vehículos',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Selecciona un vehículo para ver sus recordatorios de servicio.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: FutureBuilder<List<Car>>(
              future: _carsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.green));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar los vehículos.'));
                }
                final cars = snapshot.data ?? [];
                if (cars.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_car_outlined, size: 64, color: Colors.black26),
                          SizedBox(height: 16),
                          Text(
                            'No tienes vehículos registrados.',
                            style: TextStyle(fontSize: 16, color: Colors.black45),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Agrega uno en la sección "Autos" para ver sus recordatorios.',
                            style: TextStyle(fontSize: 13, color: Colors.black38),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cars.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final car = cars[i];
                    _tileKeys[car.id] ??= GlobalKey();
                    return _CarReminderTile(
                      key: _tileKeys[car.id],
                      car: car,
                      isExpanded: isExpandedCarId == car.id,
                      onTap: () => _onCarTap(car.id),
                    );
                  },
                );
              },
            ),
          ),

          // Agendar cita button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CiteForm(workshopData: null),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Agendar cita',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Car Reminder Tile ────────────────────────────────────────────────────────

class _CarReminderTile extends StatelessWidget {
  final Car car;
  final bool isExpanded;
  final VoidCallback onTap;

  const _CarReminderTile({
    super.key,
    required this.car,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reminders = ReminderService().fetchRemindersForCar(car);

    // Count overdue / due soon for the summary badge
    final now = DateTime.now();
    final overdueCount = reminders.where((r) => r.nextDue.isBefore(now)).length;
    final soonCount = reminders
        .where((r) =>
            !r.nextDue.isBefore(now) &&
            r.nextDue.difference(now).inDays <= 30)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // ── Car header ──────────────────────────────────────────────────
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Car icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.directions_car,
                          color: Colors.green[400], size: 24),
                    ),
                    const SizedBox(width: 12),

                    // Brand / model / year
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${car.brand} ${car.model}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${car.year} · ${car.color}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                    // Status summary badges
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Plates
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            car.plates,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[800],
                            ),
                          ),
                        ),
                        if (overdueCount > 0 || soonCount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (overdueCount > 0)
                                _MiniChip(
                                    label: '$overdueCount vencido${overdueCount > 1 ? 's' : ''}',
                                    color: Colors.red),
                              if (overdueCount > 0 && soonCount > 0)
                                const SizedBox(width: 4),
                              if (soonCount > 0)
                                _MiniChip(
                                    label: '$soonCount próximo${soonCount > 1 ? 's' : ''}',
                                    color: Colors.orange),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 8),

                    // Expand chevron
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.black45),
                    ),
                  ],
                ),
              ),
            ),

            // ── Reminders list ───────────────────────────────────────────────
            if (isExpanded)
              Column(
                children: [
                  const Divider(height: 1, color: Colors.black12),
                  ...reminders.map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: _ReminderCard(reminder: r),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Mini chip for summary badges ─────────────────────────────────────────────

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ─── Reminder Card (unchanged from original) ─────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final ReminderInfo reminder;

  const _ReminderCard({required this.reminder});

  static const Map<String, IconData> _serviceIcons = {
    'Cambio de aceite': Icons.oil_barrel,
    'Rotación de llantas': Icons.tire_repair,
    'Revisión de frenos': Icons.car_crash,
    'Cambio de batería': Icons.battery_charging_full,
    'Cambio de filtro de aire': Icons.air,
    'Afinación general': Icons.build,
    'Servicio de transmisión': Icons.settings,
    'Cambio de líquido refrigerante': Icons.water_drop,
    'Alineación y balanceo': Icons.balance,
    'Servicio de aire acondicionado': Icons.ac_unit,
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysUntilDue = reminder.nextDue.difference(now).inDays;
    final isOverdue = daysUntilDue < 0;
    final isDueSoon = !isOverdue && daysUntilDue <= 30;

    Widget statusChip;
    if (isOverdue) {
      statusChip = _buildChip('Vencido', Colors.red.shade100, Colors.red);
    } else if (isDueSoon) {
      statusChip =
          _buildChip('Próximo', Colors.orange.shade100, Colors.orange);
    } else {
      statusChip =
          _buildChip('Al día', Colors.green.shade100, Colors.green);
    }

    final fmt = DateFormat('dd/MM/yyyy');
    final lastDoneText = reminder.lastDone != null
        ? _monthsAgo(reminder.lastDone!, now)
        : 'Sin registro';

    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.green[50],
          child: Icon(
            _serviceIcons[reminder.serviceName] ?? Icons.build,
            color: Colors.green[700],
            size: 22,
          ),
        ),
        title: Text(
          reminder.serviceName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              'Último servicio: $lastDoneText',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Próximo: ${fmt.format(reminder.nextDue)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
        trailing: statusChip,
        isThreeLine: true,
      ),
    );
  }

  Widget _buildChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  String _monthsAgo(DateTime lastDone, DateTime now) {
    final months =
        (now.year - lastDone.year) * 12 + (now.month - lastDone.month);
    if (months <= 0) return 'Este mes';
    if (months == 1) return 'Hace 1 mes';
    return 'Hace $months meses';
  }
}
