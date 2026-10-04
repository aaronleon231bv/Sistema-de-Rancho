import 'dart:typed_data';

import 'ranch_store.dart';
import 'record_status.dart';
import 'report_exporters.dart' deferred as exporters;

const recordLabels = {
  RecordKind.parcel: 'Parcela',
  RecordKind.crop: 'Cultivo',
  RecordKind.practice: 'Práctica',
  RecordKind.observation: 'Observación',
};

double numberField(RanchRecord r, String key) =>
    (r.fields[key] as num?)?.toDouble() ?? 0;

double practiceCost(RanchRecord r) =>
    numberField(r, 'inputCost') +
    numberField(r, 'laborHours') * numberField(r, 'hourlyCost') +
    numberField(r, 'otherCost');

double harvestYield(RanchRecord r) => numberField(r, 'harvestArea') > 0
    ? numberField(r, 'harvestKg') / numberField(r, 'harvestArea')
    : 0;

List<RanchRecord> filterHistory(
  List<RanchRecord> records, {
  String? parcelId,
  String? cropId,
  String? responsible,
  DateTime? from,
  DateTime? to,
}) {
  final result = records.where((r) {
    if (parcelId != null &&
        r.id != parcelId &&
        r.fields['parcelId'] != parcelId) {
      return false;
    }
    if (cropId != null && r.id != cropId && r.fields['cropId'] != cropId) {
      return false;
    }
    if (responsible != null && r.fields['responsible'] != responsible) {
      return false;
    }
    if (from != null || to != null) {
      final day = DateTime.tryParse(r.fields['date'] as String? ?? '');
      if (day == null ||
          (from != null && day.isBefore(from)) ||
          (to != null && day.isAfter(to))) {
        return false;
      }
    }
    return true;
  }).toList();
  result.sort(
    (a, b) => (a.fields['date'] as String? ?? '').compareTo(
      b.fields['date'] as String? ?? '',
    ),
  );
  return result;
}

String relatedTitle(List<RanchRecord> all, dynamic id) =>
    all.where((r) => r.id == id).firstOrNull?.title ?? '';

String cycleTitle(List<RanchRecord> all, RanchRecord record) =>
    (record.kind == RecordKind.crop
                ? record
                : all.where((r) => r.id == record.fields['cropId']).firstOrNull)
            ?.fields['cycle']
        as String? ??
    '';

String stateLabel(RanchRecord record) => record.kind == RecordKind.practice
    ? practiceStatus(record)
    : record.kind == RecordKind.observation
    ? observationStatus(record)
    : record.fields['stage'] as String? ?? '';

class RanchReport {
  const RanchReport(this.records, this.allRecords, {required this.selection});
  final List<RanchRecord> records, allRecords;
  final String selection;

  double get cost => records
      .where(
        (r) =>
            r.kind == RecordKind.practice && practiceStatus(r) == 'Realizada',
      )
      .fold(0, (v, r) => v + practiceCost(r));
  double get plannedCost => records
      .where(
        (r) =>
            r.kind == RecordKind.practice && practiceStatus(r) != 'Realizada',
      )
      .fold(0, (v, r) => v + practiceCost(r));
  double get kilograms => records
      .where(
        (r) =>
            r.kind == RecordKind.practice &&
            r.fields['activity'] == 'Cosecha' &&
            practiceStatus(r) == 'Realizada',
      )
      .fold(0, (v, r) => v + numberField(r, 'harvestKg'));

  Future<Uint8List> excelBytes() async {
    await exporters.loadLibrary();
    return exporters.RanchReportExporter(
      records,
      allRecords,
      selection: selection,
    ).generateExcel();
  }

  Future<Uint8List> pdfBytes() async {
    await exporters.loadLibrary();
    return exporters.RanchReportExporter(
      records,
      allRecords,
      selection: selection,
    ).generatePdf();
  }
}
