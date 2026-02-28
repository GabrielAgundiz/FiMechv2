import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fimech/screens/user/cars.dart';
import 'package:fimech/screens/user/talleresScreen.dart';
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
