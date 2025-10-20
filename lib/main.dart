import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Show Charges',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          bodyMedium: TextStyle(fontSize: 16)
        )
      ),  
      home: const FormScreen(),
    );
  }
}

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _descriptionController = TextEditingController();
  final _chargeController = TextEditingController();
  bool _loading = false;

  final String _spreadsheetId = '1D0TXCXJb_iAbokNpp6by8Orxv9OTtLj8ulWK3GhRRrw';

  Future<void> _submitData() async {
    final description = _descriptionController.text;
    final charge = _chargeController.text;

    if (description.isEmpty || charge.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final credentialsJson = json.decode(await rootBundle.loadString('assets/flutter-474004-aad09c754a74.json'));
      
      final accountCredentials = ServiceAccountCredentials.fromJson(credentialsJson);
      final scopes = [
        sheets.SheetsApi.spreadsheetsScope,
        'https://www.googleapis.com/auth/drive.file',
      ];

      final client = await clientViaServiceAccount(accountCredentials, scopes);

      final sheetsApi = sheets.SheetsApi(client);

      final now = DateTime.now().toString();

      final values = [
        [description, charge, now],
      ];

      final valueRange = sheets.ValueRange(values: values);

      await sheetsApi.spreadsheets.values.append(
        valueRange,
        _spreadsheetId,
        'A:C',
        valueInputOption: 'RAW',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data submitted successfully')),
      );

      _descriptionController.clear();
      _chargeController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting data: $e')),
      );
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3F51B5), Color(0xFF2196F3)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Add Charge', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _chargeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Charge',
                        prefixIcon: const Icon(Icons.attach_money_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.indigo)
                          : ElevatedButton.icon(
                              key: const ValueKey('submitButton'),
                              icon: const Icon(Icons.save),
                              label: const Text('Submit', style: TextStyle(fontSize: 18)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _submitData,
                            ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}