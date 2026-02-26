import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:fimech/screens/user/home.dart';
import 'package:fimech/screens/user/reminders_screen.dart';
import 'package:fimech/screens/user/widgets/circularimage.dart';
import 'package:fimech/screens/user/widgets/profiledata.dart';
import 'package:fimech/screens/user/widgets/sectionheading.dart';
import 'package:fimech/screens/user/widgets/whatsappbutton.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePage2 extends StatefulWidget {
  ProfilePage2({super.key});

  @override
  _ProfilePage2State createState() => _ProfilePage2State();
}

class _ProfilePage2State extends State<ProfilePage2> {
  Map<String, dynamic>? _userData;
  // Lista de talleres disponibles (id + name + address opcional)
  List<Map<String, String>> _availableWorkshops = [];
  bool _loadingWorkshops = false;
  String? _selectedWorkshopId;
  String? _selectedWorkshopName;
  // Indica si el usuario actual es administrador (true) o no (false). Null mientras se comprueba.
  bool? _isAdminUser;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadWorkshops();
    _checkIsAdmin();
  }

  Future<void> _loadWorkshops() async {
    setState(() {
      _loadingWorkshops = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin')
          .where('isMechanic', isEqualTo: true)
          .get();
      _availableWorkshops = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': (data['workshopName'] ?? data['name'] ?? 'Taller sin nombre') as String,
          'address': (data['workshopAddress'] ?? '') as String,
        };
      }).toList();
    } catch (e) {
      // Error cargando talleres
      _availableWorkshops = [];
    } finally {
      setState(() {
        _loadingWorkshops = false;
      });
    }
  }

  // Comprueba si el usuario actual existe en la colección 'admin' (por convención, los admins se guardan ahí)
  Future<void> _checkIsAdmin() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isAdminUser = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('admin').doc(user.uid).get();
      setState(() {
        _isAdminUser = doc.exists;
      });
    } catch (e) {
      // Error comprobando rol admin
      setState(() => _isAdminUser = false);
    }
  }

  Future<void> _updatePreferredWorkshop(String? id, String? name) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('client').doc(user.uid).update({
        'preferredWorkshopId': id ?? '',
        'preferredWorkshopName': name ?? 'Ninguno',
      });
      setState(() {
        _selectedWorkshopId = id;
        _selectedWorkshopName = name;
        _userData ??= {};
        _userData!['preferredWorkshopId'] = id ?? '';
        _userData!['preferredWorkshopName'] = name ?? 'Ninguno';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferencia de taller guardada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar preferencia: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final client = FirebaseFirestore.instance
        .collection('client')
        .doc(user?.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xF3FFF8F2),
        title: const Text(
          'Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RemindersScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(
              24,
            ),
            child: Column(
              children: [
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: client,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    // Actualiza el valor de _userData con los datos del usuario
                    _userData = snapshot.data!.data();

                    // Valor para mostrar (nombre del taller preferido)
                    final String currentWorkshopName = (_userData?['preferredWorkshopName'] as String?) ?? (_selectedWorkshopName ?? 'Ninguno');

                    Widget workshopControl;
                    if (_loadingWorkshops || _isAdminUser == null) {
                      // Mostrar el valor en un ProfileData mientras se resuelve la carga/rol
                      workshopControl = ProfileData(
                        title: 'Taller preferido',
                        value: _loadingWorkshops ? 'Cargando...' : currentWorkshopName,
                        onPressed: () {},
                        icon: Icons.hourglass_top,
                      );
                    } else if (_isAdminUser == true) {
                      // Admin: mostrar en lectura (no permitir cambios)
                      workshopControl = ProfileData(
                        title: 'Taller preferido',
                        value: currentWorkshopName,
                        onPressed: () {}, // inactivo para admins
                        icon: Icons.lock,
                      );
                    } else {
                      // Usuario normal: mostrar ProfileData que abre un modal para cambiar
                      workshopControl = ProfileData(
                        title: 'Taller preferido',
                        value: currentWorkshopName,
                        onPressed: () async {
                          await _showSelectPreferredWorkshop();
                        },
                        icon: Icons.edit,
                      );
                    }

                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              CircularImage(
                                image: _userData?['image'] ??
                                    'https://img.freepik.com/vector-premium/perfil-hombre-dibujos-animados_18591-58483.jpg',
                                width: 140,
                                height: 140,
                              ),
                               /*TextButton(
                                onPressed: () async {
                                  await _pickAndUploadImage();
                                },
                                child: _uploadingPhoto
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(
                                        'Cambiar foto de perfil',
                                        style: TextStyle(color: Colors.green[400]),
                                      ),
                              ),*/
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        const Divider(),
                        const SizedBox(
                          height: 16,
                        ),
                        const SectionHeading(
                          title: "Informacion de Usuario",
                          showActionButton: false,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        ProfileData(
                          title: 'Nombre',
                          value: _userData?['name'] ?? 'N/A',
                          onPressed: () async {
                            String? newName;
                            await showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  backgroundColor: const Color(0xF2FFF3FF),
                                   title: const Text('Editar nombre'),
                                   content: TextField(
                                     onChanged: (value) {
                                       newName = value;
                                     },
                                     decoration: const InputDecoration(
                                         hintText: 'Nombre'),

                                   ),
                                   actions: [
                                     TextButton(
                                       onPressed: () => Navigator.pop(context),
                                       child: const Text('Cancelar', style: TextStyle( color: Colors.red)),
                                     ),
                                     TextButton(
                                       onPressed: () async {
                                        if (newName?.trim().isEmpty ?? true) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Ingrese un nombre válido')),
                                          );
                                          return;
                                        }
                                        if (newName != _userData?['name']) {
                                          await FirebaseFirestore.instance
                                              .collection('client')
                                              .doc(user?.uid)
                                              .update({'name': newName});
                                          setState(() {
                                            _userData!['name'] = newName;
                                          });
                                        }
                                        Navigator.pop(context);
                                       },
                                       child: Text('Guardar', style: TextStyle(color: Colors.green[600]),),
                                     ),
                                   ],
                                 );
                               },
                             );
                           },
                         ),

                        const SizedBox(
                          height: 8,
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              const SizedBox(height: 6),
                              workshopControl,
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        const Divider(),
                        const SectionHeading(
                          title: "Informacion Personal",
                          showActionButton: false,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        ProfileData(
                            title: 'E-mail:',
                            value: _userData?['email'] ?? 'N/A',
                            icon: Icons.copy,

                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                  text: _userData?['email'] ?? 'N/A'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Los datos se han copiado'),
                                ),
                              );
                            }),
                        ProfileData(
                          title: 'Telefono',
                          value: _userData?['phone'] ?? 'N/A',
                          onPressed: () async {
                            String? newPhone;
                            await showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  backgroundColor: const Color(0xF2FFF3FF),
                                  title: const Text('Editar telefono'),
                                  content: TextField(
                                    onChanged: (value) {
                                      newPhone = value;
                                    },
                                    decoration: const InputDecoration(
                                        hintText: 'Telefono'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancelar', style: TextStyle( color: Colors.red)),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        if (newPhone?.trim().isEmpty ?? true) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Ingrese un teléfono válido')),
                                          );
                                          return;
                                        }
                                        if (newPhone != _userData?['phone']) {
                                          await FirebaseFirestore.instance
                                              .collection('client')
                                              .doc(user?.uid)
                                              .update({'phone': newPhone});
                                          setState(() {
                                            _userData!['phone'] = newPhone;
                                          });
                                        }
                                        Navigator.pop(context);
                                      },
                                      child: Text('Guardar', style: TextStyle(color: Colors.green[600]),),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        ProfileData(
                          title: 'Direccion',
                          value: _userData?['address'] ?? 'N/A',
                          onPressed: () async {
                            String? newAddress;
                            await showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  backgroundColor: const Color(0xF2FFF3FF),
                                  title: const Text('Editar direccion'),
                                  content: TextField(
                                    onChanged: (value) {
                                      newAddress = value;
                                    },
                                    decoration: const InputDecoration(
                                        hintText: 'Direccion'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancelar', style: TextStyle( color: Colors.red)),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        if (newAddress?.trim().isEmpty ?? true) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Ingrese una dirección válida')),
                                          );
                                          return;
                                        }
                                        if (newAddress != _userData?['address']) {
                                          await FirebaseFirestore.instance
                                              .collection('client')
                                              .doc(user?.uid)
                                              .update({'address': newAddress});
                                          setState(() {
                                            _userData!['address'] = newAddress;
                                          });
                                        }
                                        Navigator.pop(context);
                                      },
                                      child: Text('Guardar', style: TextStyle(color: Colors.green[600]),),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: const WhatsappButtonPerfil(),
      ),
    );
  }

  // Muestra modal con la lista de talleres para seleccionar el preferido
  Future<void> _showSelectPreferredWorkshop() async {
    // Asegurarse de que la lista de talleres está cargada
    if (_availableWorkshops.isEmpty && !_loadingWorkshops) {
      await _loadWorkshops();
    }

    if (_loadingWorkshops) {
      // Si sigue cargando, esperar un poco o mostrar indicador
      return showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          backgroundColor: Color(0xF2FFF3FF),
          content: SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
        ),
      );
    }

    await showModalBottomSheet(
      context: context,
     backgroundColor: const Color(0xF3FFF8F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        if (_availableWorkshops.isEmpty) {
          return const SizedBox(height: 200, child: Center(child: Text('No hay talleres disponibles')));
        }
        return SizedBox(
          height: 400,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            children: [
              ListTile(
                title: const Text('Ninguno'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _updatePreferredWorkshop('', 'Ninguno');
                },
              ),
              const Divider(),
              ..._availableWorkshops.map((w) => ListTile(
                    title: Text(w['name'] ?? 'Taller'),
                    subtitle: (w['address'] ?? '').isNotEmpty ? Text(w['address'] ?? '') : null,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _updatePreferredWorkshop(w['id'], w['name']);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (pickedFile == null) return;

      setState(() {
        _uploadingPhoto = true;
      });

      final File file = File(pickedFile.path);
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _uploadingPhoto = false);
        return;
      }

      final String storagePath = 'user_photos/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(storagePath);

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Guardar URL en Firestore en el documento del cliente
      await FirebaseFirestore.instance.collection('client').doc(user.uid).update({
        'image': downloadUrl,
      });

      setState(() {
        _userData ??= {};
        _userData!['image'] = downloadUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto de perfil actualizada')));
    } catch (e) {
      debugPrint('Error subiendo foto: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir la foto: $e')));
    } finally {
      setState(() {
        _uploadingPhoto = false;
      });
    }
  }
}
