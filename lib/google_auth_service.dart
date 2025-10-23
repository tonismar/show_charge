import 'dart:js_interop';
import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';

@JS('globalThis')
external GlobalThis get globalThis;

@JS()
@staticInterop
class GlobalThis {}

extension GlobalThisExtension on GlobalThis {
  external GoogleNamespace? get google;
}

@JS()
@staticInterop
class GoogleNamespace {}

extension GoogleNamespaceExtension on GoogleNamespace {
  external Accounts? get accounts;
}

@JS()
@staticInterop
class Accounts {}

extension AccountsExtension on Accounts {
  external GoogleAccountsId? get id;
  external GoogleAccountsOAuth2? get oauth2;
}

@JS()
@staticInterop
class GoogleAccountsId {}

extension GoogleAccountsIdExtension on GoogleAccountsId {
  external void initialize(IdConfig config);
  external void prompt([JSFunction? callback]);
  external void renderButton(JSAny element, ButtonConfig config);
}

@JS()
@staticInterop
class GoogleAccountsOAuth2 {}

extension GoogleAccountsOAuth2Extension on GoogleAccountsOAuth2 {
  external TokenClient initTokenClient(TokenClientConfig config);
}

@JS()
@staticInterop
class TokenClient {}

extension TokenClientExtension on TokenClient {
  external void requestAccessToken([RequestOptions? options]);
}

@JS()
@anonymous
@staticInterop
class IdConfig {
  external factory IdConfig({
    String client_id,
    JSFunction? callback,
    String? context,
    String? ux_mode,
    JSFunction? native_callback,
  });
}

@JS()
@anonymous
@staticInterop
class ButtonConfig {
  external factory ButtonConfig({
    String? theme,
    String? size,
    String? type,
    String? shape,
    String? text,
    String? logo_alignment,
  });
}

@JS()
@anonymous
@staticInterop
class TokenClientConfig {
  external factory TokenClientConfig({
    String client_id,
    JSFunction callback,
    String scope,
    String? prompt,
  });
}

@JS()
@anonymous
@staticInterop
class RequestOptions {
  external factory RequestOptions({String? hint});
}

@JS()
@staticInterop
class CredentialResponse {}

extension CredentialResponseExtension on CredentialResponse {
  external String get credential;
  external String? get select_by;
}

@JS()
@staticInterop
class TokenResponse {}

extension TokenResponseExtension on TokenResponse {
  external String get access_token;
  external String get token_type;
  external int get expires_in;
  external String? get scope;
  external String? get error;
}

class GoogleAuthService {
  static const String clientId = '390125749205-m44f9grqr1l5dpcp2fqm09l1tifouctt.apps.googleusercontent.com';
  static const String scope = 'https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive.file';
  
  String? _accessToken;
  DateTime? _tokenExpiry;
  TokenClient? _tokenClient;
  Function()? _onAuthStateChanged;
  bool _initialized = false;
  String? _initError;
  
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null && !_isTokenExpired();
  bool get isInitialized => _initialized;
  String? get initializationError => _initError;

  void setAuthStateChangeCallback(Function() callback) {
    _onAuthStateChanged = callback;
  }

  bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!);
  }

  bool _checkGoogleApiAvailable() {
    try {
      final google = globalThis.google;
      if (google == null) return false;
      
      final accounts = google.accounts;
      if (accounts == null) return false;
      
      final oauth2 = accounts.oauth2;
      if (oauth2 == null) return false;
      
      return true;
    } catch (e) {
      print('Error checking Google API: $e');
      return false;
    }
  }

  Future<void> initialize() async {
    if (_initialized) {
      print('Already initialized');
      return;
    }

    print('Starting Google Auth initialization...');
    
    // Carrega token salvo
    await _loadSavedToken();
    
    try {
      // Aguarda o Google Identity Services estar disponível
      int attempts = 0;
      const maxAttempts = 30; // 15 segundos no máximo
      
      while (attempts < maxAttempts) {
        if (_checkGoogleApiAvailable()) {
          print('Google API available after ${attempts + 1} attempts');
          break;
        }
        
        if (attempts == 0) {
          print('Waiting for Google Identity Services to load...');
        }
        
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }
      
      if (!_checkGoogleApiAvailable()) {
        final error = 'Google Identity Services failed to load after ${maxAttempts * 0.5} seconds. Please check your internet connection and reload the page.';
        print('ERROR: $error');
        _initError = error;
        _initialized = false;
        return;
      }
      
      print('Initializing token client...');
      
      // Inicializa o cliente de token OAuth2
      _tokenClient = globalThis.google!.accounts!.oauth2!.initTokenClient(
        TokenClientConfig(
          client_id: clientId,
          callback: _handleTokenResponse.toJS,
          scope: scope,
          prompt: '', // Vazio para não forçar prompt toda vez
        ),
      );
      
      _initialized = true;
      _initError = null;
      print('✓ Google Auth initialized successfully');
      
    } catch (e, stackTrace) {
      final error = 'Error initializing Google Auth: $e';
      print(error);
      print('Stack trace: $stackTrace');
      _initError = error;
      _initialized = false;
    }
  }

  Future<void> _loadSavedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('google_access_token');
      final expiryStr = prefs.getString('google_token_expiry');
      
      if (token != null && expiryStr != null) {
        _accessToken = token;
        _tokenExpiry = DateTime.parse(expiryStr);
        
        // Verifica se o token expirou
        if (_isTokenExpired()) {
          print('Saved token expired, clearing...');
          _accessToken = null;
          _tokenExpiry = null;
          await _clearSavedToken();
        } else {
          print('Loaded valid token from storage');
        }
      }
    } catch (e) {
      print('Error loading saved token: $e');
    }
  }

  Future<void> _saveToken(String token, int expiresIn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = token;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
      
      await prefs.setString('google_access_token', token);
      await prefs.setString('google_token_expiry', _tokenExpiry!.toIso8601String());
      
      print('Token saved successfully');
    } catch (e) {
      print('Error saving token: $e');
    }
  }

  Future<void> _clearSavedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('google_access_token');
      await prefs.remove('google_token_expiry');
      _accessToken = null;
      _tokenExpiry = null;
      print('Token cleared');
    } catch (e) {
      print('Error clearing token: $e');
    }
  }

  void _handleTokenResponse(TokenResponse response) {
    try {
      if (response.error != null) {
        print('Error getting token: ${response.error}');
        return;
      }
      
      print('Token received successfully');
      
      _saveToken(response.access_token, response.expires_in).then((_) {
        // Chama o callback após salvar o token
        print('Calling auth state changed callback');
        _onAuthStateChanged?.call();
      });
    } catch (e, stackTrace) {
      print('Error handling token response: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> signIn() async {
    try {
      print('Sign in requested');
      
      if (!_initialized) {
        print('Not initialized, initializing now...');
        await initialize();
      }
      
      if (!_initialized) {
        throw Exception(_initError ?? 'Failed to initialize Google Auth. Please reload the page.');
      }
      
      // Tenta usar token existente se ainda válido
      if (isAuthenticated) {
        print('Already authenticated with valid token');
        return;
      }
      
      if (_tokenClient == null) {
        throw Exception('Token client not initialized. Please reload the page.');
      }
      
      print('Requesting access token...');
      // Solicita novo token
      _tokenClient!.requestAccessToken();
      
    } catch (e, stackTrace) {
      print('Error in signIn: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      print('Sign out requested');
      await _clearSavedToken();
      
      // Revoga o token
      if (_accessToken != null) {
        html.window.open(
          'https://accounts.google.com/o/oauth2/revoke?token=$_accessToken',
          '_blank',
        );
      }
      
      // Notifica sobre mudança de estado
      _onAuthStateChanged?.call();
      
      print('Signed out successfully');
    } catch (e) {
      print('Error in signOut: $e');
    }
  }

  Map<String, String>? getAuthHeaders() {
    if (!isAuthenticated) return null;
    
    return {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    };
  }
}