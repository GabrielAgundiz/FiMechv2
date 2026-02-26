import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:fimech/model/appointment.dart';
import 'package:fimech/screens/admin/homead.dart';
import 'package:fimech/screens/user/widgets/sectionheading.dart';

class TrackFormAD extends StatefulWidget {
  final Appointment _appointment;
  final Diagnostico _diagnostico;
  final Diagnostico _diagnostico2;
  final Diagnostico _diagnostico3;

  TrackFormAD(this._appointment, this._diagnostico, this._diagnostico2,
      this._diagnostico3,
      {super.key});

  @override
  State<TrackFormAD> createState() => _TrackFormADState();
}

class _TrackFormADState extends State<TrackFormAD> {
  Appointment? _appointment;
  //estado de la cita
  final _formKey = GlobalKey<FormState>();
  bool _includeDiagnostic = false;
  final String _progreso = '';
  final String _reason = '';
  final DateTime _selectedDate = DateTime.now();
  final TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  late String userId;

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

  late TextEditingController _progresoController;
  late TextEditingController _reasonController;
  late TextEditingController _descriptionController;
  late TextEditingController _costController;

  Future<String> getUserEmail(String userId) async {
    var userDoc =
        await FirebaseFirestore.instance.collection('client').doc(userId).get();
    if (userDoc.exists) {
      return userDoc.data()!['email'];
    } else {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    getUserId();
    _progresoController = TextEditingController();
    _reasonController = TextEditingController();
    _descriptionController = TextEditingController();
    _costController = TextEditingController();
  }

  @override
  void dispose() {
    _progresoController.dispose();
    _reasonController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _saveCite() async {
    setState(() {});
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final dateTime = DateTime.now();
      if (widget._appointment.status2 == 'Pendiente') {
        _saveInfoAceptado(dateTime);
      } else if (widget._appointment.status2 == 'Aceptado') {
        _saveInfoRevision(dateTime);
      } else if (widget._appointment.status2 == 'Diagnostico') {
        _saveInfoReparacion(dateTime);
      } else if (widget._appointment.status2 == 'Reparacion') {
        _saveInfoCompletado(dateTime);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cambios guardados correctamente'),
        ),
      );
    }
  }

  Future<void> _saveInfoAceptado(DateTime dateTime) async {
    await FirebaseFirestore.instance
        .collection('citas')
        .doc(widget._appointment.id)
        .collection(
            'citasDiagnostico') // Agregar una subcolección 'citasDiagnostico' dentro del documento
        .doc(
            'Aceptado') // Puedes usar un ID único o el mismo ID del documento principal
        .set({
      'progreso2': _progresoController.text,
      'date_update': dateTime,
      'reason2': _reasonController.text,
      'costo': _costController.text,
      'descriptionService': _descriptionController.text,
      'status2': 'Aceptado',
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance
        .collection('citas')
        .doc(widget._appointment.id)
        .set({
      'progreso2': _progresoController.text,
      'date_update': dateTime,
      'reason': _reasonController.text,
      'status2': 'Aceptado',
    }, SetOptions(merge: true));
    // Obtener el email del usuario
    String userEmail = await getUserEmail(widget._appointment.userId);
    EmailSender.sendMailFromGmailAceptado(userEmail);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => HomePageAD()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _saveInfoRevision(DateTime dateTime) async {
    await FirebaseFirestore.instance
        .collection('citas')
        .doc(widget._appointment.id)
        .collection(
            'citasDiagnostico') // Agregar una subcolección 'citasDiagnostico' dentro del documento
        .doc(
            'Revision') // Puedes usar un ID único o el mismo ID del documento principal
        .set({
      'progreso2': _progresoController.text,
      'date_update': dateTime,
      'reason2': _reasonController.text,
      'costo': _costController.text,
      'descriptionService': _descriptionController.text,
      'status2': 'Diagnostico',
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance
        .collection('citas')
        .doc(widget._appointment.id)
        .set({
      'progreso2': _progresoController.text,
      'date_update': dateTime,
      'reason2': _reasonController.text,
      'costo': _costController.text,
      'descriptionService': _descriptionController.text,
      'status2': 'Diagnostico',
      'idMecanico': userId,
    }, SetOptions(merge: true));
    // Obtener el email del usuario
    String userEmail = await getUserEmail(widget._appointment.userId);

    EmailSender.sendMailFromGmailRevision(userEmail);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => HomePageAD()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _saveInfoReparacion(DateTime dateTime) async {
    await FirebaseFirestore.instance
        .collection('citas')
        .doc(widget._appointment.id)
        .collection(
            'citasDiagnostico') // Agregar una subcolección 'citasDiagnostico' dentro del documento
        .doc(
            'Reparacion') // Puedes usar un ID único o el mismo ID del documento principal
        .set({
      'progreso2': _progresoController.text,
      'date_update': dateTime,
      'reason2': _reasonController.text,
      'costo': _costController.text,
      'descriptionService': _descriptionController.text,
      'status2': 'Reparacion',
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('citas')
        .doc(widget._appointment.id)
        .set({
      'progreso': _progresoController.text,
      'date_update': dateTime,
      'reason': _reasonController.text,
      'status2': 'Reparacion',
    }, SetOptions(merge: true));
    // Obtener el email del usuario
    String userEmail = await getUserEmail(widget._appointment.userId);
    EmailSender.sendMailFromGmailDiagnostico(userEmail);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePageAD()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _saveInfoCompletado(DateTime dateTime) async {
    await FirebaseFirestore.instance
        .collection('citas')
        .doc(widget._appointment.id)
        .collection(
            'citasDiagnostico') // Agregar una subcolección 'citasDiagnostico' dentro del documento
        .doc(
            'Completado') // Puedes usar un ID único o el mismo ID del documento principal
        .set({
      'progreso2': _progresoController.text,
      'date_update': dateTime,
      'reason2': _reasonController.text,
      'costo': _costController.text,
      'descriptionService': _descriptionController.text,
      'status2': 'Completado',
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance
        .collection('citas')
        .doc(widget._appointment.id)
        .set({
      'progreso': _progresoController.text,
      'date_update': dateTime,
      'reason': _reasonController.text,
      'status': 'Completado',
    }, SetOptions(merge: true));
    // Obtener el email del usuario
    String userEmail = await getUserEmail(widget._appointment.userId);
    EmailSender.sendMailFromGmailCompletado(userEmail);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePageAD()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool Diagnostico = false;
    if (widget._appointment.status2 == 'Diagnostico') {
      Diagnostico = true;
    } else {
      Diagnostico = false;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xF3FFF8F2),
        title: Text(
          //'Actualizar',
          widget._appointment.auto,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SectionHeading(
                    title: "Estado del servicio",
                    showActionButton: false,
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      "Ingresa el estado del automovil:",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                        hintText: 'Estado del automóvil',
                        hintStyle: TextStyle(fontSize: 14)),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingrese un estado';
                      }
                      return null;
                    },
                    controller: _progresoController,
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      "Descripción del estado:",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                        hintText: 'Descripción del estado',
                        hintStyle: TextStyle(fontSize: 14)),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingrese un motivo';
                      }
                      return null;
                    },
                    controller: _reasonController,
                  ),
                  const SizedBox(
                    height: 24,
                  ),
                  Diagnostico
                      ? Container(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              const Text(
                                "¿Incluye Diagnóstico?",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Checkbox(
                                value:
                                    _includeDiagnostic, // Add a boolean variable to store the checkbox state
                                onChanged: (value) {
                                  setState(() {
                                    _includeDiagnostic = value!;
                                  });
                                },
                              ),
                            ],
                          ),
                        )
                      : Container(),
                  const SizedBox(
                    height: 30,
                  ),
                  _includeDiagnostic
                      ? Container(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            children: [
                              Container(
                                alignment: Alignment.centerLeft,
                                child: const Text(
                                  "Automovil:",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(
                                height: 6,
                              ),
                              TextFormField(
                                decoration: InputDecoration(
                                    hintText: widget._appointment.auto,
                                    hintStyle: const TextStyle(fontSize: 14)),
                                readOnly: true,
                                /*validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, ingrese un motivo';
                                  }
                                  return null;
                                },
                                onSaved: (value) => _reason = value!,*/
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              Container(
                                alignment: Alignment.centerLeft,
                                child: const Text(
                                  "Reparacion:",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(
                                height: 6,
                              ),
                              TextFormField(
                                decoration: InputDecoration(
                                    hintText: widget._appointment.motivo,
                                    hintStyle: const TextStyle(fontSize: 14)),
                                readOnly: true,
                                /*validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, ingrese un motivo';
                                  }
                                  return null;
                                },
                                onSaved: (value) => _reason = value!,*/
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              Container(
                                alignment: Alignment.centerLeft,
                                child: const Text(
                                  "Descripcion:",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(
                                height: 6,
                              ),
                              TextFormField(
                                decoration: const InputDecoration(
                                    hintText: 'Descripcion de la reparacion',
                                    hintStyle: TextStyle(fontSize: 14)),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, ingrese un motivo';
                                  }
                                  return null;
                                },
                                controller: _descriptionController,
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              Container(
                                alignment: Alignment.centerLeft,
                                child: const Text(
                                  "Costo:",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(
                                height: 6,
                              ),
                              TextFormField(
                                decoration: const InputDecoration(
                                    hintText: 'Costo de la reparacion MXN',
                                    hintStyle: TextStyle(fontSize: 14)),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, ingrese un costo';
                                  }
                                  return null;
                                },
                                controller: _costController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}$')),
                                ],
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                            ],
                          ),
                        )
                      : Container(),
                  const SizedBox(
                    height: 50,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 150,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              "Cancelar",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _saveCite,
                        child: Container(
                          width: 150,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.green[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              "Guardar",
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmailSender {
  static final gmailSmtp =
      gmail(dotenv.env["GMAIL_EMAIL"]!, dotenv.env["GMAIL_PASSWORD"]!);

  static Future<void> sendMailFromGmailAceptado(String userEmail) async {
    final message = Message()
      ..from = Address(dotenv.env["GMAIL_EMAIL"]!, 'MechanicTracking')
      ..recipients.add(userEmail)
      ..subject = 'Confirmación de cita'
      ..html =
          '<body style="text-align: center; font-family: Tahoma, Geneva, Verdana, sans-serif;"> <div style="margin:auto; border-radius: 10px; width: 300px; padding: 10px; box-shadow: 1px 1px 1px 1px rgb(174, 174, 174);"> <h2>Cita aceptada</h2> <p>Hola<p>Su cita ha sido aceptada dentro del taller mecanico. Espere a nuevas actualizaciones para saber sobre el estatus de su vehiculo</p></div></body>';

    try {
      final sendReport = await send(message, gmailSmtp);
      print('Message sent: $sendReport');
    } on MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }

  static Future<void> sendMailFromGmailRevision(String userEmail) async {
    final message = Message()
      ..from = Address(dotenv.env["GMAIL_EMAIL"]!, 'MechanicTracking')
      ..recipients.add(userEmail)
      ..subject = 'Confirmación de cita'
      ..html =
          '<body style="text-align: center; font-family: Tahoma, Geneva, Verdana, sans-serif;"> <div style="margin:auto; border-radius: 10px; width: 300px; padding: 10px; box-shadow: 1px 1px 1px 1px rgb(174, 174, 174);"> <h2>Vehiculo en revision</h2> <p>Hola,</p><p>Su vehiculo ha entrado en el proceso de revision.</p><p> Espere a nuevas actualizaciones para saber sobre el estatus de su vehiculo.</p></div></body>';

    try {
      final sendReport = await send(message, gmailSmtp);
      print('Message sent: $sendReport');
    } on MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }

  static Future<void> sendMailFromGmailDiagnostico(String userEmail) async {
    final message = Message()
      ..from = Address(dotenv.env["GMAIL_EMAIL"]!, 'MechanicTracking')
      ..recipients.add(userEmail)
      ..subject = 'Confirmación de cita'
      ..html =
          '<body style="text-align: center; font-family: Tahoma, Geneva, Verdana, sans-serif;"> <div style="margin:auto; border-radius: 10px; width: 300px; padding: 10px; box-shadow: 1px 1px 1px 1px rgb(174, 174, 174);"> <h2>Vehiculo diagnosticado</h2> <p>Hola,</p><p>Su vehiculo ha sido diagnosticado.</p><p> Revise la cotización dentro de la aplicacion y acepte o rechace la misma.</p></div></body>';

    try {
      final sendReport = await send(message, gmailSmtp);
      print('Message sent: $sendReport');
    } on MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }

  static Future<void> sendMailFromGmailReparacion(String userEmail) async {
    final message = Message()
      ..from = Address(dotenv.env["GMAIL_EMAIL"]!, 'MechanicTracking')
      ..recipients.add(userEmail)
      ..subject = 'Confirmación de cita'
      ..html =
          '<body style="text-align: center; font-family: Tahoma, Geneva, Verdana, sans-serif;"> <div style="margin:auto; border-radius: 10px; width: 300px; padding: 10px; box-shadow: 1px 1px 1px 1px rgb(174, 174, 174);"> <h2>Vehiculo en reparacion</h2> <p>Hola,</p><p>Su vehiculo ha entrado en el proceso de reparacion.</p><p> Este al pendiente de las nuevas actualizaciones del estatus de su vehiculo.</p></div></body>';

    try {
      final sendReport = await send(message, gmailSmtp);
      print('Message sent: $sendReport');
    } on MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }

  static Future<void> sendMailFromGmailCompletado(String userEmail) async {
    final message = Message()
      ..from = Address(dotenv.env["GMAIL_EMAIL"]!, 'MechanicTracking')
      ..recipients.add(userEmail)
      ..subject = 'Confirmación de cita'
      ..html =
          '<body style="text-align: center; font-family: Tahoma, Geneva, Verdana, sans-serif;"> <div style="margin:auto; border-radius: 10px; width: 300px; padding: 10px; box-shadow: 1px 1px 1px 1px rgb(174, 174, 174);"> <h2>Reparación completada</h2> <p>Hola,</p><p>Su vehiculo ha terminado con el proceso de reparación. Por favor pase por el al taller mecanico</p></div></body>';

    try {
      final sendReport = await send(message, gmailSmtp);
      print('Message sent: $sendReport');
    } on MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }
}
