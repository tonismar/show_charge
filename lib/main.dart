import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html;
import 'google_auth_service.dart';

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
  final _authService = GoogleAuthService();
  
  // Nome padrão da planilha (sem data para manter o mesmo nome)
  static const String _spreadsheetName = 'Show Charges';
  
  String? _spreadsheetId;
  bool _loading = false;
  bool _initializing = true;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _authService.setAuthStateChangeCallback(_onAuthStateChanged);
    _initializeAuth();
  }

  void _onAuthStateChanged() {
    // Callback chamado quando o estado de autenticação muda
    if (_authService.isAuthenticated) {
      _getUserInfo().then((_) async {
        // Após obter o email, busca a planilha existente
        await _findExistingSpreadsheet();
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signed in successfully')),
          );
        }
      });
    } else {
      // Se não está autenticado, atualiza a UI
      if (mounted) {
        setState(() {
          _userEmail = null;
          _spreadsheetId = null;
        });
      }
    }
  }

  Future<void> _initializeAuth() async {
    await _authService.initialize();
    
    // Carrega dados salvos
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('userEmail');
    
    print('=== Initialization ===');
    print('Saved email: $savedEmail');
    print('Is authenticated: ${_authService.isAuthenticated}');

    setState(() {
      _userEmail = savedEmail;
      _initializing = false;
    });

    // Verifica se houve erro na inicialização
    if (!_authService.isInitialized && _authService.initializationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_authService.initializationError!),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Reload',
              onPressed: () {
                html.window.location.reload();
              },
            ),
          ),
        );
      }
    }

    // Se estiver autenticado, atualiza info do usuário e busca planilha
    if (_authService.isAuthenticated) {
      if (_userEmail == null) {
        await _getUserInfo();
      }
      await _findExistingSpreadsheet();
    }
  }

  Future<void> _handleSignIn() async {
    try {
      await _authService.signIn();
      // O callback _onAuthStateChanged será chamado automaticamente
      // quando o token for obtido com sucesso
    } catch (error) {
      debugPrint('Error signing in: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing in: $error')),
        );
      }
    }
  }

  Future<void> _getUserInfo() async {
    final headers = _authService.getAuthHeaders();
    if (headers == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final email = data['email'] as String;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userEmail', email);
        
        setState(() {
          _userEmail = email;
        });
      }
    } catch (error) {
      debugPrint('Error getting user info: $error');
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userEmail');
    
    setState(() {
      _spreadsheetId = null;
      _userEmail = null;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out successfully')),
      );
    }
  }

  Future<void> _findExistingSpreadsheet() async {
    final headers = _authService.getAuthHeaders();
    if (headers == null) {
      print('✗ No auth headers available');
      return;
    }

    print('=== Searching for existing spreadsheet "$_spreadsheetName" ===');

    try {
      // Busca por arquivos com o nome específico no Google Drive
      final response = await http.get(
        Uri.parse(
          'https://www.googleapis.com/drive/v3/files?'
          'q=name="$_spreadsheetName" and mimeType="application/vnd.google-apps.spreadsheet" and trashed=false'
          '&fields=files(id,name,createdTime)'
          '&orderBy=createdTime desc'
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = data['files'] as List;
        
        if (files.isNotEmpty) {
          // Pega a planilha mais recente com esse nome
          final spreadsheetId = files[0]['id'] as String;
          print('✓ Found existing spreadsheet: $spreadsheetId');
          
          setState(() {
            _spreadsheetId = spreadsheetId;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connected to existing spreadsheet'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          print('No existing spreadsheet found with name "$_spreadsheetName"');
        }
      } else {
        print('Error searching for spreadsheet: ${response.statusCode}');
      }
    } catch (error) {
      print('Exception searching for spreadsheet: $error');
    }
  }

  Future<void> _createSpreadsheet() async {
    final headers = _authService.getAuthHeaders();
    if (headers == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not authenticated. Please sign in again.')),
        );
      }
      return;
    }

    // Primeiro verifica se já existe uma planilha
    await _findExistingSpreadsheet();
    if (_spreadsheetId != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Using existing spreadsheet'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    print('Creating new spreadsheet...');

    try {
      final response = await http.post(
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets'),
        headers: headers,
        body: jsonEncode({
          'properties': {
            'title': _spreadsheetName
          },
          'sheets': [
            {
              'properties': {
                'title': 'Charges',
              },
              'data': [
                {
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
              ]
            }
          ]
        }),
      );

      print('Create spreadsheet response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final spreadsheetId = data['spreadsheetId'];
        
        print('Spreadsheet created successfully: $spreadsheetId');
        
        setState(() {
          _spreadsheetId = spreadsheetId;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Spreadsheet created successfully!\nID: $spreadsheetId'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('Error creating spreadsheet: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating spreadsheet: ${response.statusCode}\n${response.body}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (error) {
      print('Exception creating spreadsheet: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _ensureSpreadsheetExists() async {
    print('=== _ensureSpreadsheetExists called ===');
    print('Current _spreadsheetId in state: $_spreadsheetId');
    
    final headers = _authService.getAuthHeaders();
    if (headers == null) {
      print('✗ No auth headers available');
      throw Exception('Not authenticated');
    }
    
    // Se tem spreadsheetId no estado, verifica se ainda é válido
    if (_spreadsheetId != null) {
      print('Checking if current spreadsheet exists: $_spreadsheetId');
      try {
        final checkResponse = await http.get(
          Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId'),
          headers: headers,
        );
        
        print('Check response status: ${checkResponse.statusCode}');
        
        if (checkResponse.statusCode == 200) {
          print('✓ Spreadsheet exists and is valid');
          return;
        } else {
          print('✗ Spreadsheet not found (${checkResponse.statusCode}), will search for existing or create new one');
          setState(() {
            _spreadsheetId = null;
          });
        }
      } catch (e) {
        print('Error checking spreadsheet: $e');
        setState(() {
          _spreadsheetId = null;
        });
      }
    }
    
    // Busca por planilha existente com o nome padrão
    print('Searching for existing spreadsheet...');
    await _findExistingSpreadsheet();
    
    // Se encontrou, retorna
    if (_spreadsheetId != null) {
      print('✓ Found existing spreadsheet: $_spreadsheetId');
      return;
    }
    
    // Se não encontrou, cria nova planilha
    print('No valid spreadsheet found, creating new one...');
    await _createSpreadsheet();
    
    if (_spreadsheetId == null) {
      throw Exception('Failed to create spreadsheet');
    }
    
    print('After create, _spreadsheetId: $_spreadsheetId');
  }

  Future<void> _submitData() async {
    print('=== _submitData called ===');
    print('State _spreadsheetId BEFORE ensure: $_spreadsheetId');
    
    final description = _descriptionController.text.trim();
    final charge = _chargeController.text.trim();

    if (description.isEmpty || charge.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')),
        );
      }
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // Garante que existe uma planilha válida
      await _ensureSpreadsheetExists();
      
      print('State _spreadsheetId AFTER ensure: $_spreadsheetId');
      
      if (_spreadsheetId == null) {
        throw Exception('Spreadsheet ID is null after ensure');
      }

      final headers = _authService.getAuthHeaders();
      if (headers == null) {
        throw Exception('No auth headers');
      }

      final range = 'Charges!A:C';
      final body = {
        'values': [
          [description, charge, DateTime.now().toIso8601String()]
        ]
      };

      print('Submitting data to spreadsheet: $_spreadsheetId');

      final response = await http.post(
        Uri.parse(
          'https://sheets.googleapis.com/v4/spreadsheets/$_spreadsheetId/values/$range:append?valueInputOption=USER_ENTERED'),
        headers: headers,
        body: jsonEncode(body),
      );

      print('Submit response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✓ Data submitted successfully');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data submitted successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        _descriptionController.clear();
        _chargeController.clear();
      } else if (response.statusCode == 401) {
        // Token expirou
        print('✗ Token expired');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired. Please sign in again.')),
          );
        }
        await _handleSignOut();
      } else if (response.statusCode == 404) {
        // Planilha foi deletada durante a submissão
        print('✗ Spreadsheet was deleted during submission');
        setState(() {
          _spreadsheetId = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Spreadsheet was deleted. Click Submit again to create a new one.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        print('✗ Error submitting data: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (error) {
      print('✗ Exception in _submitData: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _openSpreadsheet() {
    if (_spreadsheetId != null) {
      final url = 'https://docs.google.com/spreadsheets/d/$_spreadsheetId/edit';
      print('Opening spreadsheet: $url');
      
      // Para Flutter Web
      html.window.open(url, '_blank');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening spreadsheet in new tab...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_authService.isAuthenticated) {
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
            child: Card(
              elevation: 8,
              margin: const EdgeInsets.all(32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 80,
                      color: Colors.indigo,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome to Show Charges',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sign in to start tracking your charges',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text(
                        'Sign in with Google',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _handleSignIn,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Show Charges'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_userEmail != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  _userEmail!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
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
                padding: const EdgeInsets.all(32.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Add Charge',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
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
                      const SizedBox(height: 20),
                      TextField(
                        controller: _chargeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Charge',
                          prefixIcon: const Icon(Icons.attach_money_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.indigo,
                              )
                            : ElevatedButton.icon(
                                key: const ValueKey('submitButton'),
                                icon: const Icon(Icons.save),
                                label: const Text(
                                  'Submit',
                                  style: TextStyle(fontSize: 18),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                                onPressed: _submitData,
                              ),
                      ),
                      if (_spreadsheetId != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open Spreadsheet'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _openSpreadsheet,
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('New'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Create New Spreadsheet?'),
                                    content: const Text(
                                      'This will create a new spreadsheet with the name "Show Charges". The current one will remain in your Google Drive.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Create New'),
                                      ),
                                    ],
                                  ),
                                );
                                
                                if (confirm == true) {
                                  setState(() {
                                    _spreadsheetId = null;
                                  });
                                  await _createSpreadsheet();
                                }
                              },
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Create Spreadsheet'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _createSpreadsheet,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _chargeController.dispose();
    super.dispose();
  }
}