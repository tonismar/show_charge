# Show Charges 💰

A Flutter Web application for tracking and managing charges with Google Sheets integration.

## 📋 Overview

Show Charges is a simple and intuitive web application that allows users to track their charges by storing them in a Google Sheets spreadsheet. The app automatically manages spreadsheet creation and synchronization across multiple devices using the same Google account.

## ✨ Features

- 🔐 **Google Authentication**: Secure login with Google OAuth
- 📊 **Google Sheets Integration**: Automatic spreadsheet creation and data synchronization
- 🌐 **Multi-device Support**: Access the same spreadsheet from any device
- 💾 **Automatic Sync**: Finds existing spreadsheet or creates a new one automatically
- 🎨 **Modern UI**: Beautiful gradient design with Material 3 components
- ⚡ **Real-time Updates**: Submit charges instantly to your spreadsheet
- 🔗 **Quick Access**: Open your spreadsheet directly in Google Sheets with one click

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- A Google Cloud Project with the following APIs enabled:
  - Google Sheets API
  - Google Drive API
  - Google OAuth 2.0

### Google Cloud Configuration

1. Create a project in [Google Cloud Console](https://console.cloud.google.com/)
2. Enable the following APIs:
   - Google Sheets API
   - Google Drive API
3. Create OAuth 2.0 credentials (Web application)
4. Add authorized JavaScript origins and redirect URIs
5. Copy your Client ID

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/show-charges.git
cd show-charges
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure your Google OAuth Client ID in `google_auth_service.dart`:
```dart
static const String _clientId = 'YOUR_CLIENT_ID_HERE';
```

4. Run the application:
```bash
flutter run -d chrome
```

## 📦 Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  shared_preferences: ^2.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

## 🏗️ Project Structure
```
lib/
├── main.dart                 # Main application and UI
└── google_auth_service.dart  # Google OAuth authentication service
```

## 🔧 How It Works

### Authentication Flow

1. User clicks "Sign in with Google"
2. OAuth popup opens for Google authentication
3. User grants permissions (Sheets and Drive access)
4. Access token is stored and managed automatically

### Spreadsheet Management

1. **On First Login**: 
   - Searches for existing spreadsheet named "Show Charges"
   - If found, connects to it
   - If not found, creates a new one

2. **On Subsequent Logins**:
   - Automatically finds and connects to the existing "Show Charges" spreadsheet
   - Works across all devices using the same Google account

3. **Data Structure**:
   - Sheet name: "Charges"
   - Columns: Description | Charge | Date

### Data Submission

When you submit a charge:
1. Validates that spreadsheet exists and is accessible
2. Appends new row with: Description, Charge amount, and ISO timestamp
3. Shows success/error feedback
4. Clears input fields on success

## 🎯 Usage

1. **Sign In**: Click "Sign in with Google" and authenticate
2. **Add Charges**: Fill in description and charge amount
3. **Submit**: Click "Submit" to save to your spreadsheet
4. **View Spreadsheet**: Click "Open Spreadsheet" to view in Google Sheets
5. **Create New**: Click "New" to create an additional spreadsheet

## 🔒 Security & Privacy

- Uses OAuth 2.0 for secure authentication
- Only requests necessary permissions (Sheets and Drive)
- Access tokens are managed securely
- No sensitive data stored locally
- All data stored in user's own Google Drive

## 🌟 Features in Detail

### Automatic Spreadsheet Detection

The app uses Google Drive API to search for existing spreadsheets with the name "Show Charges". This ensures:
- No duplicate spreadsheets when using multiple devices
- Seamless experience across all devices
- Data consistency

### Error Handling

- Token expiration detection and re-authentication
- Deleted spreadsheet detection and recovery
- Network error handling with user feedback
- Input validation

### User Experience

- Loading indicators for async operations
- Success/error notifications
- Confirmation dialogs for destructive actions
- Responsive design

## 🐛 Troubleshooting

### "Not authenticated" error
- Sign out and sign in again
- Check if your OAuth credentials are correctly configured

### "Spreadsheet not found" error
- The app will automatically create a new spreadsheet
- Check if you have the necessary permissions in Google Cloud Console

### Authentication popup blocked
- Allow popups for the application domain
- Check browser popup blocker settings

## 📝 API Scopes Required
```
https://www.googleapis.com/auth/spreadsheets
https://www.googleapis.com/auth/drive.readonly
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

Your Name - [your@email.com](mailto:your@email.com)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Google for the Sheets and Drive APIs
- Material Design for the beautiful UI components

---

**Note**: This application requires an active internet connection and a Google account to function properly.