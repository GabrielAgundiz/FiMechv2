import 'package:fimech/screens/user/citeform.dart';
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
  late final String _userId;
  late final Future<List<ReminderInfo>> _remindersFuture;
  late final Future<String> _carModelFuture;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = ReminderService();
    _remindersFuture = service.fetchReminders(_userId);
    _carModelFuture = service.fetchCarModel(_userId);
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
        children: [
          // Car model header
          FutureBuilder<String>(
            future: _carModelFuture,
            builder: (context, snap) {
              final model = snap.data ?? 'Tu automóvil';
              return Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_car,
                        color: Colors.green[700], size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        model,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Service list
          Expanded(
            child: FutureBuilder<List<ReminderInfo>>(
              future: _remindersFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                      child: Text('Error: ${snap.error}'));
                }
                final reminders = snap.data ?? [];
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: reminders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _ReminderCard(reminder: reminders[index]),
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
                      builder: (_) =>
                          const CiteForm(workshopData: null),
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
      statusChip = _buildChip('Próximo', Colors.orange.shade100, Colors.orange);
    } else {
      statusChip = _buildChip('Al día', Colors.green.shade100, Colors.green);
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
    final months = (now.year - lastDone.year) * 12 +
        (now.month - lastDone.month);
    if (months <= 0) return 'Este mes';
    if (months == 1) return 'Hace 1 mes';
    return 'Hace $months meses';
  }
}
