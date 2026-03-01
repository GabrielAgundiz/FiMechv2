import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fimech/model/car.dart';

class CarService {
  final _carsRef = FirebaseFirestore.instance.collection('cars');
  final _transfersRef = FirebaseFirestore.instance.collection('car_transfers');
  final _alertsRef = FirebaseFirestore.instance.collection('user_alerts');

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

  /// Creates a pending transfer request that the recipient must confirm.
  Future<void> createPendingTransfer({
    required String carId,
    required String carBrand,
    required String carModel,
    required String carPlates,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
    required String toUserName,
  }) async {
    await _transfersRef.add({
      'carId': carId,
      'carBrand': carBrand,
      'carModel': carModel,
      'carPlates': carPlates,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns all pending transfers addressed to [userId].
  Future<List<Map<String, dynamic>>> getPendingTransfersForUser(String userId) async {
    final snapshot = await _transfersRef
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.map((doc) {
      return <String, dynamic>{'id': doc.id, ...doc.data()};
    }).toList();
  }

  /// Atomically: updates car ownership, re-links all citas, deletes the transfer doc.
  Future<void> confirmTransfer(
    String transferId,
    String carId,
    String toUserId,
    String toUserName,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_carsRef.doc(carId), {'userId': toUserId, 'owner': toUserName});

    final citas = await FirebaseFirestore.instance
        .collection('citas')
        .where('carId', isEqualTo: carId)
        .get();
    for (final doc in citas.docs) {
      batch.update(doc.reference, {'userId': toUserId});
    }

    batch.delete(_transfersRef.doc(transferId));
    await batch.commit();
  }

  /// Cancels a pending transfer and leaves an in-app alert for the original owner.
  Future<void> cancelTransfer(
    String transferId,
    String fromUserId,
    String carBrand,
    String carModel,
    String toUserName,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_transfersRef.doc(transferId));
    batch.set(_alertsRef.doc(), {
      'userId': fromUserId,
      'title': 'Transferencia cancelada',
      'message':
          '$toUserName rechazó la transferencia de $carBrand $carModel. '
          'El vehículo permanece en tu cuenta.',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Returns unread in-app alerts for [userId].
  Future<List<Map<String, dynamic>>> getUnreadAlerts(String userId) async {
    final snapshot = await _alertsRef
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    return snapshot.docs.map((doc) {
      return <String, dynamic>{'id': doc.id, ...doc.data()};
    }).toList();
  }

  Future<void> markAlertRead(String alertId) async {
    await _alertsRef.doc(alertId).update({'read': true});
  }
}
