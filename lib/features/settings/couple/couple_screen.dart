import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_providers.dart';

class CoupleScreen extends ConsumerWidget {
  const CoupleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final date = settings.startDate;

    return Scaffold(
      appBar: AppBar(title: const Text('Datos de la pareja')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Fecha de inicio',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(
              date == null
                  ? 'Sin configurar'
                  : '${date.day.toString().padLeft(2, '0')}/'
                      '${date.month.toString().padLeft(2, '0')}/${date.year}',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                await notifier.setStartDate(picked);
              }
            },
          ),
          if (date != null)
            TextButton.icon(
              onPressed: () => notifier.setStartDate(null),
              icon: const Icon(Icons.clear),
              label: const Text('Borrar fecha'),
            ),
        ],
      ),
    );
  }
}