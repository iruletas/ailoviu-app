import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de Ailoviu')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.favorite),
            title: Text('Ailoviu'),
            subtitle: Text('Versión 0.1.0'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licencias de código abierto'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Ailoviu',
              applicationVersion: '0.1.0',
            ),
          ),
        ],
      ),
    );
  }
}