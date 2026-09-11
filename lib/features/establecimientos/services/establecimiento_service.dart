import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/establecimiento_model.dart';

class EstablecimientoService {
  EstablecimientoService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _establecimientos {
    return _firestore.collection('establecimientos');
  }

  Future<void> crear(EstablecimientoModel establecimiento) {
    return _establecimientos
        .doc(establecimiento.id)
        .set(establecimiento.toFirestoreParaCrear());
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> obtenerPorId(
    String establecimientoId,
  ) {
    return _establecimientos.doc(establecimientoId).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> observarPorId(
    String establecimientoId,
  ) {
    return _establecimientos.doc(establecimientoId).snapshots();
  }
}
