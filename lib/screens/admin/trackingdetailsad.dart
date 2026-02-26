import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fimech/model/appointment.dart';
import 'package:fimech/screens/admin/diagnosticad.dart';
import 'package:fimech/screens/admin/trackformad.dart';
import 'package:fimech/screens/admin/widgets/whatsappbuttonad.dart';
import 'package:fimech/screens/user/widgets/verticalstepper.dart'
    as step;
import 'package:fimech/screens/user/widgets/verticalstepper.dart';
import 'package:fimech/services/appointment_service.dart';

class TrackDetailsPageAD extends StatefulWidget {
  final Appointment _appointment;

  TrackDetailsPageAD(this._appointment, {super.key});

  @override
  State<TrackDetailsPageAD> createState() => _TrackDetailsPageADState();
}

class _TrackDetailsPageADState extends State<TrackDetailsPageAD> {
  List<step.Step> steps = [];
  late Diagnostico elemento1;
  late Diagnostico elemento2;
  late Diagnostico elemento3;
  late Diagnostico elemento4;
  bool paso1Cumplido = false;
  bool paso2Cumplido = false;
  bool paso3Cumplido = false;
  bool paso4Cumplido = false;
  String? userPhoneNumber;

  Future<Diagnostico> validacion(
      String appointmentId, String diagnosticoId) async {
    Diagnostico cita = await AppointmentService()
        .getAppointmentTraking(appointmentId, diagnosticoId);
    return cita;
  }

  @override
  void initState() {
    super.initState();
    _initializeSteps();
    _getUserPhoneNumber();
    paso1Cumplido = false;
    paso2Cumplido = false;
    paso3Cumplido = false;
    paso4Cumplido = false;
  }

  Future<void> _getUserPhoneNumber() async {
    userPhoneNumber = await getUserPhoneNumber(widget._appointment.userId);
    setState(() {}); // To trigger a rebuild with the updated phone number
  }

  Future<void> _initializeSteps() async {
    elemento1 = await validacion(widget._appointment.id, "Aceptado");
    elemento2 = await validacion(widget._appointment.id, "Revision");
    elemento3 = await validacion(widget._appointment.id, "Reparacion");
    elemento4 = await validacion(widget._appointment.id, "Completado");

    if (widget._appointment.status == 'Pendiente') {
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
                title: const Text(
                  'Detalles',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ), // Título de la barra de aplicación
              ),
              bottomNavigationBar: userPhoneNumber == null
                  ? const SizedBox(
                      height: 60,

                    )
                  : (userPhoneNumber!.isEmpty
                      ? const SizedBox.shrink()
                      : WhatsappButtonAD(widget._appointment.id, widget._appointment.auto, userPhoneNumber!)),
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
                            children: [
                              Text(
                                widget._appointment.auto,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(widget._appointment.motivo),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      if (steps.isEmpty)
                        const Text('No hay información')
                      else
                        Column(
                          children: [_creacionStepper(steps)],
                        ),
                    ],
                  ),
                ),
              ),
              floatingActionButton: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: FloatingActionButton(
                  backgroundColor: Colors.green[300],
                  onPressed: () {
                    _openTrackingDetailsForm(context, widget._appointment,
                        elemento1, elemento2, elemento3);
                  },
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endDocked,
            );
          }
        });
  }

  void _openTrackingDetailsForm(
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
  }

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
        title:
            'Vehiculo en ' + diagnostico4.id + " : " + diagnostico4.progreso2,
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
          builder: (context) => DiagnosticPageAD(appointment!, diagnostico!)),
    );
  }
}
