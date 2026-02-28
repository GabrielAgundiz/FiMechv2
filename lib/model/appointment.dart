import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final String auto;
  final DateTime date;
  final String motivo;
  final String status;
  final DateTime dateUpdate;
  final String costo;
  final String descriptionService;
  final String status2;
  final String progreso2;
  final String reason2;
  final String userId;
  final String idMecanico;
  final String workshopName;
  final String workshopAddress;
  final String carId;

  Appointment(
      this.id,
      this.auto,
      this.date,
      this.motivo,
      this.status,
      this.dateUpdate,
      this.costo,
      this.descriptionService,
      this.status2,
      this.progreso2,
      this.reason2,
      this.userId,
      this.idMecanico,
      this.workshopName,
      this.workshopAddress,
      this.carId);

  factory Appointment.fromJson(String id, Map<String, dynamic> json) {
    return Appointment(
      id,
      json['automovil'] as String,
      (json['date'] as Timestamp).toDate(),
      json['motivo'] as String,
      json['status'] as String,
      (json['date_update'] as Timestamp).toDate(),
      json['costo'] as String,
      json['descriptionService'] as String,
      json['status2'] as String,
      json['progreso2'] as String,
      json['reason2'] as String,
      json['userId'] as String,
      json['idMecanico'] as String,
      json['workshopName'] as String,
      json['workshopAddress'] as String,
      (json['carId'] as String?) ?? '',
    );
  }
  toJson() {
    return {
      'id': id,
      'automovil': auto,
      'date': date.toIso8601String(),
      'motivo': motivo,
      'status': status,
    };
  }
}

class Diagnostico {
  final String id;
  final DateTime dateUpdate;
  final String costo;
  final String descriptionService;
  final String status2;
  final String progreso2;
  final String reason2;

  Diagnostico(this.id, this.dateUpdate, this.costo, this.descriptionService,
      this.status2, this.progreso2, this.reason2);

  factory Diagnostico.fromJson(String id, Map<String, dynamic> json) {
    return Diagnostico(
      id,
      (json['date_update'] as Timestamp).toDate(),
      json['costo'] as String,
      json['descriptionService'] as String,
      json['status2'] as String,
      json['progreso2'] as String,
      json['reason2'] as String,
    );
  }
  toJson() {
    return {
      'id': id,
      'date': dateUpdate.toIso8601String(),
      'descriptionService': descriptionService,
      'status2': status2,
      'progreso2': progreso2,
      'reason2': reason2,
    };
  }
}
