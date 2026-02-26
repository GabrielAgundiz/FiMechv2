import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fimech/model/appointment.dart';
import 'package:fimech/screens/user/trackdetails.dart';
import 'package:fimech/services/appointment_service.dart';

class CompletedTrackingAD extends StatefulWidget {
  const CompletedTrackingAD({super.key});

  @override
  State<CompletedTrackingAD> createState() => _CompletedTrackingADState();
}

class _CompletedTrackingADState extends State<CompletedTrackingAD> {
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
  String? _workshopImageUrl; // imagen del taller asignado
  bool _diagnosticoRejected = false; // flag si algún diagnostico está rechazado

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
    final mechanicId = appointment.idMecanico;
    if (mechanicId.isNotEmpty) {
      _loadWorkshopImage(mechanicId);
    }
    // Cargar estado de los diagnosticos asociados para saber si alguno fue rechazado
    _loadDiagnosticoRejected(appointmentId);
  }

  Future<void> _loadDiagnosticoRejected(String appointmentId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('citas')
          .doc(appointmentId)
          .collection('citasDiagnostico')
          .get();
      bool rejected = false;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final diag = (data['diagnostico'] as String?) ?? (data['status2'] as String?);
        if (diag != null && diag.toLowerCase() == 'rechazado') {
          rejected = true;
          break;
        }
      }
      if (mounted) {
        setState(() => _diagnosticoRejected = rejected);
      }
    } catch (_) {
      // ignore errors and keep false
    }
  }

  Future<void> _loadWorkshopImage(String mechanicId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('admin').doc(mechanicId).get();
      if (doc.exists) {
        final data = doc.data();
        final url = data?['workshopImage'] as String;
        if (mounted) {
          setState(() {
            _workshopImageUrl = url;
          });
        }
      }
    } catch (_) {
      // ignore errors and keep fallback
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
                ListTile(
                  title: Text(
                    _appointment!.auto,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _diagnosticoRejected ? Colors.red : Colors.black,
                    ),
                  ),
                  subtitle: Text(_appointment!.motivo),
                  trailing: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey[200],
                    child: ClipOval(
                      child: (_workshopImageUrl != null && _workshopImageUrl!.isNotEmpty)
                          ? Image.network(
                              _workshopImageUrl!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Icon(Icons.car_repair, color: Colors.black54),
                                );
                              },
                            )
                          : const SizedBox(
                              width: 50,
                              height: 50,
                              child: Icon(Icons.car_repair, color: Colors.black54),
                            ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Divider(
                    thickness: 1,
                    height: 20,
                  ),
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
                        const SizedBox(width: 3),
                        Text(
                          DateFormat('dd/MM/yyyy').format(_appointment!.date),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(width: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_filled,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          DateFormat.jm().format(_appointment!.date),
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
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
    }
    {
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
          child: const Column(
            children: [
              Text(
                "Aún no tiene citas canceladas",
                style: TextStyle(color: Colors.black54),
              )
            ],
          ),
        ),
      );
    }
  }

  void _openTrackingDetails(BuildContext context, Appointment? appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TrackDetailsPage(appointment!)),
    );
  }
}
