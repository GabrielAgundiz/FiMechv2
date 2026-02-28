import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fimech/model/car.dart';
import 'package:fimech/screens/user/car_form.dart';
import 'package:fimech/services/car_service.dart';
import 'package:fimech/router.dart';

class CarsPage extends StatefulWidget {
  const CarsPage({super.key});

  @override
  State<CarsPage> createState() => _CarsPageState();
}

class _CarsPageState extends State<CarsPage> with RouteAware {
  late Future<List<Car>> _carsFuture;
  final _carService = CarService();

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    _loadCars();
  }

  @override
  void didPopNext() {
    _loadCars();
  }

  void _loadCars() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    setState(() {
      _carsFuture = _carService.getUserCars(userId);
    });
  }

  Future<void> _onEdit(Car car) async {
    final result = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(builder: (context) => CarForm(car: car)),
    );
    if (result == true) _loadCars();
  }

  Future<void> _onDelete(Car car) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF3FFF8F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '¿Eliminar vehículo?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Se eliminará "${car.brand} ${car.model} (${car.plates})" de forma permanente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.black54),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _carService.deleteCar(car.id);
      _loadCars();
    }
  }

  Future<void> _onTransfer(Car car) async {
    final transferred = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TransferCarDialog(car: car, carService: _carService),
    );
    if (transferred == true) _loadCars();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xF3FFF8F2),
        title: const Text(
          'Mis Autos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Text(
                  'Vehículos',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<List<Car>>(
                future: _carsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: CircularProgressIndicator(
                          color: Colors.green,
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Text('Error al cargar los vehículos.'),
                      ),
                    );
                  }
                  final cars = snapshot.data ?? [];
                  if (cars.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_car_outlined,
                              size: 64,
                              color: Colors.black26,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No tienes vehículos registrados.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black45,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Agrega uno con el botón +',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: cars.map((car) => _CarCard(
                      car: car,
                      onEdit: () => _onEdit(car),
                      onDelete: () => _onDelete(car),
                      onTransfer: () => _onTransfer(car),
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          backgroundColor: Colors.green[300],
          onPressed: () async {
            final result = await Navigator.push<bool?>(
              context,
              MaterialPageRoute(
                builder: (context) => const CarForm(),
              ),
            );
            if (result == true) {
              _loadCars();
            }
          },
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }
}

class _CarCard extends StatelessWidget {
  final Car car;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTransfer;

  const _CarCard({
    required this.car,
    required this.onEdit,
    required this.onDelete,
    required this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
                  child: Icon(
                    Icons.directions_car,
                    color: Colors.green[400],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${car.brand} ${car.model}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        car.year,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                    if (value == 'transfer') onTransfer();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Colors.black54),
                          SizedBox(width: 10),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'transfer',
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, size: 18, color: Colors.black54),
                          SizedBox(width: 10),
                          Text('Transferir'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
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

// ─── Transfer Dialog ─────────────────────────────────────────────────────────

class _TransferCarDialog extends StatefulWidget {
  final Car car;
  final CarService carService;

  const _TransferCarDialog({required this.car, required this.carService});

  @override
  State<_TransferCarDialog> createState() => _TransferCarDialogState();
}

class _TransferCarDialogState extends State<_TransferCarDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSearching = false;
  bool _isTransferring = false;

  // Non-null once a valid user is found
  String? _foundUserId;
  String? _foundUserName;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSearching = true;
      _foundUserId = null;
      _foundUserName = null;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final snapshot = await FirebaseFirestore.instance
          .collection('client')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => _errorMessage = 'Este correo no está registrado en la app.');
        return;
      }

      final doc = snapshot.docs.first;
      if (doc.id == currentUid) {
        setState(() => _errorMessage = 'No puedes transferirte el vehículo a ti mismo.');
        return;
      }

      final data = doc.data();
      final name = (data['name'] as String?)?.trim() ??
          (data['email'] as String?) ??
          'Usuario';

      setState(() {
        _foundUserId = doc.id;
        _foundUserName = name;
      });
    } catch (_) {
      setState(() => _errorMessage = 'Ocurrió un error al buscar el usuario.');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _confirmTransfer() async {
    if (_foundUserId == null) return;
    setState(() => _isTransferring = true);
    try {
      await widget.carService.transferCar(
        widget.car.id,
        _foundUserId!,
        _foundUserName!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
          _errorMessage = 'Ocurrió un error al transferir el vehículo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xF3FFF8F2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Transferir vehículo',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Car summary
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_car, color: Colors.green[400], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.car.brand} ${widget.car.model} · ${widget.car.plates}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Correo del nuevo dueño:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'correo@ejemplo.com',
                  hintStyle: const TextStyle(color: Colors.black38),
                  prefixIcon: Icon(Icons.email_outlined, color: Colors.green[400], size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.green[300]!, width: 1.5)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa un correo';
                  final emailRegex = RegExp(r'^[\w\-.]+@[\w\-]+\.[a-zA-Z]{2,}$');
                  if (!emailRegex.hasMatch(v.trim())) return 'Correo no válido';
                  return null;
                },
                onChanged: (_) => setState(() {
                  _foundUserId = null;
                  _foundUserName = null;
                  _errorMessage = null;
                }),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],

              // Found user confirmation card
              if (_foundUserId != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, color: Colors.blue[600], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nuevo dueño encontrado:',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                            Text(
                              _foundUserName!,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTransferring ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: Colors.black54),
          child: const Text('Cancelar'),
        ),
        if (_foundUserId == null)
          ElevatedButton(
            onPressed: _isSearching ? null : _searchUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[300],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: _isSearching
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Buscar'),
          )
        else
          ElevatedButton(
            onPressed: _isTransferring ? null : _confirmTransfer,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: _isTransferring
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Confirmar transferencia'),
          ),
      ],
    );
  }
}

// ─── Info Item ────────────────────────────────────────────────────────────────

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

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
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        ),
      ],
    );
  }
}
