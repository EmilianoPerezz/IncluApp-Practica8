import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Emulador Android: 10.0.2.2 apunta al localhost de la computadora.
// En un teléfono físico, reemplaza esta dirección por la IPv4 de tu PC.
const String baseUrl = 'http://10.0.2.2:3000';

void main() {
  runApp(const IncluApp());
}

class IncluApp extends StatelessWidget {
  const IncluApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IncluApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const InicioPage(),
    );
  }
}

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  final descripcionCtrl = TextEditingController();
  final ubicacionCtrl = TextEditingController();
  bool cargando = false;
  String resultado = '';
  String mensaje = '';
  List<dynamic> incidencias = [];

  Future<void> enviarReporte() async {
    final descripcion = descripcionCtrl.text.trim();
    if (descripcion.length < 10) {
      setState(() => mensaje = 'Escribe una descripción de al menos 10 caracteres.');
      return;
    }

    setState(() {
      cargando = true;
      mensaje = '';
      resultado = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/incidencias'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'descripcion': descripcion,
          'ubicacion': ubicacionCtrl.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        setState(() {
          resultado = data['analisis_ia'] ?? 'Reporte registrado.';
          mensaje = 'Reporte #${data['id']} guardado correctamente.';
          descripcionCtrl.clear();
        });
        await cargarReportes();
      } else {
        setState(() => mensaje = data['error'] ?? 'Error al enviar el reporte.');
      }
    } catch (e) {
      setState(() => mensaje =
          'No se pudo conectar con el servidor. Verifica la URL y la red.');
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> cargarReportes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/incidencias'),
      );
      if (response.statusCode == 200) {
        setState(() => incidencias = jsonDecode(response.body));
      }
    } catch (_) {
      // El mensaje de conexión se mostrará al intentar enviar el reporte.
    }
  }

  @override
  void initState() {
    super.initState();
    cargarReportes();
  }

  @override
  void dispose() {
    descripcionCtrl.dispose();
    ubicacionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IncluApp | Reportes de accesibilidad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Reporta una barrera de accesibilidad',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Describe la situación. Gemini generará una orientación '
            'para apoyar su clasificación.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descripcionCtrl,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Descripción del problema',
              hintText: 'Ej. La rampa está bloqueada...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ubicacionCtrl,
            decoration: const InputDecoration(
              labelText: 'Ubicación (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: cargando ? null : enviarReporte,
            icon: const Icon(Icons.send),
            label: Text(cargando ? 'Procesando...' : 'Enviar reporte'),
          ),
          if (mensaje.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(mensaje, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
          if (resultado.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Análisis de Gemini',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(resultado),
                    const SizedBox(height: 8),
                    const Text(
                      'Orientación automatizada; requiere validación humana.',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: 32),
          const Text('Reportes registrados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          for (final item in incidencias)
            Card(
              child: ListTile(
                title: Text(item['descripcion'] ?? ''),
                subtitle: Text(
                  '${item['ubicacion'] ?? 'Sin ubicación'}\n'
                  '${item['fecha'] ?? ''}',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }
}
