import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int _maxFirestoreStringLength = 700000;

  static CollectionReference<Map<String, dynamic>> _pestCollection(String userId) {
    return _db.collection('users').doc(userId).collection('pest_history');
  }

  static CollectionReference<Map<String, dynamic>> _diseaseCollection(String userId) {
    return _db.collection('users').doc(userId).collection('disease_history');
  }

  static CollectionReference<Map<String, dynamic>> _gardenDesignCollection(String userId) {
    return _db.collection('users').doc(userId).collection('garden_design_history');
  }

  // Save a pest detection result to history
  static Future<void> savePestResult(String userId, Map<String, dynamic> result) async {
    final data = _sanitizeForStorage(result);

    final capturedImage = data['captured_image_base64'];
    if (capturedImage is String) {
      data['captured_image_chars'] = capturedImage.length;
      if (capturedImage.length > _maxFirestoreStringLength) {
        data.remove('captured_image_base64');
        data['captured_image_stored'] = false;
      } else {
        data['captured_image_stored'] = true;
      }
    }

    data['timestamp'] = Timestamp.now();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _pestCollection(userId).add(data);
  }

  // Save a disease detection result to history
  static Future<void> saveDiseaseResult(String userId, Map<String, dynamic> result) async {
    final data = _sanitizeForStorage(result);

    final capturedImage = data['captured_image_base64'];
    if (capturedImage is String) {
      data['captured_image_chars'] = capturedImage.length;
      if (capturedImage.length > _maxFirestoreStringLength) {
        data.remove('captured_image_base64');
        data['captured_image_stored'] = false;
      } else {
        data['captured_image_stored'] = true;
      }
    }

    data['timestamp'] = Timestamp.now();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _diseaseCollection(userId).add(data);
  }

  // Save a garden design result to history
  static Future<void> saveGardenDesignResult(String userId, Map<String, dynamic> result) async {
    final data = _sanitizeForStorage(result);

    final base64Image = data['designed_image_base64'];
    if (base64Image is String) {
      data['generated_image_chars'] = base64Image.length;
      if (base64Image.length > _maxFirestoreStringLength) {
        data.remove('designed_image_base64');
        data['generated_image_stored'] = false;
      } else {
        data['generated_image_stored'] = true;
      }
    }

    data['timestamp'] = Timestamp.now();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _gardenDesignCollection(userId).add(data);
  }

  // Get all pest detection history items
  static Future<List<Map<String, dynamic>>> getHistory(String userId) async {
    final snapshot = await _pestCollection(userId).orderBy('timestamp', descending: true).get();
    return snapshot.docs.map(_mapDoc).toList();
  }

  // Get all disease detection history items
  static Future<List<Map<String, dynamic>>> getDiseaseHistory(String userId) async {
    final snapshot = await _diseaseCollection(userId).orderBy('timestamp', descending: true).get();
    return snapshot.docs.map(_mapDoc).toList();
  }

  // Get all garden design history items
  static Future<List<Map<String, dynamic>>> getGardenDesignHistory(String userId) async {
    final snapshot = await _gardenDesignCollection(userId).orderBy('timestamp', descending: true).get();
    return snapshot.docs.map(_mapDoc).toList();
  }

  // Clear all pest detection history
  static Future<void> clearHistory(String userId) async {
    final snapshot = await _pestCollection(userId).get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Clear all disease detection history
  static Future<void> clearDiseaseHistory(String userId) async {
    final snapshot = await _diseaseCollection(userId).get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Clear all garden design history
  static Future<void> clearGardenDesignHistory(String userId) async {
    final snapshot = await _gardenDesignCollection(userId).get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static Map<String, dynamic> _mapDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data());
    final ts = data['timestamp'];

    if (ts is Timestamp) {
      data['timestamp'] = ts.toDate().toIso8601String();
    } else if (ts is DateTime) {
      data['timestamp'] = ts.toIso8601String();
    } else if (ts == null) {
      data['timestamp'] = DateTime.now().toIso8601String();
    }

    data['id'] = doc.id;
    return data;
  }

  static Map<String, dynamic> _sanitizeForStorage(Map<String, dynamic> source) {
    final data = Map<String, dynamic>.from(source);
    data.remove('id');
    data.remove('timestamp');

    // Avoid storing large base64 blobs in Firestore documents.
    final overlayImage = data['overlay_image'];
    if (overlayImage is String && _looksLikeDataUri(overlayImage)) {
      data.remove('overlay_image');
    }

    return data;
  }

  static bool _looksLikeDataUri(String value) {
    return value.startsWith('data:image/') || value.length > 1000;
  }
}
