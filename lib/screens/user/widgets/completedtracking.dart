import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fimech/model/appointment.dart';
import 'package:fimech/screens/user/trackdetailsComplete.dart';
import 'package:fimech/services/appointment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CompletedTracking extends StatefulWidget {
  const CompletedTracking({super.key});

  @override
  State<CompletedTracking> createState() => _CompletedTrackingState();
}

class _CompletedTrackingState extends State<CompletedTracking> {
  late String userId;
  @override
  void initState() {
    super.initState();
    getUserId();
  }

  Future<void> getUserId() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
      });
    } else {
      userId = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Appointment>>(
      future: AppointmentService().getAllAppointments(userId, "Completado"),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          List<Appointment> appointments = snapshot.data ?? [];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Servicios Completados",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 15),
                appointments.isNotEmpty
                    ? SingleChildScrollView(
                        child: Column(
                          children: appointments.map((appointment) {
                            return CardAppointment(appointment.id, appointment);
                          }).toList(),
                        ),
                      )
                    : Column(children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            height: 45,
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "Aún no tiene servicios completados",
                                  style: TextStyle(color: Colors.black54),
                                )
                              ],
                            ),
                          ),
                        ),
                      ]),
                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

class CardAppointment extends StatefulWidget {
  final String appointmentId;
  final Appointment appointment_1;
  const CardAppointment(this.appointmentId, this.appointment_1, {super.key});

  @override
  State<StatefulWidget> createState() {
    return _CardAppointmentState();
  }
}

class _CardAppointmentState extends State<CardAppointment> {
  Appointment? _appointment; //state local
  String? _workshopImageUrl;

  @override
  void initState() {
    super.initState();
    _getAppointment(widget.appointmentId);
  }

  void _getAppointment(String appointmentId) async {
    var appointment = await AppointmentService().getAppointment(appointmentId);
    setState(() {
      _appointment = appointment;
    });
    // Cargar imagen del taller asignado si existe idMecanico
    try {
      final mechId = appointment.idMecanico;
      if (mechId.isNotEmpty) {
        _loadWorkshopImage(mechId);
      }
    } catch (_) {}
  }

  Future<void> _loadWorkshopImage(String mechanicId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('admin').doc(mechanicId).get();
      if (doc.exists) {
        final data = doc.data();
        final raw = data?['workshopImageUrl'] ?? data?['image'] ?? data?['workshopImage'];
        final resolved = await _resolveImageUrl(raw);
        if (mounted) setState(() => _workshopImageUrl = resolved);
      }
    } catch (_) {
      // ignore errors
    }
  }

  Future<String?> _resolveImageUrl(dynamic raw) async {
    try {
      if (raw == null) return null;
      if (raw is String && raw.trim().isNotEmpty) {
        final s = raw.trim();
        if (s.startsWith('http')) return s;
        try {
          final url = await FirebaseStorage.instance.ref().child(s).getDownloadURL();
          return url;
        } catch (_) {
          return null;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_appointment == null) {
      return const Center(child: CircularProgressIndicator());
    } else if (_appointment!.status == "Completado") {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.directions_car, color: Colors.green[400], size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _appointment!.auto,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _appointment!.motivo,
                              style: const TextStyle(color: Colors.black54, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _workshopImageUrl != null ? NetworkImage(_workshopImageUrl!) : null,
                        child: _workshopImageUrl == null ? const Icon(Icons.store, color: Colors.black54) : null,
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Divider(thickness: 1, height: 20),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const Row(
                      children: [
                        SizedBox(
                          width: 10,
                        ),
                        Text(
                          "Completado: ",
                          style: TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('dd/MM/yyyy')
                              .format(_appointment!.dateUpdate),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                    
                  ],
                ),
                const SizedBox(
                  height: 15,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    InkWell(
                      onTap: () {
                        _openTrackingDetails(context, _appointment);
                      },
                      child: Container(
                        width: 300,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            "Ver detalles",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 15,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return const Column(
        children: [
          Text(
            "No tiene citas pendientes",
            style: TextStyle(color: Colors.black54),
          )
        ],
      );
    }
  }

  void _openTrackingDetails(BuildContext context, Appointment? appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => TrackDetailsPageComplete(appointment!)),
    );
  }
}
