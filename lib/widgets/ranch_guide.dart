import 'package:flutter/material.dart';

import '../data/ranch_store.dart';

const recordDescriptions = {
  RecordKind.parcel: 'El lugar donde trabajas: nombre, superficie y ubicación.',
  RecordKind.crop: 'Lo que siembras en una parcela: cultivo, variedad y ciclo.',
  RecordKind.practice:
      'Una labor del campo: riego, fertilización, siembra o cosecha.',
  RecordKind.observation:
      'Algo que detectaste y necesita seguimiento: plagas, daños o cambios en el cultivo.',
};

const formExplanations = {
  RecordKind.parcel:
      'Registra un espacio de trabajo del rancho. Después podrás relacionar sus cultivos y labores.',
  RecordKind.crop:
      'Registra una siembra y su ciclo en una parcela. Así podrás consultar las labores y cosechas de esa temporada.',
  RecordKind.practice:
      'Anota qué trabajo se hizo, cuándo, dónde y quién lo realizó. Elige Pendiente para programarlo o Realizada para registrar su ejecución.',
  RecordKind.observation:
      'Describe lo que detectaste en el campo. Puedes adjuntar una foto y registrar las acciones hasta resolver la situación.',
};

void showRanchGuide(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 760),
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Guía de la bitácora',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar guía',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '¿Para qué sirve?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para llevar el registro del trabajo de campo: dónde trabajaste, '
              'qué hiciste, quién participó y qué resultados obtuviste. '
              'Te ayuda a consultar gastos, cosechas y problemas pendientes de cada parcela.',
            ),
            const SizedBox(height: 20),
            const Text(
              'Empieza en este orden',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            for (final item in const [
              (
                '1',
                'Registra una parcela',
                'Ejemplo: Parcela norte, 2.5 hectáreas, junto al pozo.',
              ),
              (
                '2',
                'Agrega el cultivo, si corresponde',
                'Ejemplo: Maíz, ciclo Primavera 2026. Crea un cultivo para cada nueva siembra.',
              ),
              (
                '3',
                'Anota el trabajo y lo observado',
                'Registra las labores como prácticas y los problemas o cambios como observaciones.',
              ),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(item.$1)),
                title: Text(item.$2),
                subtitle: Text(item.$3),
              ),
            const Text(
              'Puedes registrar prácticas y observaciones sin un cultivo específico; siempre se relacionan con una parcela.',
            ),
            const SizedBox(height: 20),
            const Text(
              '¿Práctica u observación?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.agriculture_outlined),
              title: Text('Práctica = una labor'),
              subtitle: Text(
                '“Regué el maíz durante dos horas”. Anota responsable, insumos y costos. '
                'En una cosecha, registra los kilos y la superficie cosechada.',
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.visibility_outlined),
              title: Text('Observación = algo que detectaste'),
              subtitle: Text(
                '“Encontré hojas amarillas”. Adjunta una fotografía, indica el nivel de atención '
                'y registra el seguimiento hasta resolverlo.',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Planea y consulta resultados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.calendar_month_outlined),
              title: Text('Calendario de tareas'),
              subtitle: Text(
                'Programa labores con fecha y responsable. Al realizarlas, actualiza su estado y fecha.',
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.history),
              title: Text('Historial y reportes'),
              subtitle: Text(
                'Consulta lo ocurrido por parcela y ciclo. Revisa gastos y cosechas y guarda reportes PDF o Excel.',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tus registros se guardan en este dispositivo, incluso sin internet. '
              'Usa Respaldos y comprobación para guardar una copia en archivo o restaurarla.',
            ),
          ],
        ),
      ),
    ),
  );
}
