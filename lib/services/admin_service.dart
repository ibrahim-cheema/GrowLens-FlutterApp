import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> streamUsers() {
    return _db
        .collection('users')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_mapDoc).toList());
  }

  Future<void> updateUserRole(String userId, String role) async {
    await _db.collection('users').doc(userId).set({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setUserActive(String userId, bool isActive) async {
    await _db.collection('users').doc(userId).set({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getModelPerformanceSummary() async {
    final diseaseSnapshot = await _db.collectionGroup('disease_history').get();
    final pestSnapshot = await _db.collectionGroup('pest_history').get();
    final retrainPendingSnapshot = await _db
        .collection('model_retrain_jobs')
        .where('status', isEqualTo: 'requested')
        .get();

    final diseaseConfidence = _averageConfidence(diseaseSnapshot.docs);
    final pestConfidence = _averageConfidence(pestSnapshot.docs);

    return {
      'diseasePredictions': diseaseSnapshot.docs.length,
      'pestPredictions': pestSnapshot.docs.length,
      'avgDiseaseConfidence': diseaseConfidence,
      'avgPestConfidence': pestConfidence,
      'retrainRequested': retrainPendingSnapshot.docs.length,
    };
  }

  Future<void> requestRetrain({
    required String requestedByUid,
    required String requestedByEmail,
    required String modelType,
    required String reason,
  }) async {
    await _db.collection('model_retrain_jobs').add({
      'requestedByUid': requestedByUid,
      'requestedByEmail': requestedByEmail,
      'modelType': modelType,
      'reason': reason,
      'status': 'requested',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamRetrainJobs() {
    return _db
        .collection('model_retrain_jobs')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_mapDoc).toList());
  }

  Future<void> updateRetrainJobStatus(String jobId, String status) async {
    await _db.collection('model_retrain_jobs').doc(jobId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamDatasetEntries() {
    return _db
        .collection('dataset_entries')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_mapDoc).toList());
  }

  Future<void> addDatasetEntry({
    required String plant,
    required String disease,
    required String imageUrl,
    required String treatment,
    required String prevention,
    required String createdByUid,
  }) async {
    await _db.collection('dataset_entries').add({
      'plant': plant,
      'disease': disease,
      'imageUrl': imageUrl,
      'treatment': treatment,
      'prevention': prevention,
      'createdByUid': createdByUid,
      'isValidated': false,
      'validationNote': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> validateDatasetEntry({
    required String entryId,
    required bool isValidated,
    String? validationNote,
  }) async {
    await _db.collection('dataset_entries').doc(entryId).update({
      'isValidated': isValidated,
      'validationNote': validationNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDatasetEntry(String entryId) async {
    await _db.collection('dataset_entries').doc(entryId).delete();
  }

  Stream<List<Map<String, dynamic>>> streamTreatmentRules() {
    return _db
        .collection('treatment_rules')
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_mapDoc).toList());
  }

  Future<void> upsertTreatmentRule({
    String? ruleId,
    required String plant,
    required String disease,
    required String treatment,
    required String prevention,
  }) async {
    final data = {
      'plant': plant,
      'disease': disease,
      'treatment': treatment,
      'prevention': prevention,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (ruleId == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('treatment_rules').add(data);
      return;
    }

    await _db.collection('treatment_rules').doc(ruleId).set(
      data,
      SetOptions(merge: true),
    );
  }

  Future<void> deleteTreatmentRule(String ruleId) async {
    await _db.collection('treatment_rules').doc(ruleId).delete();
  }

  double _averageConfidence(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return 0;
    double sum = 0;
    int count = 0;

    for (final doc in docs) {
      final val = doc.data()['confidence'];
      final parsed = _parseConfidence(val);
      if (parsed != null) {
        sum += parsed;
        count++;
      }
    }
    if (count == 0) return 0;
    return sum / count;
  }

  double? _parseConfidence(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll('%', '').trim();
      return double.tryParse(normalized);
    }
    return null;
  }

  Map<String, dynamic> _mapDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data());
    data['id'] = doc.id;
    return data;
  }
}
