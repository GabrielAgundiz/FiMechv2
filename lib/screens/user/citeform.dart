import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:fimech/screens/user/home.dart';
import 'package:fimech/screens/user/widgets/sectionheading.dart';

class CiteForm extends StatefulWidget {
  final Map<String, dynamic>? workshopData;
  const CiteForm({super.key, required this.workshopData});

  @override
  State<CiteForm> createState() => _CiteFormState();
}

class _CiteFormState extends State<CiteForm> {
  late String userId;
  List<Map<String, String>> _workshops = [];
  bool _isLoadingWorkshops = false;
  String? _selectedWorkshopId;
  String? _selectedWorkshopName;
  String? _selectedWorkshopAddress;

  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String _model = '';
  String _reason = '';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  static const List<Map<String, String>> _popularServices = [
    {'name': 'Cambio de aceite', 'time': '30–45 min'},
    {'name': 'Rotación de llantas', 'time': '30 min'},
    {'name': 'Revisión de frenos', 'time': '1 hora'},
    {'name': 'Cambio de batería', 'time': '30 min'},
    {'name': 'Cambio de filtro de aire', 'time': '15 min'},
    {'name': 'Afinación general', 'time': '2–3 horas'},
    {'name': 'Servicio de transmisión', 'time': '2–4 horas'},
    {'name': 'Cambio de líquido refrigerante', 'time': '1 hora'},
    {'name': 'Alineación y balanceo', 'time': '1 hora'},
    {'name': 'Servicio de aire acondicionado', 'time': '1–2 horas'},
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _showServicesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xF3FFF8F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'Servicios populares',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 12),
                    child: Text(
                      'Tiempo estimado',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              ...(_popularServices.map((s) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(s['name']!),
                    trailing: Text(
                      s['time']!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    onTap: () {
                      _reasonController.text = s['name']!;
                      Navigator.of(ctx).pop();
                    },
                  ))),
            ],
          ),
        );
      },
    );
  }

  Future<void> _init() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      await _loadUserPreferredWorkshop();
      await _loadWorkshops();
      // Aplicar workshopData si viene desde Talleres
      if (widget.workshopData != null && widget.workshopData!['id'] != null) {
        final wid = widget.workshopData!['id'] as String;
        _selectedWorkshopId = wid;
        _selectedWorkshopName = (widget.workshopData!['workshopName'] as String?) ?? (widget.workshopData!['name'] as String?);
        _selectedWorkshopAddress = (widget.workshopData!['workshopAddress'] as String?) ?? '';
      }
      setState(() {});
    } else {
      userId = '';
    }
  }

  Future<void> _loadUserPreferredWorkshop() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('client').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        final prefId = (data?['preferredWorkshopId'] as String?) ?? '';
        final prefName = (data?['preferredWorkshopName'] as String?) ?? '';
        if (prefId.isNotEmpty) {
          _selectedWorkshopId = prefId;
          _selectedWorkshopName = prefName;
        }
      }
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error al cargar preferencia del usuario: $e');
    }
  }

  Future<void> _loadWorkshops() async {
    setState(() {
      _isLoadingWorkshops = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin')
          .where('isMechanic', isEqualTo: true)
          .get();
      _workshops = snapshot.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': (data['workshopName'] ?? data['name'] ?? 'Taller sin nombre') as String,
          'address': (data['workshopAddress'] ?? '') as String,
        };
      }).toList();

      // Si ya había una selección, completar nombre/dirección
      if ((_selectedWorkshopId ?? '').isNotEmpty) {
        final sel = _workshops.firstWhere((w) => w['id'] == _selectedWorkshopId, orElse: () => {});
        if (sel.isNotEmpty) {
          _selectedWorkshopName = sel['name'];
          _selectedWorkshopAddress = sel['address'];
        }
      }
    } catch (e) {
      debugPrint('Error cargando talleres: $e');
      _workshops = [];
    } finally {
      setState(() {
        _isLoadingWorkshops = false;
      });
    }
  }

  Future<String> getUserEmail(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('client').doc(userId).get();
    if (userDoc.exists) return (userDoc.data()?['email'] as String?) ?? '';
    return '';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final newTime = await showTimePicker(context: context, initialTime: _selectedTime);
    if (newTime != null) {
      final selectedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        newTime.hour,
        newTime.minute,
      );

      final startTime = const TimeOfDay(hour: 9, minute: 0);
      final endTime = const TimeOfDay(hour: 17, minute: 0);

      if (_isTimeInRange(newTime, startTime, endTime)) {
        setState(() {
          _selectedTime = newTime;
          _selectedDate = selectedDateTime;
        });
      } else {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xF2FFF3FF),
            title: const Text('Hora no válida'),
            content: const Text('Por favor, seleccione una hora entre las 9 am y las 5 pm.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.green[800]),
                child: const Text('Aceptar'),
              )
            ],
          ),
        );
      }
    }
  }

  bool _isTimeInRange(TimeOfDay time, TimeOfDay startTime, TimeOfDay endTime) {
    final int t = time.hour * 60 + time.minute;
    final int s = startTime.hour * 60 + startTime.minute;
    final int e = endTime.hour * 60 + endTime.minute;
    return t >= s && t <= e;
  }

  Future<void> _saveCite() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese todos los campos'), backgroundColor: Colors.red),
      );
      return;
    }
    _formKey.currentState!.save();

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final startTime = const TimeOfDay(hour: 9, minute: 0);
    final endTime = const TimeOfDay(hour: 17, minute: 0);
    if (!_isTimeInRange(_selectedTime, startTime, endTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione una hora entre las 9:00 y las 17:00'), backgroundColor: Colors.red),
      );
      return;
    }

    if (dateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha y hora seleccionada no puede estar en el pasado'), backgroundColor: Colors.red),
      );
      return;
    }

    final appointmentRef = await FirebaseFirestore.instance.collection('citas').add({
      'userId': userId,
      'automovil': _model,
      'date': dateTime,
      'motivo': _reason,
      'status': 'Pendiente',
      'status2': 'Pendiente',
      'reason': 'Evaluando proceso',
      'reason2': 'Evaluando proceso',
      'progreso': 'Pendiente de evaluar',
      'progreso2': '',
      'date_update': dateTime,
      'costo': '',
      'idMecanico': _selectedWorkshopId ?? '',
      'workshopName': _selectedWorkshopName ?? '',
      'workshopAddress': _selectedWorkshopAddress ?? '',
      'descriptionService': '',
    });

    // Crear documentos base para diagnósticos
    final diag = appointmentRef.collection('citasDiagnostico');
    await diag.doc('Aceptado').set({'progreso2': '', 'date_update': dateTime, 'reason2': '', 'costo': '', 'descriptionService': '', 'status2': ''}, SetOptions(merge: true));
    await diag.doc('Completado').set({'progreso2': '', 'date_update': dateTime, 'reason2': '', 'costo': '', 'descriptionService': '', 'status2': ''}, SetOptions(merge: true));
    await diag.doc('Reparacion').set({'progreso2': '', 'date_update': dateTime, 'reason2': '', 'costo': '', 'descriptionService': '', 'status2': ''}, SetOptions(merge: true));
    await diag.doc('Revision').set({'progreso2': '', 'date_update': dateTime, 'reason2': '', 'costo': '', 'descriptionService': '', 'status2': ''}, SetOptions(merge: true));

    final userEmail = await getUserEmail(userId);
    EmailSender.sendMailFromGmail(userEmail);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('La cita se ha agendado correctamente. Se le enviarán actualizaciones por correo.'), duration: Duration(seconds: 2)),
    );

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    // Si la pantalla que abrió el formulario está en el stack, hacemos pop(true)
    // para regresar a esa instancia y así preservar la bottom navigation.
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop(true);
    } else {
      // Si no hay ruta previa, reemplazamos el stack por HomePage
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xF3FFF8F2),
        title: const Text('Agendar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(title: 'Detalles de la cita', showActionButton: false),
                  const SizedBox(height: 30),

                  const Text('Ingresa el modelo de automovil:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    decoration: const InputDecoration(hintText: 'Modelo del automóvil', hintStyle: TextStyle(fontSize: 14)),
                    validator: (value) => (value == null || value.isEmpty) ? 'Por favor, ingrese un modelo' : null,
                    onSaved: (value) => _model = value!.trim(),
                  ),

                  const SizedBox(height: 24),
                  const Text('Ingresa el motivo:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(hintText: 'Motivo de la cita', hintStyle: TextStyle(fontSize: 14)),
                    validator: (value) => (value == null || value.isEmpty) ? 'Por favor, ingrese un motivo' : null,
                    onSaved: (value) => _reason = value!.trim(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: TextButton(
                        onPressed: _showServicesSheet,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Ver servicios populares',
                          style: TextStyle(color: Colors.green[700], fontSize: 15),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text('Selecciona el taller:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),

                  _isLoadingWorkshops
                      ? const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()))
                      : DropdownButtonFormField<String>(
                          initialValue: (_selectedWorkshopId == '' ? null : _selectedWorkshopId),
                          decoration: const InputDecoration(),
                          hint: const Text('Seleccione un taller'),
                          items: _workshops.map((w) => DropdownMenuItem<String>(value: w['id'], child: Text(w['name'] ?? 'Taller'))).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedWorkshopId = value;
                              final sel = _workshops.firstWhere((e) => e['id'] == value, orElse: () => {});
                              if (sel.isNotEmpty) {
                                _selectedWorkshopName = sel['name'];
                                _selectedWorkshopAddress = sel['address'];
                              } else {
                                _selectedWorkshopName = '';
                                _selectedWorkshopAddress = '';
                              }
                            });
                          },
                        ),

                  const SizedBox(height: 24),
                  const Text('Ingresa el día y hora:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: TextButton(onPressed: _selectDate, child: Text('Fecha: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextButton(onPressed: _selectTime, child: Text('Hora: ${_selectedTime.format(context)}'))),
                  ]),

                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(false),
                        child: Container(
                          width: 150,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('Cancelar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          await _saveCite();
                        },
                        child: Container(
                          width: 150,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.green[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('Guardar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ),
                    ],
                  )
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
  static final gmailSmtp = gmail(dotenv.env['GMAIL_EMAIL']!, dotenv.env['GMAIL_PASSWORD']!);

  static Future<void> sendMailFromGmail(String userEmail) async {
    final message = Message()
      ..from = Address(dotenv.env['GMAIL_EMAIL']!, 'MechanicTracking')
      ..recipients.add(userEmail)
      ..subject = 'Confirmación de cita'
      ..html = '<body style="text-align: center; font-family: Tahoma, Geneva, Verdana, sans-serif;"> <div style="margin:auto; border-radius: 10px; width: 300px; padding: 10px; box-shadow: 1px 1px 1px 1px rgb(174, 174, 174);"> <h2>Hola, se ha agendado la cita en la lista de espera del taller mecanico</h2> <p>Espere a nuevas actualizaciones para saber sobre su estatus</p></div></body>';

    try {
      await send(message, gmailSmtp);
    } on MailerException {
      // ignore
    }
  }
}
