import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fimech/model/car.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fimech/model/appointment.dart';
import 'package:fimech/screens/user/diagnostic.dart';
import 'package:fimech/screens/user/widgets/verticalstepper.dart' as step;
import 'package:fimech/screens/user/widgets/verticalstepper.dart';
import 'package:fimech/screens/user/widgets/whatsappbutton.dart';
import 'package:fimech/services/appointment_service.dart';

class TrackDetailsPage extends StatefulWidget {
  final Appointment _appointment;
  TrackDetailsPage(this._appointment, {super.key});

  @override
  State<TrackDetailsPage> createState() => _TrackDetailsPageState();
}

class _TrackDetailsPageState extends State<TrackDetailsPage> {
  List<step.Step> steps = [];
  late final Future<Car?> _carFuture;
  late Diagnostico elemento1;
  late Diagnostico elemento2;
  late Diagnostico elemento3;
  late Diagnostico elemento4;
  bool paso1Cumplido = false;
  bool paso2Cumplido = false;
  bool paso3Cumplido = false;
  bool paso4Cumplido = false;

  Future<Diagnostico> validacion(
      String appointmentId, String diagnosticoId) async {
    Diagnostico cita = await AppointmentService()
        .getAppointmentTraking(appointmentId, diagnosticoId);
    return cita;
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
  void initState() {
    super.initState();
    _carFuture = _loadCar();
    _initializeSteps();
    paso1Cumplido = false;
    paso2Cumplido = false;
    paso3Cumplido = false;
    paso4Cumplido = false;
  }

  Future<void> _initializeSteps() async {
    elemento1 = await validacion(widget._appointment.id, "Aceptado");
    elemento2 = await validacion(widget._appointment.id, "Revision");
    elemento3 = await validacion(widget._appointment.id, "Reparacion");
    elemento4 = await validacion(widget._appointment.id, "Completado");

    if (widget._appointment.status == 'Pendiente' ||
        widget._appointment.status == 'Completado') {
      if (elemento1.status2 == 'Aceptado') {
        paso1Cumplido = true;
        setState(() {
          var condicion = elemento1.progreso2;
          steps.addAll(_addToStep(elemento1.progreso2, elemento1, null, null,
              null, condicion, Colors.green[300]));
        });
      }
      if (paso1Cumplido && elemento2.status2 == 'Diagnostico') {
        paso2Cumplido = true;
        setState(() {
          var condicion = elemento2.progreso2;
          steps.addAll(_addToStep(elemento2.progreso2, elemento1, elemento2,
              null, null, condicion, Colors.green[300]));
        });
      }
      if (paso2Cumplido && elemento3.status2 == 'Reparacion') {
        paso3Cumplido = true;
        setState(() {
          var condicion = elemento3.progreso2;
          steps.addAll(_addToStep(elemento3.progreso2, elemento1, elemento2,
              elemento3, null, condicion, Colors.green[300]));
        });
      }
      if (paso3Cumplido && elemento4.status2 == 'Completado') {
        paso4Cumplido = true;
        setState(() {
          var condicion = elemento4.progreso2;
          steps.addAll(_addToStep(elemento4.progreso2, elemento1, elemento2,
              elemento3, elemento4, condicion, Colors.green[300]));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: AppointmentService()
            .getAppointmentTraking(widget._appointment.id, "Aceptado"),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: const Color(0xF3FFF8F2),
                title: Text(
                  "Detalles",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              bottomNavigationBar: WhatsappButton(
                  widget._appointment.id, widget._appointment.auto),
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 20,
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 60),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                widget._appointment.motivo,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Vehicle card ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: FutureBuilder<Car?>(
                          future: _carFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: CircularProgressIndicator(
                                      color: Colors.green),
                                ),
                              );
                            }
                            final car = snapshot.data;
                            if (car != null) return _VehicleCard(car: car);
                            return _FallbackVehicleCard(
                                name: widget._appointment.auto);
                          },
                        ),
                      ),

                      // ── Workshop info ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              widget._appointment.workshopName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget._appointment.workshopAddress,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      if (steps.isEmpty)
                        const Center(child: Text('No hay información'))
                      else
                        Column(
                          children: [_creacionStepper(steps)],
                        ),
                    ],
                  ),
                ),
              ),
            );
          }
        });
  }

  /*void _openTrackingDetailsForm(
      BuildContext context,
      Appointment? appointment,
      Diagnostico? diagnostico,
      Diagnostico? diagnostico2,
      Diagnostico? diagnostico3) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => TrackFormAD(
              appointment!, diagnostico!, diagnostico2!, diagnostico3!)),
    );
  }*/

  VerticalStepper _creacionStepper(List<step.Step> steps) {
    return VerticalStepper(steps: steps, dashLength: 2);
  }

  List<step.Step> _addToStep(
    String title,
    Diagnostico? diagnostico,
    Diagnostico? diagnostico2,
    Diagnostico? diagnostico3,
    Diagnostico? diagnostico4,
    String condicion,
    Color? iconStyle,
  ) {
    List<step.Step> steps = [];

    if (diagnostico != null && condicion == diagnostico.progreso2) {
      steps.add(step.Step(
        //shimmer: false,
        title: 'Vehiculo ' + diagnostico.id + " : " + diagnostico.progreso2,
        iconStyle: iconStyle,
        content: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            children: [
              Container(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(diagnostico.dateUpdate),
                      textAlign: TextAlign.left,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      DateFormat.jm().format(diagnostico.dateUpdate),
                      textAlign: TextAlign.left,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  diagnostico.reason2,
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
      ));
    }

    if (diagnostico2 != null && condicion == diagnostico2.progreso2) {
      steps.add(step.Step(
        //shimmer: false,
        title:
            'Vehiculo en ' + diagnostico2.id + " : " + diagnostico2.progreso2,
        iconStyle: iconStyle,
        content: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            children: [
              Container(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(diagnostico2.dateUpdate),
                      textAlign: TextAlign.left,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      DateFormat.jm().format(diagnostico2.dateUpdate),
                      textAlign: TextAlign.left,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  diagnostico2.reason2,
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
      ));
    }

    if (diagnostico3 != null && condicion == diagnostico3.progreso2) {
      steps.add(step.Step(
        //shimmer: false,
        title: 'Vehiculo Diagnosticado : ${diagnostico3.progreso2}',
        iconStyle: iconStyle,
        content: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            children: [
              Container(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(diagnostico3.dateUpdate),
                      textAlign: TextAlign.left,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      DateFormat.jm().format(diagnostico3.dateUpdate),
                      textAlign: TextAlign.left,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  diagnostico3.reason2,
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Container(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(right: 63),
                  child: Builder(builder: (context) {
                    return InkWell(
                      onTap: () {
                        _openDiagnosticDetails(
                            context, widget._appointment, elemento3);
                      },
                      child: Container(
                        width: 115,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            "Diagnostico",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ));
    }

    if (diagnostico4 != null && condicion == diagnostico4.progreso2) {
      steps.add(step.Step(
        //shimmer: false,
        title: 'Vehiculo ' + diagnostico4.id + " : " + diagnostico4.progreso2,
        iconStyle: iconStyle,
        content: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            children: [
              Container(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(diagnostico4.dateUpdate),
                      textAlign: TextAlign.left,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      DateFormat.jm().format(diagnostico4.dateUpdate),
                      textAlign: TextAlign.left,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  diagnostico4.reason2,
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
      ));
    }

    return steps;
  }

  void _openDiagnosticDetails(BuildContext context, Appointment? appointment,
      Diagnostico? diagnostico) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => DiagnosticPage(appointment!, diagnostico!)),
    );
  }
}

// ── Vehicle card (full data) ──────────────────────────────────────────────────

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
            color: Colors.black.withValues(alpha: 0.08),
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
                  child: Icon(Icons.directions_car,
                      color: Colors.green[400], size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${car.brand} ${car.model}',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        car.year,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54),
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
            color: Colors.black.withValues(alpha: 0.08),
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
              child: Icon(Icons.directions_car,
                  color: Colors.green[400], size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info item (icon + label + value) ─────────────────────────────────────────

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem(
      {required this.icon, required this.label, required this.value});

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
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.black45)),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
