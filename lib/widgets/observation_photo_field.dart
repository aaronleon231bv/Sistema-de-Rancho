import 'package:flutter/material.dart';

import '../data/observation_photo.dart';

class ObservationPhotoField extends StatelessWidget {
  const ObservationPhotoField({
    super.key,
    required this.photo,
    required this.busy,
    required this.onSelect,
    required this.onRemove,
  });

  final ObservationPhoto? photo;
  final bool busy;
  final VoidCallback onSelect, onRemove;

  Widget image() => Image.memory(
    photo!.bytes,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) =>
        const Center(child: Text('No se pudo mostrar la fotografía.')),
  );

  void viewPhoto(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Fotografía de la observación')),
          body: SafeArea(
            child: SizedBox.expand(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(child: image()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Fotografía (opcional)',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (photo != null) ...[
        Semantics(
          button: true,
          label: 'Ver fotografía ampliada',
          child: InkWell(
            onTap: busy ? null : () => viewPhoto(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 220,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: image(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(photo!.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: busy ? null : onSelect,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(photo == null ? 'Adjuntar foto' : 'Reemplazar foto'),
          ),
          if (photo != null) ...[
            TextButton.icon(
              onPressed: busy ? null : () => viewPhoto(context),
              icon: const Icon(Icons.zoom_in),
              label: const Text('Ampliar foto'),
            ),
            TextButton.icon(
              onPressed: busy ? null : onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Quitar foto'),
            ),
          ],
        ],
      ),
      if (busy) const LinearProgressIndicator(),
      const SizedBox(height: 8),
      const Text(
        'Una fotografía de hasta 5 MB. Se conservará sin internet al guardar el registro.',
      ),
    ],
  );
}
