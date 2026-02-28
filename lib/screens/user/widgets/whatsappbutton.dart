import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fimech/services/appointment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Helper para normalizar el teléfono a formato internacional sin '+'
String? _normalizePhone(String? phone) {
  if (phone == null) return null;
  String digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (digits.length == 10) {
    digits = '52$digits'; // asumir México si 10 dígitos
  }
  if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length < 11) return null;
  return digits;
}

class WhatsappButton extends StatelessWidget {
  final String idCita;
  final String nombre;
  const WhatsappButton(this.idCita, this.nombre, {super.key});

  Future<String?> _getWorkshopPhoneForAppointment(String appointmentId) async {
    try {
      // Obtener cita
      final appointment = await AppointmentService().getAppointment(appointmentId);
      final String mechanicId = appointment.idMecanico;
      if (mechanicId.isEmpty) return null;
      // Leer documento del mecanico en 'admin' para obtener el teléfono
      final doc = await FirebaseFirestore.instance.collection('admin').doc(mechanicId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return data['phone'] as String?;
    } catch (e) {
      debugPrint('Error obteniendo teléfono del taller: $e');
      return null;
    }
  }

  void _launchWhatsapp(BuildContext context, {required String number, required String message}) async {
    final encodedMessage = Uri.encodeComponent(message);
    final String androidUrl = "whatsapp://send?phone=$number&text=$encodedMessage";
    final Uri androidUri = Uri.parse(androidUrl);

    final String webUrl = "https://api.whatsapp.com/send?phone=$number&text=$encodedMessage";
    final Uri webUri = Uri.parse(webUrl);

    try {
      if (await canLaunchUrl(androidUri)) {
        await launchUrl(androidUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al abrir WhatsApp: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getWorkshopPhoneForAppointment(idCita),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final rawPhone = snapshot.data;
        final normalized = _normalizePhone(rawPhone);
        final String normalizedNonNull = normalized ?? ''; // no-nulo para usar en el callback
        final bool isEnabled = normalizedNonNull.isNotEmpty;
        final String message = "Hola, tengo una consulta sobre mi cita (id: $idCita) y el auto: $nombre";

        return GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: isEnabled
                  ? () => _launchWhatsapp(context, number: normalizedNonNull, message: message)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(FontAwesomeIcons.whatsapp),
                  const SizedBox(width: 10),
                  Text(isEnabled ? "Contactar al Taller" : "Teléfono del taller no disponible"),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// FAB flotante que abre WhatsApp con el taller preferido del usuario.
/// Obtiene dinámicamente el teléfono desde Firestore.
class WhatsappButtonPerfil extends StatelessWidget {
  const WhatsappButtonPerfil({super.key});

  Future<String?> _fetchWorkshopPhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final clientDoc = await FirebaseFirestore.instance
          .collection('client')
          .doc(user.uid)
          .get();
      final workshopId =
          clientDoc.data()?['preferredWorkshopId'] as String?;
      if (workshopId == null || workshopId.isEmpty) return null;
      final adminDoc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(workshopId)
          .get();
      return adminDoc.data()?['phone'] as String?;
    } catch (e) {
      debugPrint('Error obteniendo teléfono del taller: $e');
      return null;
    }
  }

  void _launchWhatsApp(BuildContext context, String rawPhone) async {
    final normalized = _normalizePhone(rawPhone);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Número de teléfono del taller no válido')),
      );
      return;
    }
    const message =
        '¡Hola! Me gustaría obtener información sobre sus servicios.';
    final encodedMessage = Uri.encodeComponent(message);
    final androidUri = Uri.parse(
        'whatsapp://send?phone=$normalized&text=$encodedMessage');
    final webUri = Uri.parse(
        'https://api.whatsapp.com/send?phone=$normalized&text=$encodedMessage');
    try {
      if (await canLaunchUrl(androidUri)) {
        await launchUrl(androidUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir WhatsApp: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _fetchWorkshopPhone(),
      builder: (context, snapshot) {
        final rawPhone = snapshot.data;
        final normalized = _normalizePhone(rawPhone);
        final bool isEnabled =
            snapshot.connectionState == ConnectionState.done &&
                normalized != null;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                isEnabled ? () => _launchWhatsApp(context, rawPhone!) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isEnabled ? const Color(0xFF25D366) : Colors.grey[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Llamar a mi taller',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
