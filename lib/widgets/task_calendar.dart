import 'package:flutter/material.dart';

import '../data/ranch_store.dart';
import '../data/record_status.dart';

class TaskCalendar extends StatefulWidget {
  const TaskCalendar({super.key, required this.store, required this.onEdit});
  final RanchStore store;
  final Future<void> Function(RanchRecord? record, DateTime? day) onEdit;

  @override
  State<TaskCalendar> createState() => _TaskCalendarState();
}

class _TaskCalendarState extends State<TaskCalendar> {
  List<RanchRecord> records = [];
  DateTime? selectedDay;
  String filter = 'Pendientes';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final result = await widget.store.records();
      if (mounted) {
        setState(() {
          records = result;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'No se pudieron consultar las tareas. Intenta de nuevo.';
        });
      }
    }
  }

  Future<void> edit(RanchRecord? record) async {
    await widget.onEdit(record, selectedDay);
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final tasks =
        records.where((r) {
          if (r.kind != RecordKind.practice) return false;
          final status = practiceStatus(r);
          if (filter == 'Pendientes' && status == 'Realizada') return false;
          if (filter == 'Realizadas' && status != 'Realizada') return false;
          if (filter == 'Vencidas' && status != 'Vencida') return false;
          return selectedDay == null ||
              r.fields['date'] ==
                  selectedDay!.toIso8601String().substring(0, 10);
        }).toList()..sort(
          (a, b) => (a.fields['date'] as String).compareTo(
            b.fields['date'] as String,
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario de tareas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : () => edit(null),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: reload,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        if (error != null) ...[
                          Text(error!),
                          TextButton(
                            onPressed: reload,
                            child: const Text('Reintentar'),
                          ),
                        ],
                        const Text(
                          'Selecciona un día para consultar sus actividades. '
                          'Las tareas pendientes de fechas anteriores aparecen como vencidas.',
                        ),
                        CalendarDatePicker(
                          initialDate: selectedDay ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2200, 12, 31),
                          onDateChanged: (day) =>
                              setState(() => selectedDay = day),
                        ),
                        if (selectedDay != null)
                          TextButton.icon(
                            onPressed: () => setState(() => selectedDay = null),
                            icon: const Icon(Icons.date_range),
                            label: const Text('Mostrar todas las fechas'),
                          ),
                        Text(
                          selectedDay == null
                              ? 'Tareas de todas las fechas'
                              : 'Tareas del ${selectedDay!.day}/${selectedDay!.month}/${selectedDay!.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final value in [
                              'Pendientes',
                              'Vencidas',
                              'Realizadas',
                              'Todas',
                            ])
                              ChoiceChip(
                                label: Text(value),
                                selected: filter == value,
                                onSelected: (_) =>
                                    setState(() => filter = value),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (tasks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No hay tareas con estos filtros.'),
                          ),
                        for (final task in tasks)
                          Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: Icon(
                                practiceStatus(task) == 'Realizada'
                                    ? Icons.check_circle_outline
                                    : Icons.event_outlined,
                              ),
                              title: Text(task.title),
                              subtitle: Text(
                                '${task.fields['date']} · ${practiceStatus(task)}\n'
                                '${records.where((r) => r.id == task.fields['parcelId']).firstOrNull?.title ?? ''}'
                                ' · ${task.fields['responsible'] ?? ''}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => edit(task),
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
