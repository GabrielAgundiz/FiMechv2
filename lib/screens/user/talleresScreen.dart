// Ignore lint: file name is not lower_case_with_underscores
// ignore_for_file: file_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fimech/screens/user/citeform.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class TalleresScreen extends StatefulWidget {
  const TalleresScreen({super.key});
  @override
  State<TalleresScreen> createState() => _TalleresScreenState();
}

class _TalleresScreenState extends State<TalleresScreen> {
  final Map<String, String?> _urlCache = {}; // cache docId/raw -> resolved URL or null
  final Map<String, Uint8List?> _bytesCache = {}; // cache url -> bytes or null

  // Try a set of likely keys in the workshop document to find a phone/whatsapp number.
  String? _extractPhone(Map<String, dynamic> data) {
    final candidates = [
      'whatsapp',
      'workshopPhone',
      'phone',
      'phoneNumber',
      'telefono',
      'mobile',
      'contact',
      'celular',
    ];
    for (final k in candidates) {
      if (data.containsKey(k)) {
        final v = data[k];
        if (v is String && v.trim().isNotEmpty) return _sanitizePhone(v);
        if (v is num) return _sanitizePhone(v.toString());
      }
    }
    return null;
  }

  // Remove spaces, parentheses, dashes; keep leading + if present (WhatsApp accepts international format without + too).
  String _sanitizePhone(String raw) {
    var s = raw.trim();
    // Remove common separators
    s = s.replaceAll(RegExp(r'[\s\-()\\]'), '');
    // If starts with +, remove + because wa.me expects no plus; keep digits and plus only
    if (s.startsWith('+')) s = s.replaceFirst('+', '');
    return s;
  }

  Future<void> _openWhatsApp(String phone, {String? text}) async {
    try {
      final encodedText = (text ?? '').isNotEmpty ? '&text=${Uri.encodeComponent(text!)}' : '';
      final uri1 = Uri.parse('https://wa.me/$phone$encodedText');
      if (await canLaunchUrl(uri1)) {
        await launchUrl(uri1, mode: LaunchMode.externalApplication);
        return;
      }
      // fallback to api.whatsapp.com
      final uri2 = Uri.parse('https://api.whatsapp.com/send?phone=$phone$encodedText');
      if (await canLaunchUrl(uri2)) {
        await launchUrl(uri2, mode: LaunchMode.externalApplication);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.')));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.')));
    }
  }

  Future<String?> _resolveImageUrl(dynamic raw, String docId) async {
    try {
      final key = '$docId::${raw ?? ''}';
      if (_urlCache.containsKey(key)) return _urlCache[key];

      if (raw == null) {
        _urlCache[key] = null;
        return null;
      }
      if (raw is String && raw.trim().isNotEmpty) {
        final s = raw.trim();
        if (s.startsWith('http')) {
          // Probar variantes de la URL remota para evitar 404 (https/http, www, encoding)
          final List<String> candidates = [];
          candidates.add(s);
          // Force https/http variants
          if (s.startsWith('https://')) candidates.add(s.replaceFirst('https://', 'http://'));
          if (s.startsWith('http://')) candidates.add(s.replaceFirst('http://', 'https://'));
          // Add www variant if missing
          try {
            final uri = Uri.parse(s);
            final host = uri.host;
            if (!host.startsWith('www.')) {
              final withWww = uri.replace(host: 'www.$host').toString();
              candidates.add(withWww);
            }
            if (host.startsWith('www.')) {
              final withoutWww = uri.replace(host: host.replaceFirst('www.', '')).toString();
              candidates.add(withoutWww);
            }
            // Encoded path
            final encoded = Uri.encodeFull(s);
            if (encoded != s) candidates.add(encoded);
          } catch (_) {}

          for (final cand in candidates) {
            try {
              final head = await http.head(Uri.parse(cand)).timeout(const Duration(seconds: 6));
              if (head.statusCode >= 200 && head.statusCode < 400) {
                _urlCache[key] = cand;
                // Persistir la variante válida si es distinta de la original
                if (cand != s) {
                  try {
                    await FirebaseFirestore.instance.collection('admin').doc(docId).update({'workshopImageUrl': cand});
                  } catch (_) {}
                }
                return cand;
              }
              final get = await http.get(Uri.parse(cand)).timeout(const Duration(seconds: 6));
              if (get.statusCode >= 200 && get.statusCode < 400) {
                _urlCache[key] = cand;
                if (cand != s) {
                  try {
                    await FirebaseFirestore.instance.collection('admin').doc(docId).update({'workshopImageUrl': cand});
                  } catch (_) {}
                }
                return cand;
              }
            } catch (_) {
              // ignore and try next candidate
            }
          }
          // Si todas las variantes fallaron, limpiar el campo en Firestore para evitar futuros 404
          try {
            await FirebaseFirestore.instance.collection('admin').doc(docId).update({'workshopImageUrl': FieldValue.delete()});
          } catch (_) {}
          _urlCache[key] = null;
          return null;
        }
        // Si no es URL HTTP, tratar como ruta de Firebase Storage
        try {
          final ref = FirebaseStorage.instance.ref().child(s);
          final url = await ref.getDownloadURL();
          // Si obtuvimos un downloadURL válido, persistirlo en Firestore para este taller
          try {
            await FirebaseFirestore.instance.collection('admin').doc(docId).update({'workshopImageUrl': url});
          } catch (_) {}
          // verificar url
          try {
            final head = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 6));
            if (head.statusCode >= 200 && head.statusCode < 400) {
              _urlCache[key] = url;
              return url;
            }
            final get = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
            if (get.statusCode >= 200 && get.statusCode < 400) {
              _urlCache[key] = url;
              return url;
            }
            _urlCache[key] = null;
            return null;
          } catch (_) {
            _urlCache[key] = null;
            return null;
          }
        } catch (_) {
          _urlCache[key] = null;
          return null;
        }
      }
      _urlCache[key] = null;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _fetchImageBytes(String url) async {
    try {
      if (_bytesCache.containsKey(url)) return _bytesCache[url];
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (resp.statusCode >= 200 && resp.statusCode < 400) {
        _bytesCache[url] = resp.bodyBytes;
        return resp.bodyBytes;
      }
      _bytesCache[url] = null;
      return null;
    } catch (_) {
      _bytesCache[url] = null;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xF3FFF8F2),
        title: const Text('Talleres', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admin')
            .where('isMechanic', isEqualTo: true)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Algo salió mal'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay talleres registrados aún.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 5,
              childAspectRatio: 0.55,
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot document = snapshot.data!.docs[index];
              Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: Colors.grey[200],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 2,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15),
                        ),
                        child: FutureBuilder<String?>(
                          future: _resolveImageUrl(data['workshopImageUrl'], document.id),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            }
                            final imageUrl = snap.data;
                            if (imageUrl == null || imageUrl.isEmpty) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Center(child: Icon(Icons.store, size: 30)),
                              );
                            }
                            // Descargar bytes y mostrar con Image.memory para controlar fallos HTTP
                            return FutureBuilder<Uint8List?>(
                              future: _fetchImageBytes(imageUrl),
                              builder: (context, bsnap) {
                                if (bsnap.connectionState == ConnectionState.waiting) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Center(child: CircularProgressIndicator()),
                                  );
                                }
                                final bytes = bsnap.data;
                                if (bytes == null || bytes.isEmpty) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Center(child: Icon(Icons.store, size: 30)),
                                  );
                                }
                                return Image.memory(bytes, fit: BoxFit.cover);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            data['workshopName'] ?? 'Nombre no disponible',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  data['workshopAddress'] ?? 'Dirección no disponible',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dueño: ${data['name'] ?? 'Dueño no disponible'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                          ),
                          // Action buttons: Agendar (open form) and Llamar (open WhatsApp)
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CiteForm(
                                      workshopData: {...data, 'id': document.id},
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[300],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text('Agendar', style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final phone = _extractPhone(data);
                                if (phone == null || phone.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Número de WhatsApp no disponible para este taller.')));
                                  return;
                                }
                                await _openWhatsApp(phone);
                              },
                              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
                              label: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text('Llamar', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366), // WhatsApp green
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
