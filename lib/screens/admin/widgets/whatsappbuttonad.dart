import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Helper para normalizar el teléfono a formato internacional sin '+'
String? _normalizePhone(String? phone) {
  if (phone == null) return null;
  // Eliminar todo lo que no sea dígito
  String digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  // Si son 10 dígitos (ej. 8112345678) asumimos México y agregamos 52
  if (digits.length == 10) {
    digits = '52$digits';
  }
  // Si comienza con 0 y 11 dígitos, eliminamos el 0
  if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  // Si tiene un + al inicio (se eliminó antes), o ya tiene código de país, lo devolvemos tal cual
  // Finalmente aceptamos si tiene al menos 11 dígitos (ej: 521234567890)
  if (digits.length < 11) return null;
  return digits;
}

class WhatsappButtonAD extends StatelessWidget {
  final String idCita;
  final String nombre;
  final String phone;
  const WhatsappButtonAD(this.idCita, this.nombre, this.phone, {super.key});

  void launchWhatsapp({required String number, required String message}) async {
    try {
      final encodedMessage = Uri.encodeComponent(message);
      final String androidUrl = "whatsapp://send?phone=$number&text=$encodedMessage";
      final Uri androidUri = Uri.parse(androidUrl);

      final String webUrl = "https://api.whatsapp.com/send?phone=$number&text=$encodedMessage";
      final Uri webUri = Uri.parse(webUrl);

      if (await canLaunchUrl(androidUri)) {
        await launchUrl(androidUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // En caso de fallo al lanzar, mostrar en consola (el caller puede mostrar un snackbar si desea)
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Normalizar el número recibido
    final String? normalized = _normalizePhone(phone);
    final bool isEnabled = normalized != null;
    final String message = "Hola, soy mecanico dentro del taller MechanicTracking. Tengo una consulta sobre su auto: $nombre";

    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: isEnabled
              ? () {
                  launchWhatsapp(number: normalized, message: message);
                }
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
              Text(isEnabled ? "Iniciar chat con el Usuario" : "Teléfono no disponible"),
            ],
          ),
        ),
      ),
    );
  }
}

class WhatsappButtonPerfil extends StatelessWidget {
  const WhatsappButtonPerfil({super.key});

  void launchWhatsapp({required String number, required String message}) async {
    final String androidUrl = "whatsapp://send?phone=$number&text=$message";
    final Uri androidUri = Uri.parse(androidUrl);

    final String webUrl = "https://api.whatsapp.com/send/?phone=$number&text=$message";
    final Uri webUri = Uri.parse(webUrl);

    if (await canLaunchUrl(androidUri)) {
      await launchUrl(androidUri);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: () {
            // Aquí podríamos usar el teléfono del perfil del usuario; por ahora sigue estático
            launchWhatsapp(number: '8110745230', message: "Hola");
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(FontAwesomeIcons.whatsapp),
              SizedBox(width: 10),
              Text("Iniciar chat con el Usuario"),
            ],
          ),
        ),
      ),
    );
  }
}
