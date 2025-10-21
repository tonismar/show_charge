import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

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
  GoogleSignInAccount? _currentUser;
  String? _spreadsheetId;
  bool _loading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '390125749205-m44f9grqr1l5dpcp2fqm09l1tifouctt.apps.googleusercontent.com',
    scopes: [
      'https://www.googleapis.com/auth/spreadsheets',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() {
        _currentUser = account;
      });
    });
    _googleSignIn.signInSilently(); 
  }

  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      debugPrint('Error signing in: $error');
    }
  }

  Future<void> _createSpreadsheet() async {
    final authHeaders = await _currentUser?.authHeaders;
    if (authHeaders == null) return;

    final response = await http.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets'),
      headers: {
        'Authorization': authHeaders['Authorization']!,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'properties': {
          'title': 'Show Charges'
        },
        'sheets': [
          {
            'properties': {
              'title': 'Charges',
            },
            'data': {
              'rowData': [
                {
                  'values': [
                    {'userEnteredValue': {'stringValue': 'Description'}},
                    {'userEnteredValue': {'stringValue': 'Charge'}},
                    {'userEnteredValue': {'stringValue': 'Date'}},
                  ]
                }
              ]
            }
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _spreadsheetId = data['spreadsheetId'];
      });
    } else {
      debugPrint('Error creating spreadsheet: ${response.body}');
    }
  }

  Future<void> _submitData() async {
    if (_spreadsheetId == null) {
      await _createSpreadsheet();
      if (_spreadsheetId == null) return;
    }

    final authHeaders = await _currentUser?.authHeaders;
    if (authHeaders == null) return;

    final description = _descriptionController.text;
    final charge = _chargeController.text;

    if (description.isEmpty || charge.isEmpty) {
      return;
    }

    final range = 'Charges!A:C';
    final body = {
      'values': [
        [description, charge, DateTime.now().toIso8601String()]
      ]
    };

    setState(() {
      _loading = true;
    });

    final response = await http.post(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId/values/$range:append?valueInputOption=USER_ENTERED'),
      headers: {
        'Authorization': authHeaders['Authorization']!,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data submitted successfully')),
      );
      _descriptionController.clear();
      _chargeController.clear();
    } else {
      debugPrint('Error submitting data: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting data: ${response.body}')),
      );
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Sign in with Google', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _handleSignIn,
          ),
        ),
      );
    }
    
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