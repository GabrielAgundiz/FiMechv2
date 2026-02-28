import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fimech/model/car.dart';

class CarService {
  final _carsRef = FirebaseFirestore.instance.collection('cars');

  static const Map<String, String> serviceToCar = {
    'Cambio de aceite': 'aceite',
    'Rotación de llantas': 'rotacion',
    'Revisión de frenos': 'frenos',
    'Cambio de batería': 'bateria',
    'Cambio de filtro de aire': 'filtroAire',
    'Afinación general': 'afinacion',
    'Servicio de transmisión': 'transmision',
    'Cambio de líquido refrigerante': 'refrigerante',
    'Alineación y balanceo': 'alineacion',
    'Servicio de aire acondicionado': 'clima',
  };

  Future<void> updateCarServiceDate(String carId, String serviceField, DateTime date) async {
    await _carsRef.doc(carId).update({serviceField: Timestamp.fromDate(date)});
  }

  Future<List<Car>> getUserCars(String userId) async {
    final result = await _carsRef.where('userId', isEqualTo: userId).get();
    return result.docs
        .map((doc) => Car.fromJson(doc.id, doc.data()))
        .toList();
  }

  Future<void> addCar(Map<String, dynamic> data) async {
    await _carsRef.add(data);
  }

  Future<void> updateCar(String id, Map<String, dynamic> data) async {
    await _carsRef.doc(id).update(data);
  }

  Future<void> deleteCar(String id) async {
    await _carsRef.doc(id).delete();
  }

  Future<void> transferCar(String carId, String newUserId, String newOwnerName) async {
    await _carsRef.doc(carId).update({
      'userId': newUserId,
      'owner': newOwnerName,
    });
  }
}
