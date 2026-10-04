import 'package:flutter/material.dart';

/// Official header logos bundled locally for offline access.
class InstitutionalBrand extends StatelessWidget {
  const InstitutionalBrand({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E6EE)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 420 ? 40.0 : 64.0;
        return Row(
          children: [
            Expanded(
              flex: 5,
              child: Image.asset(
                'assets/logos/educacion.png',
                height: height,
                fit: BoxFit.contain,
                semanticLabel: 'Secretaría de Educación Pública',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Image.asset(
                'assets/logos/tecnm.jpg',
                height: height,
                fit: BoxFit.contain,
                semanticLabel: 'Tecnológico Nacional de México',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Image.asset(
                'assets/logos/china.jpg',
                height: height,
                fit: BoxFit.contain,
                semanticLabel: 'Instituto Tecnológico de Chiná',
              ),
            ),
          ],
        );
      },
    ),
  );
}
