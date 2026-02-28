import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fimech/model/car.dart';

class CarService {
  final _carsRef = FirebaseFirestore.instance.collection('cars');

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
