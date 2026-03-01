import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fimech/screens/user/cars.dart';
import 'package:fimech/screens/user/talleresScreen.dart';
import 'package:fimech/services/car_service.dart';
import 'package:fimech/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fimech/screens/user/profile2.dart';
import 'package:fimech/screens/user/schedule.dart';
import 'package:fimech/screens/user/tracking.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  // Firestore real-time listeners
  StreamSubscription<QuerySnapshot>? _citasSubscription;
  StreamSubscription<QuerySnapshot>? _carsSubscription;

  // Track last known states to detect changes
  final Map<String, String> _knownStatus2 = {};
  final Map<String, int> _knownDateMs = {}; // date as milliseconds for easy comparison
  final Map<String, bool> _knownInService = {};

  @override
  void initState() {
    super.initState();
    _startListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStartupDialogs());
  }

  @override
  void dispose() {
    _citasSubscription?.cancel();
    _carsSubscription?.cancel();
    super.dispose();
  }

  void _startListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userId = user.uid;

    // Listen to the user's appointments for status2 and date changes.
    _citasSubscription = FirebaseFirestore.instance
        .collection('citas')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>;
        final id = change.doc.id;

        if (change.type == DocumentChangeType.added) {
          // Populate baseline – no notification on initial load.
          _knownStatus2[id] = (data['status2'] as String?) ?? '';
          _knownDateMs[id] = _timestampMs(data['date']);
        } else if (change.type == DocumentChangeType.modified) {
          final newStatus2 = (data['status2'] as String?) ?? '';
          final newDateMs = _timestampMs(data['date']);
          final auto = (data['automovil'] as String?) ?? 'tu vehículo';

          if (newStatus2 != (_knownStatus2[id] ?? '') && newStatus2.isNotEmpty) {
            _knownStatus2[id] = newStatus2;
            _notifyStatusChange(auto, newStatus2);
          }

          if (newDateMs != 0 && newDateMs != (_knownDateMs[id] ?? 0)) {
            _knownDateMs[id] = newDateMs;
            final formatted = DateFormat('dd/MM/yyyy HH:mm')
                .format(DateTime.fromMillisecondsSinceEpoch(newDateMs));
            NotificationService.showNow(
              'Cita reprogramada – $auto',
              'Tu cita fue reprogramada al $formatted.',
            );
          }
        }
      }
    });

    // Listen to the user's cars for inService changes.
    _carsSubscription = FirebaseFirestore.instance
        .collection('cars')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>;
        final id = change.doc.id;

        if (change.type == DocumentChangeType.added) {
          _knownInService[id] = (data['inService'] as bool?) ?? false;
        } else if (change.type == DocumentChangeType.modified) {
          final newInService = (data['inService'] as bool?) ?? false;
          final oldInService = _knownInService[id] ?? false;

          if (newInService != oldInService) {
            _knownInService[id] = newInService;
            final brand = (data['brand'] as String?) ?? '';
            final model = (data['model'] as String?) ?? 'vehículo';
            final carName = brand.isNotEmpty ? '$brand $model' : model;

            if (newInService) {
              NotificationService.showNow(
                'Vehículo en servicio',
                '$carName ha ingresado al taller.',
              );
            } else {
              NotificationService.showNow(
                'Vehículo listo',
                '$carName ha salido del taller. El servicio fue completado.',
              );
            }
          }
        }
      }
    });
  }

  Future<void> _checkStartupDialogs() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || !mounted) return;

    final carService = CarService();

    // Show any unread in-app alerts first.
    final alerts = await carService.getUnreadAlerts(userId);
    for (final alert in alerts) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _UserAlertDialog(alert: alert, carService: carService),
      );
    }

    // Then handle pending car transfers addressed to this user.
    final transfers = await carService.getPendingTransfersForUser(userId);
    for (final transfer in transfers) {
      if (!mounted) return;
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _TransferConfirmationDialog(
          transfer: transfer,
          carService: carService,
        ),
      );
    }
  }

  void _notifyStatusChange(String auto, String status2) {
    final messages = {
      'Aceptado': 'Tu cita fue aceptada por el taller.',
      'Diagnostico': 'Tu vehículo está siendo diagnosticado.',
      'Reparacion': 'Tu vehículo está en proceso de reparación.',
      'Completado': 'El servicio de tu vehículo ha sido completado.',
      'Cancelado': 'Tu cita ha sido cancelada.',
      'Pendiente': 'Tu cita ha vuelto a estado Pendiente.',
    };
    final body = messages[status2] ?? 'El estado de tu cita cambió a: $status2';
    NotificationService.showNow('Actualización de cita – $auto', body);
  }

  int _timestampMs(dynamic field) {
    if (field is Timestamp) return field.toDate().millisecondsSinceEpoch;
    if (field is DateTime) return field.millisecondsSinceEpoch;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      SchedulePage(),
      TrackingPage(),
      TalleresScreen(),
      const CarsPage(),
      ProfilePage2()
    ];

    Color selectedColor = Colors.green[300]!;
    Color unselectedColor = Colors.grey[600]!;

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (value) {
          setState(() {
            selectedIndex = value;
          });
        },
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        selectedItemColor: selectedColor,
        unselectedItemColor: unselectedColor,
        backgroundColor: const Color(0xF2FFF3FF),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Citas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.content_paste_search),
            label: 'Seguimiento',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Talleres',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Autos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// ─── Transfer Confirmation Dialog ────────────────────────────────────────────

class _TransferConfirmationDialog extends StatefulWidget {
  final Map<String, dynamic> transfer;
  final CarService carService;

  const _TransferConfirmationDialog({
    required this.transfer,
    required this.carService,
  });

  @override
  State<_TransferConfirmationDialog> createState() =>
      _TransferConfirmationDialogState();
}

class _TransferConfirmationDialogState
    extends State<_TransferConfirmationDialog> {
  int _countdown = 10;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('client')
          .doc(currentUser.uid)
          .get();
      final toUserName =
          (userDoc.data()?['name'] as String?)?.trim() ?? 'Usuario';

      await widget.carService.confirmTransfer(
        widget.transfer['id'] as String,
        widget.transfer['carId'] as String,
        currentUser.uid,
        toUserName,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('client')
          .doc(currentUser.uid)
          .get();
      final toUserName =
          (userDoc.data()?['name'] as String?)?.trim() ?? 'Usuario';

      await widget.carService.cancelTransfer(
        widget.transfer['id'] as String,
        widget.transfer['fromUserId'] as String,
        widget.transfer['carBrand'] as String? ?? '',
        widget.transfer['carModel'] as String? ?? '',
        toUserName,
      );
      if (mounted) Navigator.of(context).pop(false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final carBrand = widget.transfer['carBrand'] as String? ?? '';
    final carModel = widget.transfer['carModel'] as String? ?? '';
    final carPlates = widget.transfer['carPlates'] as String? ?? '';
    final fromUserName = widget.transfer['fromUserName'] as String? ?? '';
    final canAct = _countdown == 0 && !_isLoading;

    return AlertDialog(
      backgroundColor: const Color(0xF3FFF8F2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(Icons.swap_horiz, color: Colors.green[400]),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Transferencia recibida',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Car info chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.directions_car,
                      color: Colors.green[400], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$carBrand $carModel',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          carPlates,
                          style: TextStyle(
                              fontSize: 12, color: Colors.green[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                children: [
                  const TextSpan(text: 'El usuario '),
                  TextSpan(
                    text: fromUserName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text:
                        ' desea transferirte este vehículo.\n\nSi aceptas, el vehículo y sus citas quedarán vinculados a tu cuenta. Si rechazas, permanecerán con el dueño actual.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_countdown > 0)
              Center(
                child: Column(
                  children: [
                    Text(
                      '$_countdown',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[400],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Lee el mensaje antes de responder',
                      style:
                          TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: CircularProgressIndicator(color: Colors.green),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: canAct ? _cancel : null,
          style: TextButton.styleFrom(foregroundColor: Colors.red[400]),
          child: const Text('Rechazar'),
        ),
        ElevatedButton(
          onPressed: canAct ? _confirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[300],
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

// ─── User Alert Dialog ────────────────────────────────────────────────────────

class _UserAlertDialog extends StatelessWidget {
  final Map<String, dynamic> alert;
  final CarService carService;

  const _UserAlertDialog({required this.alert, required this.carService});

  @override
  Widget build(BuildContext context) {
    final title = alert['title'] as String? ?? 'Notificación';
    final message = alert['message'] as String? ?? '';
    final alertId = alert['id'] as String;

    return AlertDialog(
      backgroundColor: const Color(0xF3FFF8F2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(Icons.notifications_outlined, color: Colors.orange[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: Text(message, style: const TextStyle(fontSize: 14)),
      actions: [
        ElevatedButton(
          onPressed: () async {
            await carService.markAlertRead(alertId);
            if (context.mounted) Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[300],
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}
