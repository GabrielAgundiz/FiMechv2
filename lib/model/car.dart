import 'package:cloud_firestore/cloud_firestore.dart';

class Car {
  final String id;
  final String owner;
  final String plates;
  final String brand;
  final String model;
  final String year;
  final String serial;
  final String color;
  final String userId;
  final bool inService;
  final List<String> services;
  final DateTime? aceite;
  final DateTime? afinacion;
  final DateTime? bateria;
  final DateTime? clima;
  final DateTime? filtroAire;
  final DateTime? frenos;
  final DateTime? refrigerante;
  final DateTime? rotacion;
  final DateTime? transmision;

  Car({
    required this.id,
    required this.owner,
    required this.plates,
    required this.brand,
    required this.model,
    required this.year,
    required this.serial,
    required this.color,
    required this.userId,
    required this.inService,
    required this.services,
    this.aceite,
    this.afinacion,
    this.bateria,
    this.clima,
    this.filtroAire,
    this.frenos,
    this.refrigerante,
    this.rotacion,
    this.transmision,
  });

  factory Car.fromJson(String id, Map<String, dynamic> json) {
    DateTime? toDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      return null;
    }

    return Car(
      id: id,
      owner: json['owner'] as String? ?? '',
      plates: json['plates'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: json['year'] as String? ?? '',
      serial: json['serial'] as String? ?? '',
      color: json['color'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      inService: json['inService'] as bool? ?? false,
      services: List<String>.from(json['services'] as List? ?? []),
      aceite: toDate(json['aceite']),
      afinacion: toDate(json['afinacion']),
      bateria: toDate(json['bateria']),
      clima: toDate(json['clima']),
      filtroAire: toDate(json['filtroAire']),
      frenos: toDate(json['frenos']),
      refrigerante: toDate(json['refrigerante']),
      rotacion: toDate(json['rotacion']),
      transmision: toDate(json['transmision']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'owner': owner,
      'plates': plates,
      'brand': brand,
      'model': model,
      'year': year,
      'serial': serial,
      'color': color,
      'userId': userId,
      'inService': inService,
      'services': services,
      if (aceite != null) 'aceite': Timestamp.fromDate(aceite!),
      if (afinacion != null) 'afinacion': Timestamp.fromDate(afinacion!),
      if (bateria != null) 'bateria': Timestamp.fromDate(bateria!),
      if (clima != null) 'clima': Timestamp.fromDate(clima!),
      if (filtroAire != null) 'filtroAire': Timestamp.fromDate(filtroAire!),
      if (frenos != null) 'frenos': Timestamp.fromDate(frenos!),
      if (refrigerante != null)
        'refrigerante': Timestamp.fromDate(refrigerante!),
      if (rotacion != null) 'rotacion': Timestamp.fromDate(rotacion!),
      if (transmision != null) 'transmision': Timestamp.fromDate(transmision!),
    };
  }
}
