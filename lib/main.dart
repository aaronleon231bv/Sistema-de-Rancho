import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/observation_photo.dart';
import 'data/ranch_store.dart';
import 'data/backup_files.dart';
import 'data/record_status.dart';
import 'widgets/task_calendar.dart';
import 'widgets/parcel_history.dart';
import 'widgets/ranch_guide.dart';
import 'widgets/observation_photo_field.dart';
import 'widgets/institutional_brand.dart';
import 'widgets/adaptive_layout.dart';
import 'data/open_store.dart'
    if (dart.library.js_interop) 'data/open_store_web.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RanchStartup(openStore: () => openRanchStore()));
}

class RanchStartup extends StatefulWidget {
  const RanchStartup({super.key, required this.openStore});
  final Future<RanchStore> Function() openStore;
  @override
  State<RanchStartup> createState() => _RanchStartupState();
}

class _RanchStartupState extends State<RanchStartup> {
  late Future<RanchStore> opening;
  @override
  void initState() {
    super.initState();
    opening = open();
  }

  Future<RanchStore> open() => widget.openStore().timeout(
    const Duration(seconds: 30),
    onTimeout: () =>
        throw StateError('La apertura de la base de datos tardó demasiado.'),
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<RanchStore>(
    future: opening,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData) {
        return RanchApp(store: snapshot.data!);
      }
      return MaterialApp(
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        title: 'Bitácora del rancho',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: institutionalBlue),
        ),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: SizedBox(
                width: 440,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.eco_outlined,
                        size: 56,
                        color: institutionalBlue,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Bitácora del rancho',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (snapshot.connectionState != ConnectionState.done ||
                          !snapshot.hasError) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 18),
                        const Text('Abriendo tus registros locales…'),
                      ] else ...[
                        const Text(
                          'No se pudo abrir la bitácora. Tus registros no se han borrado.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => setState(() {
                            opening = open();
                          }),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

const institutionalBlue = Color(0xFF1B3B6C);
const institutionalBurgundy = Color(0xFF651333);
const institutionalGold = Color(0xFFB18A34);
const labels = {
  RecordKind.parcel: 'Parcela',
  RecordKind.crop: 'Cultivo',
  RecordKind.practice: 'Práctica',
  RecordKind.observation: 'Observación',
};
const icons = {
  RecordKind.parcel: Icons.grid_view_rounded,
  RecordKind.crop: Icons.grass_rounded,
  RecordKind.practice: Icons.agriculture_rounded,
  RecordKind.observation: Icons.edit_note_rounded,
};
String dateLabel(String value) {
  final date = DateTime.tryParse(value);
  return date == null
      ? value
      : '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class RanchApp extends StatelessWidget {
  const RanchApp({super.key, required this.store});
  final RanchStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('es', 'MX'),
    supportedLocales: const [Locale('es', 'MX')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    title: 'Bitácora del rancho',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: institutionalBlue,
        primary: institutionalBlue,
        secondary: institutionalBurgundy,
        tertiary: institutionalGold,
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F5F8),
      appBarTheme: const AppBarTheme(
        backgroundColor: institutionalBlue,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E6EE)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: institutionalBurgundy,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFE3EAF5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    ),
    home: RanchHome(store: store),
  );
}

enum RecordFormResult { saved, deleted }

class RanchHome extends StatefulWidget {
  const RanchHome({super.key, required this.store});
  final RanchStore store;
  @override
  State<RanchHome> createState() => _RanchHomeState();
}

class _RanchHomeState extends State<RanchHome> {
  List<RanchRecord> records = [];
  int tab = 0;
  bool loading = true;
  bool backingUp = false;
  String query = '', filter = 'Todos';
  @override
  void initState() {
    super.initState();
    reload();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> reload() async {
    try {
      final result = await widget.store.records();
      if (mounted) {
        setState(() {
          records = result;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
      message('No se pudieron consultar los registros. Intenta de nuevo.');
    }
  }

  Future<void> openForm(RecordKind kind, {RanchRecord? record}) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (kind != RecordKind.parcel &&
        !records.any((r) => r.kind == RecordKind.parcel)) {
      message('Registra primero una parcela.');
      return;
    }
    final result = await Navigator.push<RecordFormResult>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordForm(
          store: widget.store,
          records: records,
          kind: kind,
          record: record,
        ),
      ),
    );
    if (result != null) {
      await reload();
      message(
        result == RecordFormResult.deleted
            ? 'Práctica eliminada.'
            : 'Registro guardado en este dispositivo.',
      );
    }
  }

  Future<void> export() async {
    try {
      await Clipboard.setData(
        ClipboardData(text: await widget.store.exportBackup()),
      );
      message(
        'Bitácora copiada como JSON. Pégala en un archivo para respaldarla.',
      );
    } catch (_) {
      message('No se pudo copiar el respaldo.');
    }
  }

  Future<void> backupAction(String action) async {
    if (backingUp) return;
    setState(() => backingUp = true);
    try {
      if (action == 'save') {
        if (await saveBackupFile(await widget.store.exportBackup())) {
          message('Respaldo guardado con registros y fotografías.');
        }
      } else if (action == 'restore') {
        final content = await pickBackupFile();
        if (content == null || !mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restaurar respaldo'),
            content: const Text(
              'Se agregarán los registros que falten. '
              'Los registros que ya existen se conservarán sin cambios. '
              'Si el archivo es inválido, no se importará ningún registro.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restaurar'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        final result = await widget.store.restoreBackup(content);
        await reload();
        message(
          '${result.imported} registros restaurados. '
          '${result.skipped} ya existían y se conservaron.',
        );
      } else if (action == 'verify') {
        final count = await widget.store.verifySavedRecords();
        message(
          'Comprobación correcta: $count registros guardados y legibles.',
        );
      } else {
        await export();
      }
    } catch (error) {
      message(
        error is FormatException
            ? error.message
            : 'No se pudo completar la operación. Tus registros se conservan.',
      );
    } finally {
      if (mounted) setState(() => backingUp = false);
    }
  }

  Future<void> openCalendar() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (calendarContext) => TaskCalendar(
          store: widget.store,
          onEdit: (record, day) async {
            final current = await widget.store.records();
            if (!calendarContext.mounted) return;
            if (!current.any((r) => r.kind == RecordKind.parcel)) {
              ScaffoldMessenger.of(calendarContext).showSnackBar(
                const SnackBar(content: Text('Registra primero una parcela.')),
              );
              return;
            }
            final result = await Navigator.push<RecordFormResult>(
              calendarContext,
              MaterialPageRoute(
                builder: (_) => RecordForm(
                  store: widget.store,
                  records: current,
                  kind: RecordKind.practice,
                  record: record,
                  initialStatus: 'Pendiente',
                  initialDate: day,
                ),
              ),
            );
            if (calendarContext.mounted && result != null) {
              ScaffoldMessenger.of(calendarContext).showSnackBar(
                SnackBar(
                  content: Text(
                    result == RecordFormResult.deleted
                        ? 'Práctica eliminada.'
                        : 'Tarea guardada.',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
    await reload();
  }

  void add() {
    if (tab == 1) {
      openForm(RecordKind.parcel);
      return;
    }
    if (tab == 2) {
      openForm(RecordKind.crop);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '¿Qué deseas registrar?',
                style: TextStyle(fontSize: 20),
              ),
            ),
            for (final kind
                in (tab == 3
                    ? [RecordKind.practice, RecordKind.observation]
                    : RecordKind.values))
              ListTile(
                leading: Icon(icons[kind], color: institutionalBlue),
                title: Text(labels[kind]!),
                subtitle: Text(recordDescriptions[kind]!),
                onTap: () {
                  Navigator.pop(context);
                  openForm(kind);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String relation(String? id) =>
      records.where((r) => r.id == id).firstOrNull?.title ?? '';
  Future<void> openHistory({String? parcelId}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ParcelHistory(
          store: widget.store,
          initialParcelId: parcelId,
          onEdit: (record) => openForm(record.kind, record: record),
        ),
      ),
    );
    await reload();
  }

  Widget recordTile(RanchRecord record) {
    final fields = record.fields;
    final details = [
      labels[record.kind]!,
      if (fields['parcelId'] != null) relation(fields['parcelId']),
      if (fields['date'] != null) dateLabel(fields['date']),
      if (record.kind == RecordKind.parcel) '${fields['area']} ha',
      if (fields['photo'] != null) 'Con fotografía',
      if (record.kind == RecordKind.practice) practiceStatus(record),
      if (record.kind == RecordKind.observation) observationStatus(record),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF0F9),
          child: Icon(icons[record.kind], color: institutionalBlue),
        ),
        title: Text(
          record.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${details.join(' · ')}\nGuardado en la bitácora'),
        isThreeLine: true,
        trailing: record.kind == RecordKind.parcel
            ? IconButton(
                tooltip: 'Historial de la parcela',
                icon: const Icon(Icons.history),
                onPressed: () => openHistory(parcelId: record.id),
              )
            : const Icon(Icons.chevron_right),
        onTap: () => openForm(record.kind, record: record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = records.where((r) {
      final matchTab = tab == 1
          ? r.kind == RecordKind.parcel
          : tab == 2
          ? r.kind == RecordKind.crop
          : r.kind == RecordKind.practice || r.kind == RecordKind.observation;
      final matchFilter = filter == 'Todos' || labels[r.kind] == filter;
      return matchTab &&
          (tab != 3 || matchFilter) &&
          '${r.title} ${r.fields['notes'] ?? ''} ${relation(r.fields['parcelId'])}'
              .toLowerCase()
              .contains(query.toLowerCase());
    }).toList();
    return AdaptiveRanchScaffold(
      selectedIndex: tab,
      onSelected: (value) => setState(() {
        tab = value;
        query = '';
        filter = 'Todos';
      }),
      title: const Text(
        'Bitácora del rancho',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          onPressed: loading ? null : () => openHistory(),
          icon: const Icon(Icons.history),
          tooltip: 'Historial y reportes',
        ),
        IconButton(
          onPressed: loading ? null : openCalendar,
          icon: const Icon(Icons.calendar_month_outlined),
          tooltip: 'Calendario de tareas',
        ),
        PopupMenuButton<String>(
          enabled: !loading && !backingUp,
          tooltip: 'Respaldos y comprobación',
          icon: backingUp
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.backup_outlined),
          onSelected: backupAction,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'save',
              child: Text('Guardar respaldo en archivo'),
            ),
            PopupMenuItem(
              value: 'restore',
              child: Text('Restaurar desde archivo'),
            ),
            PopupMenuItem(value: 'copy', child: Text('Copiar respaldo JSON')),
            PopupMenuItem(
              value: 'verify',
              child: Text('Comprobar registros guardados'),
            ),
          ],
        ),
      ],
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: reload,
                    child: ListView(
                      key: ValueKey('home-section-$tab'),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      children: [
                        const InstitutionalBrand(),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [institutionalBlue, Color(0xFF102A50)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: const Border(
                              bottom: BorderSide(
                                color: institutionalGold,
                                width: 4,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TECNM · CAMPUS CHINÁ',
                                style: TextStyle(
                                  color: Color(0xFFE4C987),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.6,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tab == 0
                                    ? 'Tu bitácora de campo'
                                    : [
                                        'Inicio',
                                        'Parcelas',
                                        'Cultivos',
                                        'Bitácora de campo',
                                      ][tab],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  height: 1.15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tab == 0
                                    ? 'Registra las labores, los problemas y las cosechas de cada parcela para dar seguimiento al rancho.'
                                    : [
                                        '',
                                        'Registra dónde trabajas: nombre, superficie y ubicación de cada parcela.',
                                        'Registra qué siembras y en qué ciclo para consultar sus labores y cosechas.',
                                        'Prácticas: las labores que haces. Observaciones: los problemas o cambios que detectas.',
                                      ][tab],
                                style: const TextStyle(
                                  color: Color(0xFFDCE6F5),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () => showRanchGuide(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Color(0xFFDCE6F5),
                                  ),
                                ),
                                icon: const Icon(Icons.help_outline),
                                label: const Text('Cómo usar la bitácora'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.offline_pin_outlined,
                                color: institutionalBlue,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Tus registros se guardan sin internet.',
                                  style: TextStyle(
                                    color: institutionalBlue,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (tab == 0) ...[
                          if (!records.any(
                            (r) => r.kind == RecordKind.parcel,
                          )) ...[
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '1. Empieza por una parcela',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Ponle un nombre al lugar donde trabajas, indica su superficie y ubicación. '
                                      'Después agrega lo que siembras y las labores del campo.',
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          openForm(RecordKind.parcel),
                                      icon: const Icon(
                                        Icons.add_location_alt_outlined,
                                      ),
                                      label: const Text(
                                        'Registrar mi primera parcela',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () =>
                                      openForm(RecordKind.practice),
                                  icon: const Icon(Icons.agriculture_outlined),
                                  label: const Text('Registrar una labor'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      openForm(RecordKind.observation),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('Anotar una observación'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: openCalendar,
                                  icon: const Icon(Icons.event_outlined),
                                  label: const Text('Programar una tarea'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => openHistory(),
                                  icon: const Icon(Icons.assessment_outlined),
                                  label: const Text('Consultar resultados'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          Card(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.event_note_outlined,
                                  ),
                                  title: const Text('Tareas por realizar'),
                                  subtitle: Text(
                                    '${records.where((r) => r.kind == RecordKind.practice && practiceStatus(r) != 'Realizada').length} pendientes '
                                    '(${records.where((r) => r.kind == RecordKind.practice && practiceStatus(r) == 'Vencida').length} vencidas). Consulta el calendario.',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: openCalendar,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.report_problem_outlined,
                                  ),
                                  title: const Text(
                                    'Observaciones por atender',
                                  ),
                                  subtitle: Text(
                                    '${records.where((r) => r.kind == RecordKind.observation && observationStatus(r) != 'Resuelta').length} sin resolver '
                                    '(${records.where((r) => r.kind == RecordKind.observation && observationStatus(r) != 'Resuelta' && r.fields['severity'] == 'Urgente').length} urgentes). Consulta su seguimiento.',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => setState(() {
                                    tab = 3;
                                    filter = 'Observación';
                                    query = '';
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Tu rancho, de un vistazo',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: institutionalBlue,
                            ),
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final textScale =
                                  MediaQuery.textScalerOf(context).scale(14) /
                                  14;
                              final minWidth = 145 * textScale;
                              final columns =
                                  ((constraints.maxWidth + 12) /
                                          (minWidth + 12))
                                      .floor()
                                      .clamp(1, 4);
                              final width =
                                  (constraints.maxWidth - 12 * (columns - 1)) /
                                  columns;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final kind in RecordKind.values)
                                    SizedBox(
                                      width: width,
                                      child: Card(
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          onTap: () => setState(() {
                                            tab = kind == RecordKind.parcel
                                                ? 1
                                                : kind == RecordKind.crop
                                                ? 2
                                                : 3;
                                            query = '';
                                            filter =
                                                kind == RecordKind.practice ||
                                                    kind ==
                                                        RecordKind.observation
                                                ? labels[kind]!
                                                : 'Todos';
                                          }),
                                          child: Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  icons[kind],
                                                  color: kind.index.isEven
                                                      ? institutionalBlue
                                                      : institutionalBurgundy,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  '${records.where((r) => r.kind == kind).length}',
                                                  style: const TextStyle(
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.bold,
                                                    color: institutionalBlue,
                                                  ),
                                                ),
                                                Text(
                                                  [
                                                    'Parcelas',
                                                    'Cultivos',
                                                    'Prácticas',
                                                    'Observaciones',
                                                  ][kind.index],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 26),
                          const Text(
                            'Actividad reciente',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (records.isEmpty)
                            const _Empty(
                              text:
                                  'Comienza registrando una parcela. Después podrás asociar cultivos y actividades.',
                            ),
                          ResponsiveRecordList(
                            children: records.take(6).map(recordTile).toList(),
                          ),
                        ] else ...[
                          TextField(
                            key: ValueKey(tab),
                            decoration: const InputDecoration(
                              labelText: 'Buscar registros',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) => setState(() => query = value),
                          ),
                          const SizedBox(height: 12),
                          if (tab == 3)
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final value in [
                                  'Todos',
                                  'Práctica',
                                  'Observación',
                                ])
                                  ChoiceChip(
                                    label: Text(value),
                                    selected: filter == value,
                                    onSelected: (_) =>
                                        setState(() => filter = value),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          if (visible.isEmpty)
                            const _Empty(
                              text:
                                  'No hay registros para mostrar. Usa el botón de agregar para crear uno.',
                            ),
                          ResponsiveRecordList(
                            children: visible.map(recordTile).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: add,
        isExtended:
            MediaQuery.sizeOf(context).width >= 360 &&
            MediaQuery.sizeOf(context).height >= 500,
        tooltip: tab == 1
            ? 'Nueva parcela'
            : tab == 2
            ? 'Nuevo cultivo'
            : 'Nuevo registro',
        icon: const Icon(Icons.add),
        label: Text(
          tab == 1
              ? 'Nueva parcela'
              : tab == 2
              ? 'Nuevo cultivo'
              : 'Nuevo registro',
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Column(
      children: [
        const Icon(Icons.eco_outlined, size: 48, color: institutionalBlue),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

class RecordForm extends StatefulWidget {
  const RecordForm({
    super.key,
    required this.store,
    required this.records,
    required this.kind,
    this.record,
    this.initialStatus,
    this.initialDate,
    this.photoPicker = pickObservationPhoto,
  });
  final RanchStore store;
  final List<RanchRecord> records;
  final RecordKind kind;
  final RanchRecord? record;
  final String? initialStatus;
  final DateTime? initialDate;
  final Future<ObservationPhoto?> Function() photoPicker;
  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name,
      notes,
      area,
      location,
      responsible,
      variety,
      followUp,
      cycle,
      inputName,
      inputQuantity,
      inputUnit,
      inputCost,
      laborHours,
      hourlyCost,
      otherCost,
      harvestKg,
      harvestArea;
  late String status;
  String? parcelId, cropId;
  String activity = 'Preparación del suelo',
      severity = 'Normal',
      stage = 'Establecido';
  late DateTime date;
  bool saving = false;
  bool deleting = false;
  bool selectingPhoto = false;
  ObservationPhoto? photo;
  @override
  void initState() {
    super.initState();
    final f = widget.record?.fields ?? {};
    name = TextEditingController(text: f['name']);
    notes = TextEditingController(text: f['notes']);
    area = TextEditingController(text: f['area']?.toString());
    location = TextEditingController(text: f['location']);
    responsible = TextEditingController(text: f['responsible']);
    variety = TextEditingController(text: f['variety']);
    followUp = TextEditingController(text: f['followUp']);
    cycle = TextEditingController(text: f['cycle']);
    inputName = TextEditingController(text: f['inputName']);
    inputQuantity = TextEditingController(text: f['inputQuantity']?.toString());
    inputUnit = TextEditingController(text: f['inputUnit']);
    inputCost = TextEditingController(text: f['inputCost']?.toString());
    laborHours = TextEditingController(text: f['laborHours']?.toString());
    hourlyCost = TextEditingController(text: f['hourlyCost']?.toString());
    otherCost = TextEditingController(text: f['otherCost']?.toString());
    harvestKg = TextEditingController(text: f['harvestKg']?.toString());
    harvestArea = TextEditingController(text: f['harvestArea']?.toString());
    status =
        f['status'] ??
        (widget.kind == RecordKind.practice
            ? (widget.record == null
                  ? widget.initialStatus ?? 'Realizada'
                  : 'Realizada')
            : 'Abierta');
    parcelId = f['parcelId'];
    cropId = f['cropId'];
    activity = f['activity'] ?? activity;
    severity = f['severity'] ?? severity;
    stage = f['stage'] ?? stage;
    date =
        DateTime.tryParse(f['date'] ?? '') ??
        widget.initialDate ??
        DateTime.now();
    photo = ObservationPhoto.fromJson(f['photo']);
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      notes,
      area,
      location,
      responsible,
      variety,
      followUp,
      cycle,
      inputName,
      inputQuantity,
      inputUnit,
      inputCost,
      laborHours,
      hourlyCost,
      otherCost,
      harvestKg,
      harvestArea,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int lines = 1,
    bool number = false,
    bool zeroAllowed = false,
  }) => Padding(
    padding: EdgeInsets.zero,
    child: TextFormField(
      key: lines > 1 ? const ValueKey('multiline-field') : null,
      controller: controller,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      maxLines: lines,
      enabled: !saving,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (required && (value ?? '').trim().isEmpty) {
          return 'Completa este campo.';
        }
        if (number) {
          if (!required && (value ?? '').trim().isEmpty) return null;
          final number = double.tryParse((value ?? '').replaceAll(',', '.'));
          if (number == null ||
              !number.isFinite ||
              (zeroAllowed ? number < 0 : number <= 0)) {
            return zeroAllowed
                ? 'Escribe un número igual o mayor que cero.'
                : 'Escribe un número mayor que cero.';
          }
        }
        return null;
      },
    ),
  );
  Widget choice(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: EdgeInsets.zero,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: saving ? null : (v) => setState(() => onChanged(v!)),
    ),
  );
  Future<void> selectPhoto() async {
    if (saving || selectingPhoto) return;
    setState(() => selectingPhoto = true);
    try {
      final selected = await widget.photoPicker();
      if (mounted && selected != null) setState(() => photo = selected);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'No se pudo abrir la fotografía. Revisa el acceso a tus fotos e inténtalo de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => selectingPhoto = false);
    }
  }

  Future<void> save() async {
    if (saving || selectingPhoto) return;
    if (!form.currentState!.validate()) return;
    if (widget.kind == RecordKind.practice &&
        inputName.text.trim().isNotEmpty &&
        (inputQuantity.text.trim().isEmpty || inputUnit.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indica la cantidad y unidad del insumo registrado.'),
        ),
      );
      return;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    if (widget.kind == RecordKind.practice &&
        status == 'Realizada' &&
        DateUtils.dateOnly(date).isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Una práctica realizada necesita una fecha de hoy o anterior. '
            'Para programarla, elige Pendiente.',
          ),
        ),
      );
      return;
    }
    if (widget.kind == RecordKind.crop &&
        widget.record != null &&
        parcelId != widget.record!.fields['parcelId'] &&
        widget.records.any((r) => r.fields['cropId'] == widget.record!.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este cultivo tiene actividades vinculadas. Conserva su parcela para mantener el historial.',
          ),
        ),
      );
      return;
    }
    setState(() => saving = true);
    final kind = widget.kind;
    final fields = <String, dynamic>{
      ...?widget.record?.fields,
      'name': name.text.trim(),
      'notes': notes.text.trim(),
      if (kind == RecordKind.parcel) ...{
        'area': double.parse(area.text.replaceAll(',', '.')),
        'location': location.text.trim(),
      },
      if (kind != RecordKind.parcel) ...{
        'parcelId': parcelId,
        'date': date.toIso8601String().substring(0, 10),
      },
      if (kind == RecordKind.crop) ...{
        'variety': variety.text.trim(),
        'stage': stage,
        'cycle': cycle.text.trim(),
      },
      if (kind == RecordKind.practice || kind == RecordKind.observation) ...{
        'cropId': cropId,
        'responsible': responsible.text.trim(),
      },
      if (kind == RecordKind.practice) 'activity': activity,
      if (kind == RecordKind.practice) ...{
        'inputName': inputName.text.trim(),
        'inputUnit': inputUnit.text.trim(),
        for (final entry in {
          'inputQuantity': inputQuantity,
          'inputCost': inputCost,
          'laborHours': laborHours,
          'hourlyCost': hourlyCost,
          'otherCost': otherCost,
          if (activity == 'Cosecha') ...{
            'harvestKg': harvestKg,
            'harvestArea': harvestArea,
          },
        }.entries)
          entry.key: entry.value.text.trim().isEmpty
              ? null
              : double.parse(entry.value.text.replaceAll(',', '.')),
      },
      if (kind == RecordKind.practice || kind == RecordKind.observation)
        'status': status,
      if (kind == RecordKind.observation) 'severity': severity,
      if (kind == RecordKind.observation) ...{
        'followUp': followUp.text.trim(),
        'followUpHistory': [
          ...?widget.record?.fields['followUpHistory'] as List?,
          if (widget.record?.fields['status'] != status ||
              widget.record?.fields['followUp'] != followUp.text.trim())
            {
              'date': DateTime.now().toIso8601String(),
              'status': status,
              'notes': followUp.text.trim(),
              'responsible': responsible.text.trim(),
            },
        ],
      },
      if (kind == RecordKind.observation && photo != null)
        'photo': photo!.toJson(),
    };
    if (kind == RecordKind.observation && photo == null) fields.remove('photo');
    if (kind == RecordKind.practice && activity != 'Cosecha') {
      fields.remove('harvestKg');
      fields.remove('harvestArea');
    }
    try {
      await widget.store.save(kind, fields, id: widget.record?.id);
      if (mounted) Navigator.pop(context, RecordFormResult.saved);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar. Tu formulario sigue disponible.',
            ),
          ),
        );
      }
    }
  }

  Future<void> deletePractice() async {
    if (saving || selectingPhoto || widget.record == null) return;
    final record = widget.record!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar esta práctica?'),
        content: Text(
          '«${record.title}»\n${dateLabel(record.fields['date'] as String)}\n\n'
          'Este registro, sus costos y los datos de cosecha dejarán de aparecer '
          'en la bitácora, el calendario y los reportes de este dispositivo. '
          'No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar práctica'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      saving = true;
      deleting = true;
    });
    try {
      await widget.store.deletePractice(record);
      if (mounted) Navigator.pop(context, RecordFormResult.deleted);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        saving = false;
        deleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'No se pudo eliminar la práctica. El registro se conserva.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final parcels = widget.records.where((r) => r.kind == RecordKind.parcel);
    final crops = widget.records.where(
      (r) => r.kind == RecordKind.crop && r.fields['parcelId'] == parcelId,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.record == null ? 'Registrar' : 'Editar'} ${labels[kind]!.toLowerCase()}',
        ),
        actions: [
          if (kind == RecordKind.practice && widget.record != null)
            IconButton(
              tooltip: 'Eliminar práctica',
              icon: const Icon(Icons.delete_outline),
              onPressed: saving || selectingPhoto ? null : deletePractice,
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Form(
            key: form,
            child: ResponsiveFormList(
              children: [
                Text(
                  '${formExplanations[kind]}\n\n'
                  'Se guarda en este dispositivo, incluso sin internet.',
                ),
                const SizedBox(height: 20),
                field(
                  name,
                  kind == RecordKind.crop
                      ? 'Nombre del cultivo'
                      : 'Nombre o título',
                  required: true,
                ),
                if (kind == RecordKind.parcel) ...[
                  field(
                    area,
                    'Superficie (hectáreas)',
                    required: true,
                    number: true,
                  ),
                  field(location, 'Ubicación o referencia', required: true),
                ],
                if (kind != RecordKind.parcel) ...[
                  DropdownButtonFormField<String>(
                    initialValue: parcelId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Parcela'),
                    items: parcels
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(r.title),
                          ),
                        )
                        .toList(),
                    validator: (v) =>
                        v == null ? 'Selecciona una parcela.' : null,
                    onChanged: saving
                        ? null
                        : (v) => setState(() {
                            parcelId = v;
                            cropId = null;
                          }),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(
                      kind == RecordKind.crop
                          ? 'Fecha de siembra'
                          : kind == RecordKind.practice && status == 'Pendiente'
                          ? 'Fecha programada'
                          : 'Fecha de la actividad',
                    ),
                    subtitle: Text(dateLabel(date.toIso8601String())),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: saving
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: kind == RecordKind.practice
                                  ? DateTime(2200, 12, 31)
                                  : DateTime.now(),
                            );
                            if (picked != null && mounted) {
                              setState(() => date = picked);
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                ],
                if (kind == RecordKind.crop) ...[
                  field(variety, 'Variedad (opcional)'),
                  field(cycle, 'Ciclo de cultivo (ej. Primavera 2026)'),
                  choice('Estado del cultivo', stage, [
                    'Establecido',
                    'En desarrollo',
                    'En cosecha',
                    'Finalizado',
                  ], (v) => stage = v),
                ],
                if (kind == RecordKind.practice ||
                    kind == RecordKind.observation) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(parcelId),
                    initialValue: cropId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cultivo (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Sin cultivo específico'),
                      ),
                      ...crops.map(
                        (r) =>
                            DropdownMenuItem(value: r.id, child: Text(r.title)),
                      ),
                    ],
                    onChanged: saving
                        ? null
                        : (v) => setState(() => cropId = v),
                  ),
                  const SizedBox(height: 16),
                  field(responsible, 'Responsable', required: true),
                ],
                if (kind == RecordKind.practice)
                  choice('Tipo de práctica', activity, [
                    'Preparación del suelo',
                    'Siembra',
                    'Riego',
                    'Fertilización',
                    'Control de plagas',
                    'Cosecha',
                    'Otra',
                  ], (v) => activity = v),
                if (kind == RecordKind.observation)
                  choice('Nivel de atención', severity, [
                    'Normal',
                    'Requiere seguimiento',
                    'Urgente',
                  ], (v) => severity = v),
                field(
                  notes,
                  kind == RecordKind.observation
                      ? 'Describe lo observado'
                      : 'Notas y resultados',
                  required: kind == RecordKind.observation,
                  lines: 4,
                ),
                if (kind == RecordKind.practice)
                  choice('Estado de la tarea', status, [
                    'Pendiente',
                    'Realizada',
                  ], (v) => status = v),
                if (kind == RecordKind.practice) ...[
                  const Text(
                    'Insumos y costos (opcionales, en pesos mexicanos)',
                  ),
                  field(inputName, 'Insumo principal o producto'),
                  field(inputQuantity, 'Cantidad de insumo', number: true),
                  field(inputUnit, 'Unidad del insumo (kg, L, piezas...)'),
                  field(
                    inputCost,
                    'Costo total del insumo (MXN)',
                    number: true,
                    zeroAllowed: true,
                  ),
                  field(
                    laborHours,
                    'Horas de trabajo',
                    number: true,
                    zeroAllowed: true,
                  ),
                  field(
                    hourlyCost,
                    'Costo por hora (MXN)',
                    number: true,
                    zeroAllowed: true,
                  ),
                  field(
                    otherCost,
                    'Otros gastos (MXN)',
                    number: true,
                    zeroAllowed: true,
                  ),
                  if (activity == 'Cosecha') ...[
                    const Text('Producción de esta cosecha'),
                    field(
                      harvestKg,
                      'Cantidad cosechada (kg)',
                      number: true,
                      required: status == 'Realizada',
                    ),
                    field(
                      harvestArea,
                      'Superficie cosechada (ha)',
                      number: true,
                      required: status == 'Realizada',
                    ),
                  ],
                ],
                if (kind == RecordKind.observation) ...[
                  choice('Estado del seguimiento', status, [
                    'Abierta',
                    'En atención',
                    'Resuelta',
                  ], (v) => status = v),
                  field(
                    followUp,
                    'Acciones de seguimiento y solución',
                    lines: 4,
                    required: status == 'Resuelta',
                  ),
                  if (widget.record?.fields['followUpHistory'] is List)
                    Text(
                      'Historial de seguimiento\n${(widget.record!.fields['followUpHistory'] as List).map((e) => '${e['date']} · ${e['status']} · ${e['responsible']}\n${e['notes']}').join('\n\n')}',
                    ),
                ],
                if (kind == RecordKind.observation)
                  ObservationPhotoField(
                    key: const ValueKey('full-width-field'),
                    photo: photo,
                    busy: saving || selectingPhoto,
                    onSelect: selectPhoto,
                    onRemove: () => setState(() => photo = null),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: FilledButton.icon(
            onPressed: saving || selectingPhoto ? null : save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              saving
                  ? (deleting ? 'Eliminando…' : 'Guardando…')
                  : 'Guardar registro',
            ),
          ),
        ),
      ),
    );
  }
}
