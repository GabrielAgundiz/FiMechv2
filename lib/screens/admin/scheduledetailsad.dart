import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fimech/model/appointment.dart';
import 'package:fimech/screens/admin/widgets/whatsappbuttonad.dart';
import 'package:fimech/screens/user/widgets/sectionheading.dart';
import '../../services/appointment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:fimech/services/car_service.dart';

class ScheduleDetailsPageAD extends StatefulWidget {
  final Appointment _appointment;

  const ScheduleDetailsPageAD(this._appointment, {super.key});

  @override
  State<ScheduleDetailsPageAD> createState() => _ScheduleDetailsPageADState();
}

class _ScheduleDetailsPageADState extends State<ScheduleDetailsPageAD> {
  @override
  void initState() {
    super.initState();
    _getUserPhoneNumber();
    // Inicializar valores locales del taller (para poder actualizar en la UI cuando se cambia)
    _currentWorkshopName = widget._appointment.workshopName;
    _currentWorkshopAddress = widget._appointment.workshopAddress;
    // Inicializar estado local con el estado actual de la cita
    _currentStatus = widget._appointment.status;
    // Inicializar fecha actual local para permitir cambios y refrescar la UI
    _currentDate = widget._appointment.date;
  }

  String? userPhoneNumber;

  // Valores locales para mostrar el taller actual y permitir actualizar la UI
  late String _currentWorkshopName;
  late String _currentWorkshopAddress;
  // Estado local para reflejar cambios en la UI sin reconstruir el widget padre
  late String _currentStatus;
  // Fecha local que se mostrará y actualizará cuando el admin cambie la fecha
  late DateTime _currentDate;

  // Lista de talleres (dueños registrados como mecanicos) que se muestran en el modal
  List<Map<String, String>> _workshops = [];
  bool _isLoadingWorkshops = false;

  Future<void> _getUserPhoneNumber() async {
    userPhoneNumber = await getUserPhoneNumber(widget._appointment.userId);
    setState(() {}); // To trigger a rebuild with the updated phone number
  }

  // Devuelve true si la cita está en el futuro (próxima)
  bool _isUpcoming() {
    return _currentDate.isAfter(DateTime.now());
  }

  // Muestra selector de fecha y hora, y devuelve la nueva DateTime o null
  Future<DateTime?> _pickNewDateTime() async {
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _currentDate.isAfter(now) ? _currentDate : now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (pickedDate == null) return null;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_currentDate),
    );
    if (pickedTime == null) return null;

    return DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
  }

  // Actualiza la fecha de la cita en Firestore y notifica al usuario por correo
  Future<void> _changeDate(DateTime newDate) async {
    try {
      await FirebaseFirestore.instance.collection('citas').doc(widget._appointment.id).update({
        'date': newDate,
        'date_update': DateTime.now(),
      });

      setState(() {
        _currentDate = newDate;
      });

      // Mostrar snackbar confirmando cambio
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha se ha cambiado correctamente')),
      );

      // Enviar email al usuario notificando el cambio
      String? userEmail = await getUserEmail(widget._appointment.userId);
      if (userEmail != null && userEmail.isNotEmpty) {
        await _sendDateChangedEmail(userEmail, newDate);
      } else {
        print('Usuario no tiene email registrado');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cambiar la fecha: $e')),
      );
    }
  }

  // Envía un correo informando que la fecha ha sido cambiada
  Future<void> _sendDateChangedEmail(String userEmail, DateTime newDate) async {
    try {
      final smtpServer = gmail(dotenv.env['GMAIL_EMAIL']!, dotenv.env['GMAIL_PASSWORD']!);
      final formattedDate = DateFormat('dd/MM/yyyy').format(newDate);
      final formattedTime = DateFormat.jm().format(newDate);
      final message = Message()
        ..from = Address(dotenv.env['GMAIL_EMAIL']!, 'MechanicTracking')
        ..recipients.add(userEmail)
        ..subject = 'Cambio de fecha de su cita'
        ..html =
            '<body style="text-align: center; font-family: Tahoma, Geneva, Verdana, sans-serif;">'
            '<div style="margin:auto; border-radius: 10px; width: 300px; padding: 10px; box-shadow: 1px 1px 1px 1px rgb(174, 174, 174);">'
            '<h2>Fecha de cita actualizada</h2>'
            '<p>Su cita ha sido reprogramada al <b>$formattedDate</b> a las <b>$formattedTime</b>.</p>'
            '<p>Si tiene alguna duda, contáctenos a través de la app.</p>'
            '</div></body>';

      final sendReport = await send(message, smtpServer);
      print('Email sent: $sendReport');
    } on MailerException catch (e) {
      print('Error sending email: $e');
    } catch (e) {
      print('Unknown error sending email: $e');
    }
  }

  // Carga los talleres desde la colección 'admin' donde isMechanic == true
  Future<void> _loadWorkshops() async {
    setState(() {
      _isLoadingWorkshops = true;
    });
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('admin')
          .where('isMechanic', isEqualTo: true)
          .get();

      _workshops = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': (data['workshopName'] ?? data['name'] ?? 'Taller sin nombre') as String,
          'address': (data['workshopAddress'] ?? '') as String,
        };
      }).toList();
    } catch (e) {
      // En caso de error, limpiamos la lista y lo informamos en consola
      _workshops = [];
      print('Error cargando talleres: $e');
    } finally {
      setState(() {
        _isLoadingWorkshops = false;
      });
    }
  }

  // Actualiza la cita en Firestore con el taller seleccionado
  Future<void> _changeWorkshop(Map<String, String> selected) async {
    try {
      await FirebaseFirestore.instance
          .collection('citas')
          .doc(widget._appointment.id)
          .update({
        'idMecanico': selected['id'],
        'workshopName': selected['name'],
        'workshopAddress': selected['address'],
      });

      // Actualizamos los valores locales para refrescar la UI
      setState(() {
        _currentWorkshopName = selected['name']!;
        _currentWorkshopAddress = selected['address']!;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taller actualizado correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar taller: $e')),
      );
    }
  }

  // Actualizar el estado de la cita (Pendiente / Completado / Cancelado)
  Future<void> _updateStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('citas').doc(widget._appointment.id).update({
        'status': newStatus,
        'status2': newStatus,
        'date_update': DateTime.now(),
      });

      if ((newStatus == 'Cancelado' || newStatus == 'Completado') &&
          widget._appointment.carId.isNotEmpty) {
        await CarService().updateCar(widget._appointment.carId, {'inService': false});
      }

      setState(() {
        _currentStatus = newStatus;
      });

      // Mostrar snackbar con color según estado
      Color bg = Colors.blueGrey;
      if (newStatus == 'Completado') bg = Colors.green;
      if (newStatus == 'Cancelado') bg = Colors.red;
      if (newStatus == 'Pendiente') bg = Colors.orange;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado a "$newStatus"'),
          backgroundColor: bg,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar estado: $e')),
      );
    }
  }

  // Abre un modal con la lista de talleres para seleccionar
  Future<void> _showChangeWorkshopDialog() async {
    // Cargar talleres antes de mostrar el modal (si no están cargados)
    if (_workshops.isEmpty) {
      await _loadWorkshops();
    }

    // Mostrar modal inferior con la lista de talleres
    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (_isLoadingWorkshops) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (_workshops.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No hay talleres disponibles')),
          );
        }

        return SizedBox(
          height: 400,
          child: ListView.builder(
            itemCount: _workshops.length,
            itemBuilder: (context, index) {
              final w = _workshops[index];
              return ListTile(
                title: Text(w['name'] ?? 'Taller'),
                subtitle: Text(w['address'] ?? ''),
                onTap: () async {
                  Navigator.of(context).pop(); // Cerrar modal
                  await _changeWorkshop(w);
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xF3FFF8F2),
        title: const Text(
          'Detalles',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SectionHeading(
                title: "Detalles de la cita",
                showActionButton: false,
              ),
              const SizedBox(
                height: 30,
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Modelo",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      maxLines: 2,
                      widget._appointment.auto,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Motivo:",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      maxLines: 20,
                      widget._appointment.motivo,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Fecha:",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      maxLines: 2,
                      DateFormat('dd/MM/yyyy').format(widget._appointment.date),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Hora:",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      maxLines: 2,
                      DateFormat.jm().format(widget._appointment.date),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Taller Mecánico:",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      maxLines: 20,
                      // Mostrar el nombre del taller desde el valor local (se actualiza si el admin lo cambia)
                      _currentWorkshopName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Dirección del taller:",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      maxLines: 20,
                      // Mostrar dirección actual del taller
                      _currentWorkshopAddress,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      "Estado:",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      maxLines: 2,
                      _currentStatus,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Mostrar botón para cambiar taller sólo si la cita es próxima (futura)
              if (_isUpcoming()) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.swap_horiz, color: Colors.black,),
                    label: Text('Cambiar taller', style: TextStyle(color: Colors.black),),
                    onPressed: () async {
                      await _showChangeWorkshopDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[300],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Botón para cambiar la fecha (visible sólo si la cita es futura)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today, color: Colors.black,),
                    label: Text('Cambiar fecha', style: TextStyle(color: Colors.black),),
                    onPressed: () async {
                      final DateTime? newDate = await _pickNewDateTime();
                      if (newDate != null) {
                        await _changeDate(newDate);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[300],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Botón para que el admin actualice el estado manualmente
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_calendar, color: Colors.black),
                  label: const Text('Actualizar estado', style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[300],
                  ),
                  onPressed: () async {
                    final choice = await showModalBottomSheet<String>(
                      context: context,
                      builder: (context) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.pending_actions),
                                title: const Text('Pendiente'),
                                onTap: () => Navigator.of(context).pop('Pendiente'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.check_circle),
                                title: const Text('Completado'),
                                onTap: () => Navigator.of(context).pop('Completado'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.cancel),
                                title: const Text('Cancelado'),
                                onTap: () => Navigator.of(context).pop('Cancelado'),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      },
                    );
                    if (choice != null && choice.isNotEmpty) {
                      await _updateStatus(choice);
                    }
                  },
                ),
              ),

            ],
          ),
        ),
      )),
    );
  }
}
