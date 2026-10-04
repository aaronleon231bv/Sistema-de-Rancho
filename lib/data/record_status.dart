import 'ranch_store.dart';

String practiceStatus(RanchRecord record, {DateTime? today}) {
  final status = record.fields['status'] as String? ?? 'Realizada';
  if (status != 'Pendiente') return status;
  final date = DateTime.tryParse(record.fields['date'] as String? ?? '');
  final now = today ?? DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  return date != null && date.isBefore(day) ? 'Vencida' : 'Pendiente';
}

String observationStatus(RanchRecord record) =>
    record.fields['status'] as String? ?? 'Abierta';
