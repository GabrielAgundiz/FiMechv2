import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fimech/model/car.dart';
import 'package:fimech/services/car_service.dart';

class CarForm extends StatefulWidget {
  final Car? car; // null = add mode, non-null = edit mode
  const CarForm({super.key, this.car});

  @override
  State<CarForm> createState() => _CarFormState();
}

class _CarFormState extends State<CarForm> {
  final _formKey = GlobalKey<FormState>();
  final _platesController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _serialController = TextEditingController();

  bool _isSaving = false;

  bool get _isEditing => widget.car != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.car!;
      _brandController.text = c.brand;
      _modelController.text = c.model;
      _yearController.text = c.year;
      _colorController.text = c.color;
      _platesController.text = c.plates;
      _serialController.text = c.serial;
    }
  }

  @override
  void dispose() {
    _platesController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF3FFF8F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          _isEditing ? '¿Guardar cambios?' : '¿Registrar vehículo?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Confirma que los datos ingresados son correctos antes de guardar.',
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
              backgroundColor: Colors.green[300],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true) _saveCar();
  }

  Future<void> _saveCar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final carService = CarService();

      // Get user display name from Firestore client collection
      String ownerName = user.displayName ?? user.email ?? '';
      try {
        final clientDoc = await FirebaseFirestore.instance
            .collection('client')
            .doc(user.uid)
            .get();
        if (clientDoc.exists) {
          final data = clientDoc.data();
          ownerName = (data?['name'] as String? ?? ownerName).trim();
        }
      } catch (_) {}

      final data = {
        'owner': ownerName,
        'plates': _platesController.text.trim().toUpperCase(),
        'brand': _brandController.text.trim(),
        'model': _modelController.text.trim(),
        'year': _yearController.text.trim(),
        'serial': _serialController.text.trim().toUpperCase(),
        'color': _colorController.text.trim(),
        'userId': user.uid,
      };

      if (_isEditing) {
        await carService.updateCar(widget.car!.id, data);
      } else {
        await carService.addCar({...data, 'inService': false, 'services': []});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Vehículo actualizado correctamente.'
                : 'Vehículo registrado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocurrió un error al guardar el vehículo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xF3FFF8F2),
        title: Text(
          _isEditing ? 'Editar Vehículo' : 'Agregar Vehículo',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Información del vehículo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ingresa los datos de tu auto para registrarlo.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 28),

                _buildField(
                  controller: _brandController,
                  label: 'Marca',
                  hint: 'Ej. Toyota',
                  icon: Icons.local_car_wash_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa la marca' : null,
                ),
                const SizedBox(height: 16),

                _buildField(
                  controller: _modelController,
                  label: 'Modelo',
                  hint: 'Ej. Corolla',
                  icon: Icons.directions_car_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa el modelo' : null,
                ),
                const SizedBox(height: 16),

                _buildField(
                  controller: _yearController,
                  label: 'Año',
                  hint: 'Ej. 2022',
                  icon: Icons.calendar_today_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa el año';
                    final y = int.tryParse(v.trim());
                    if (y == null || y < 1900 || y > DateTime.now().year + 1) {
                      return 'Año no válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildField(
                  controller: _colorController,
                  label: 'Color',
                  hint: 'Ej. Blanco',
                  icon: Icons.palette_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa el color' : null,
                ),
                const SizedBox(height: 16),

                _buildField(
                  controller: _platesController,
                  label: 'Placas',
                  hint: 'Ej. ABC-1234',
                  icon: Icons.credit_card_outlined,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa las placas' : null,
                ),
                const SizedBox(height: 16),

                _buildField(
                  controller: _serialController,
                  label: 'Número de serie (VIN)',
                  hint: 'Ej. 1HGBH41JXMN109186',
                  icon: Icons.pin_outlined,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Ingresa el número de serie'
                          : null,
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _confirmAndSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[300],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditing ? 'Guardar cambios' : 'Guardar vehículo',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black38),
            prefixIcon: Icon(icon, color: Colors.green[400], size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.green[300]!, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
