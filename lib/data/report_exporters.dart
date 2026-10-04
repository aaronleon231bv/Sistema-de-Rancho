import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'ranch_store.dart';

import 'ranch_reports.dart';

class RanchReportExporter extends RanchReport {
  const RanchReportExporter(
    super.records,
    super.allRecords, {
    required super.selection,
  });

  Uint8List generateExcel() {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Bitácora');
    final sheet = workbook['Bitácora'];
    final headers = [
      'Tipo',
      'Título',
      'Parcela',
      'Cultivo',
      'Ciclo',
      'Fecha',
      'Responsable',
      'Estado',
      'Actividad',
      'Insumo',
      'Cantidad',
      'Unidad',
      'Costo insumo MXN',
      'Horas',
      'Costo por hora MXN',
      'Otros gastos MXN',
      'Costo total MXN',
      'Cosecha kg',
      'Superficie cosechada ha',
      'Rendimiento kg/ha',
      'Notas',
      'Seguimiento',
      'Nivel de atención',
      'Fotografía',
    ];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final r in records) {
      final f = r.fields;
      sheet.appendRow([
        TextCellValue(recordLabels[r.kind]!),
        TextCellValue(r.title),
        TextCellValue(
          r.kind == RecordKind.parcel
              ? r.title
              : relatedTitle(allRecords, f['parcelId']),
        ),
        TextCellValue(
          r.kind == RecordKind.crop
              ? r.title
              : relatedTitle(allRecords, f['cropId']),
        ),
        TextCellValue(cycleTitle(allRecords, r)),
        TextCellValue(f['date'] as String? ?? ''),
        TextCellValue(f['responsible'] as String? ?? ''),
        TextCellValue(stateLabel(r)),
        TextCellValue(f['activity'] as String? ?? ''),
        TextCellValue(f['inputName'] as String? ?? ''),
        DoubleCellValue(numberField(r, 'inputQuantity')),
        TextCellValue(f['inputUnit'] as String? ?? ''),
        for (final key in [
          'inputCost',
          'laborHours',
          'hourlyCost',
          'otherCost',
        ])
          DoubleCellValue(numberField(r, key)),
        DoubleCellValue(practiceCost(r)),
        DoubleCellValue(numberField(r, 'harvestKg')),
        DoubleCellValue(numberField(r, 'harvestArea')),
        DoubleCellValue(harvestYield(r)),
        TextCellValue(f['notes'] as String? ?? ''),
        TextCellValue(f['followUp'] as String? ?? ''),
        TextCellValue(f['severity'] as String? ?? ''),
        TextCellValue(
          f['photo'] == null
              ? ''
              : (f['photo'] as Map)['name'] as String? ?? 'Sí',
        ),
      ]);
    }
    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1B3B6C'),
        fontColorHex: ExcelColor.white,
      );
      sheet.setColumnWidth(i, i == 20 || i == 21 ? 45 : 24);
    }
    final summary = workbook['Resumen'];
    summary.appendRow([
      TextCellValue('Bitácora del rancho · TecNM Campus Chiná'),
    ]);
    summary.appendRow([TextCellValue('Selección'), TextCellValue(selection)]);
    summary.appendRow([
      TextCellValue('Registros'),
      IntCellValue(records.length),
    ]);
    summary.appendRow([
      TextCellValue('Gastos realizados MXN'),
      DoubleCellValue(cost),
    ]);
    summary.appendRow([
      TextCellValue('Costos programados MXN'),
      DoubleCellValue(plannedCost),
    ]);
    summary.appendRow([
      TextCellValue('Cosecha realizada kg'),
      DoubleCellValue(kilograms),
    ]);
    summary.setColumnWidth(0, 42);
    summary.setColumnWidth(1, 65);
    return Uint8List.fromList(workbook.encode()!);
  }

  Future<Uint8List> generatePdf() async {
    final document = pw.Document();
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/logos/tecnm.jpg')).buffer.asUint8List(),
    );
    final widgets = <pw.Widget>[
      pw.Text(selection),
      pw.SizedBox(height: 8),
      pw.Text(
        '${records.length} registros | Gastos realizados: ${cost.toStringAsFixed(2)} MXN',
      ),
      pw.Text(
        'Costos programados: ${plannedCost.toStringAsFixed(2)} MXN | Cosecha: ${kilograms.toStringAsFixed(2)} kg',
      ),
      pw.SizedBox(height: 16),
    ];
    void addText(String text) {
      // Bound each block so even very long field notes can flow across pages.
      for (final paragraph in text.split('\n')) {
        if (paragraph.isEmpty) {
          widgets.add(pw.SizedBox(height: 4));
        }
        for (var offset = 0; offset < paragraph.length; offset += 800) {
          widgets.add(
            pw.Text(
              paragraph.substring(
                offset,
                (offset + 800).clamp(0, paragraph.length),
              ),
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
        }
      }
    }

    for (final r in records) {
      final f = r.fields;
      widgets.add(pw.NewPage(freeSpace: 140));
      widgets.add(
        pw.Text(
          '${recordLabels[r.kind]}: ${r.title}',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
      );
      final details = [
        f['date'] as String? ?? '',
        stateLabel(r),
        f['responsible'] as String? ?? '',
      ].where((s) => s.isNotEmpty).join(' | ');
      if (details.isNotEmpty) addText(details);
      addText(
        'Parcela: ${r.kind == RecordKind.parcel ? r.title : relatedTitle(allRecords, f['parcelId'])} | '
        'Cultivo: ${r.kind == RecordKind.crop ? r.title : relatedTitle(allRecords, f['cropId'])} | Ciclo: ${cycleTitle(allRecords, r)}',
      );
      if (r.kind == RecordKind.parcel) {
        addText(
          'Superficie: ${f['area']} ha | Ubicación: ${f['location'] ?? ''}',
        );
      }
      if (r.kind == RecordKind.practice) {
        addText(
          'Actividad: ${f['activity']} | Costo: ${practiceCost(r).toStringAsFixed(2)} MXN',
        );
        addText(
          'Insumo: ${f['inputName'] ?? ''} | ${f['inputQuantity'] ?? ''} ${f['inputUnit'] ?? ''} | '
          'Costo insumo: ${numberField(r, 'inputCost')} MXN | Trabajo: ${numberField(r, 'laborHours')} h '
          'a ${numberField(r, 'hourlyCost')} MXN/h | Otros gastos: ${numberField(r, 'otherCost')} MXN',
        );
        if (f['activity'] == 'Cosecha') {
          addText(
            'Cosecha: ${numberField(r, 'harvestKg')} kg | '
            '${numberField(r, 'harvestArea')} ha | Rendimiento: ${harvestYield(r).toStringAsFixed(2)} kg/ha',
          );
        }
      }
      if (r.kind == RecordKind.observation) {
        addText('Nivel de atención: ${f['severity'] ?? ''}');
      }
      addText('Notas: ${f['notes'] ?? ''}');
      if (r.kind == RecordKind.observation) {
        addText('Seguimiento: ${f['followUp'] ?? ''}');
        for (final item in (f['followUpHistory'] as List? ?? [])) {
          addText(
            '${item['date']} | ${item['status']} | ${item['responsible']} | ${item['notes']}',
          );
        }
      }
      if (f['photo'] is Map) {
        final bytes = base64Decode((f['photo'] as Map)['base64'] as String);
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Image(
              pw.MemoryImage(bytes),
              height: 170,
              fit: pw.BoxFit.contain,
            ),
          ),
        );
      }
      widgets.add(pw.Divider());
      widgets.add(pw.SizedBox(height: 10));
    }
    document.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        pageFormat: PdfPageFormat.a4,
        maxPages: 1000,
        header: (_) => pw.Row(
          children: [
            pw.Image(logo, width: 55, height: 40),
            pw.SizedBox(width: 12),
            pw.Text(
              'Bitácora del rancho\nTecNM · Campus Chiná',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        footer: (context) => pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        build: (_) => widgets,
      ),
    );
    return document.save();
  }
}
