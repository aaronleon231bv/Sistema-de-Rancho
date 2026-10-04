import 'package:flutter/material.dart';

import '../data/backup_files.dart';
import '../data/observation_photo.dart';
import '../data/ranch_reports.dart';
import '../data/ranch_store.dart';

class ParcelHistory extends StatefulWidget {
  const ParcelHistory({
    super.key,
    required this.store,
    required this.onEdit,
    this.initialParcelId,
  });
  final RanchStore store;
  final Future<void> Function(RanchRecord record) onEdit;
  final String? initialParcelId;

  @override
  State<ParcelHistory> createState() => _ParcelHistoryState();
}

class _ParcelHistoryState extends State<ParcelHistory> {
  List<RanchRecord> records = [];
  String? parcelId, cropId, responsible;
  DateTimeRange? range;
  bool loading = true, exporting = false;
  String? error;

  @override
  void initState() {
    super.initState();
    parcelId = widget.initialParcelId;
    reload();
  }

  Future<void> reload() async {
    try {
      final current = await widget.store.records();
      if (mounted) {
        setState(() {
          records = current;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'No se pudo leer el historial. Intenta de nuevo.';
        });
      }
    }
  }

  List<RanchRecord> selected(List<RanchRecord> current) => filterHistory(
    current,
    parcelId: parcelId,
    cropId: cropId,
    responsible: responsible,
    from: range?.start,
    to: range?.end,
  );

  String get selection => [
    parcelId == null ? 'Todas las parcelas' : relatedTitle(records, parcelId),
    if (cropId != null)
      '${relatedTitle(records, cropId)} · '
          '${records.where((r) => r.id == cropId).first.fields['cycle'] ?? 'Sin ciclo'}',
    if (responsible != null) 'Responsable: $responsible',
    if (range != null) '${dateLabel(range!.start)} al ${dateLabel(range!.end)}',
  ].join(' | ');

  String dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Future<void> export(String extension) async {
    setState(() => exporting = true);
    try {
      final current = await widget.store.records();
      final report = RanchReport(
        selected(current),
        current,
        selection: selection,
      );
      final bytes = extension == 'pdf'
          ? await report.pdfBytes()
          : await report.excelBytes();
      final saved = await saveReportFile(bytes, extension);
      if (mounted && saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reporte guardado.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo generar el reporte. Tus registros se conservan.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = selected(records);
    final crops = records
        .where(
          (r) =>
              r.kind == RecordKind.crop &&
              (parcelId == null || r.fields['parcelId'] == parcelId),
        )
        .toList();
    final people =
        records
            .map((r) => r.fields['responsible'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final report = RanchReport(visible, records, selection: selection);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial y reportes')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: reload,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (error != null) ...[
                          Text(error!),
                          TextButton(
                            onPressed: reload,
                            child: const Text('Reintentar'),
                          ),
                        ],
                        DropdownButtonFormField<String>(
                          initialValue: parcelId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Parcela',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todas las parcelas'),
                            ),
                            for (final r in records.where(
                              (r) => r.kind == RecordKind.parcel,
                            ))
                              DropdownMenuItem(
                                value: r.id,
                                child: Text(r.title),
                              ),
                          ],
                          onChanged: (value) => setState(() {
                            parcelId = value;
                            cropId = null;
                          }),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(parcelId),
                          initialValue: cropId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Cultivo y ciclo',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos los cultivos y ciclos'),
                            ),
                            for (final r in crops)
                              DropdownMenuItem(
                                value: r.id,
                                child: Text(
                                  '${r.title} · ${r.fields['cycle'] ?? 'Sin ciclo'} '
                                  '(${r.fields['date'] ?? ''})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) => setState(() => cropId = value),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: responsible,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Responsable',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos los responsables'),
                            ),
                            for (final person in people)
                              DropdownMenuItem(
                                value: person,
                                child: Text(person),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => responsible = value),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.date_range),
                              label: Text(
                                range == null
                                    ? 'Filtrar por fechas'
                                    : '${dateLabel(range!.start)} al ${dateLabel(range!.end)}',
                              ),
                              onPressed: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2200, 12, 31),
                                  initialDateRange: range,
                                );
                                if (picked != null && mounted) {
                                  setState(() => range = picked);
                                }
                              },
                            ),
                            if (range != null)
                              TextButton(
                                onPressed: () => setState(() => range = null),
                                child: const Text('Quitar fechas'),
                              ),
                            FilledButton.icon(
                              onPressed: exporting || visible.isEmpty
                                  ? null
                                  : () => export('pdf'),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('Guardar PDF'),
                            ),
                            FilledButton.icon(
                              onPressed: exporting || visible.isEmpty
                                  ? null
                                  : () => export('xlsx'),
                              icon: const Icon(Icons.table_chart_outlined),
                              label: const Text('Guardar Excel'),
                            ),
                          ],
                        ),
                        if (exporting) const LinearProgressIndicator(),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '${visible.length} registros\nGastos realizados: \$${report.cost.toStringAsFixed(2)} MXN\n'
                              'Costos programados: \$${report.plannedCost.toStringAsFixed(2)} MXN\n'
                              'Cosecha realizada: ${report.kilograms.toStringAsFixed(2)} kg',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (cropId == null && crops.isNotEmpty) ...[
                          const Text(
                            'Resultados por cultivo y ciclo',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          for (final crop in crops)
                            Builder(
                              builder: (_) {
                                final cropReport = RanchReport(
                                  visible
                                      .where(
                                        (r) => r.fields['cropId'] == crop.id,
                                      )
                                      .toList(),
                                  records,
                                  selection: '',
                                );
                                return ListTile(
                                  title: Text(
                                    '${crop.title} · ${crop.fields['cycle'] ?? 'Sin ciclo'}',
                                  ),
                                  subtitle: Text(
                                    'Gastos: \$${cropReport.cost.toStringAsFixed(2)} MXN · '
                                    'Cosecha: ${cropReport.kilograms.toStringAsFixed(2)} kg',
                                  ),
                                  onTap: () => setState(() => cropId = crop.id),
                                );
                              },
                            ),
                          const Divider(),
                        ],
                        const Text(
                          'Historial cronológico',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (visible.isEmpty)
                          const Text('No hay registros con estos filtros.'),
                        for (final r in visible)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      '${recordLabels[r.kind]} · ${r.title}',
                                    ),
                                    subtitle: Text(
                                      r.kind == RecordKind.parcel
                                          ? '${r.fields['area']} ha · ${r.fields['location'] ?? ''}'
                                          : [
                                                  r.fields['date'] as String? ??
                                                      '',
                                                  stateLabel(r),
                                                  relatedTitle(
                                                    records,
                                                    r.fields['parcelId'],
                                                  ),
                                                  r.fields['responsible']
                                                          as String? ??
                                                      '',
                                                ]
                                                .where(
                                                  (value) => value.isNotEmpty,
                                                )
                                                .join(' · '),
                                    ),
                                    trailing: const Icon(Icons.edit_outlined),
                                    onTap: () async {
                                      await widget.onEdit(r);
                                      await reload();
                                    },
                                  ),
                                  if ((r.fields['notes'] as String? ?? '')
                                      .isNotEmpty)
                                    Text(r.fields['notes'] as String),
                                  if (r.kind == RecordKind.practice)
                                    Text(
                                      'Costo: \$${practiceCost(r).toStringAsFixed(2)} MXN',
                                    ),
                                  if (r.fields['activity'] == 'Cosecha')
                                    Text(
                                      'Cosecha: ${numberField(r, 'harvestKg')} kg · '
                                      '${numberField(r, 'harvestArea')} ha · '
                                      '${harvestYield(r).toStringAsFixed(2)} kg/ha',
                                    ),
                                  if ((r.fields['followUp'] as String? ?? '')
                                      .isNotEmpty)
                                    Text(
                                      'Seguimiento: ${r.fields['followUp']}',
                                    ),
                                  if (ObservationPhoto.fromJson(
                                        r.fields['photo'],
                                      )
                                      case final photo?) ...[
                                    const SizedBox(height: 8),
                                    Image.memory(
                                      photo.bytes,
                                      height: 160,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, error, stack) =>
                                          const Text(
                                            'No se pudo mostrar la fotografía.',
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
