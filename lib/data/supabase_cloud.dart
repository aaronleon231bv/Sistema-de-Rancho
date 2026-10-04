import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ranch_store.dart';
import 'institutional_email.dart';

class RanchCloud {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qyqrfudtkeaemadzkgou.supabase.co',
  );
  // Publishable client key supplied by the project owner; protected by RLS.
  static const publicKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_8tHWYdzLn_l0n0H3x0QWDg_Lg1hrLxd',
  );
  Future<void>? _initialization;
  Future<void> initialize() =>
      _initialization ??= _initialize().catchError((Object error) {
        _initialization = null;
        throw error;
      });
  Future<void> _initialize() async {
    await Supabase.initialize(
      url: url,
      publishableKey: publicKey,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
    );
  }

  SupabaseClient get client => Supabase.instance.client;
  String? get accountId => client.auth.currentUser?.id;
  String? get email => client.auth.currentUser?.email;
  bool get hasInstitutionalSession =>
      accountId != null &&
      InstitutionalEmail.isValid(email) &&
      client.auth.currentUser?.emailConfirmedAt != null;
  Stream<AuthState> get authChanges => client.auth.onAuthStateChange;
  RanchRemote? get remote =>
      !hasInstitutionalSession ? null : SupabaseRanchRemote(client, accountId!);
}

class SupabaseRanchRemote implements RanchRemote {
  SupabaseRanchRemote(this.client, this.accountId);
  final SupabaseClient client;
  final String accountId;
  static const tables = ['parcels', 'crops', 'practices', 'observations'];
  void checkSession() {
    if (client.auth.currentUser?.id != accountId) {
      throw StateError('Inicia sesión de nuevo para sincronizar esta cuenta.');
    }
    if (!InstitutionalEmail.isValid(client.auth.currentUser?.email) ||
        client.auth.currentUser?.emailConfirmedAt == null) {
      throw StateError(
        'Inicia sesión con un correo institucional confirmado @${InstitutionalEmail.domain}.',
      );
    }
  }

  static Map<String, dynamic> toColumns(RanchRecord record) {
    final f = record.fields;
    return {
      'name': f['name'],
      'notes': f['notes'] ?? '',
      if (record.kind == RecordKind.parcel) ...{
        'area': f['area'],
        'location': f['location'],
      },
      if (record.kind != RecordKind.parcel) ...{
        'parcel_id': f['parcelId'],
        'date': f['date'],
      },
      if (record.kind == RecordKind.crop) ...{
        'variety': f['variety'] ?? '',
        'stage': f['stage'],
      },
      if (record.kind == RecordKind.practice ||
          record.kind == RecordKind.observation) ...{
        'crop_id': f['cropId'],
        'responsible': f['responsible'],
      },
      if (record.kind == RecordKind.practice) 'activity': f['activity'],
      if (record.kind == RecordKind.observation) 'severity': f['severity'],
    };
  }

  static RanchRecord fromColumns(RecordKind kind, Map<String, dynamic> row) =>
      RanchRecord(
        id: row['id'],
        kind: kind,
        revision: (row['revision'] as num).toInt(),
        baseRevision: (row['revision'] as num).toInt(),
        pending: false,
        fields: {
          'name': row['name'],
          'notes': row['notes'],
          if (kind == RecordKind.parcel) ...{
            'area': row['area'],
            'location': row['location'],
          },
          if (kind != RecordKind.parcel) ...{
            'parcelId': row['parcel_id'],
            'date': row['date'],
          },
          if (kind == RecordKind.crop) ...{
            'variety': row['variety'],
            'stage': row['stage'],
          },
          if (kind == RecordKind.practice ||
              kind == RecordKind.observation) ...{
            'cropId': row['crop_id'],
            'responsible': row['responsible'],
          },
          if (kind == RecordKind.practice) 'activity': row['activity'],
          if (kind == RecordKind.observation) 'severity': row['severity'],
        },
      );
  @override
  Future<void> send(RanchRecord record) async {
    checkSession();
    final table = tables[record.kind.index];
    final fields = toColumns(record);
    final existing = await client
        .from(table)
        .select()
        .eq('id', record.id)
        .eq('owner_id', accountId)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    checkSession();
    if (existing == null) {
      await client
          .from(table)
          .insert({
            'id': record.id,
            'owner_id': accountId,
            'revision': record.revision,
            ...fields,
          })
          .timeout(const Duration(seconds: 15));
      return;
    }
    // Retries acknowledge only the exact version and contents already persisted.
    final sameFields = fields.entries.every((e) {
      final remoteValue = existing[e.key];
      if (e.value is num && remoteValue is num) return e.value == remoteValue;
      return jsonEncode(e.value) == jsonEncode(remoteValue);
    });
    if (existing['revision'] == record.revision && sameFields) return;
    if (existing['revision'] != record.baseRevision) {
      throw StateError(
        'Conflicto en «${record.title}»: hay otra versión en Supabase. Tu cambio local se conserva.',
      );
    }
    final updated = await client
        .from(table)
        .update({...fields, 'revision': record.revision})
        .eq('id', record.id)
        .eq('owner_id', accountId)
        .eq('revision', record.baseRevision)
        .select('id')
        .timeout(const Duration(seconds: 15));
    if (updated.isEmpty) {
      throw StateError(
        'El registro cambió durante el envío. Intenta sincronizar de nuevo.',
      );
    }
  }

  @override
  Future<List<RanchRecord>> download() async {
    final result = <RanchRecord>[];
    for (final kind in RecordKind.values) {
      for (var offset = 0; ; offset += 500) {
        checkSession();
        final rows = await client
            .from(tables[kind.index])
            .select()
            .eq('owner_id', accountId)
            .order('id')
            .range(offset, offset + 499)
            .timeout(const Duration(seconds: 15));
        result.addAll(rows.map((row) => fromColumns(kind, row)));
        if (rows.length < 500) break;
      }
    }
    checkSession();
    return result;
  }
}
