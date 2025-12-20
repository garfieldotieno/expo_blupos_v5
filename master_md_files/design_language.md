# Design Language - Prototype APK

This document outlines the design language for the prototype APK with three core pages: Page1 (Activation), Page2 (Reports), and Page3 (Wallet).

## Color Palette

### Primary Colors
- **Primary Blue**: `#182A62` - Main brand color for buttons and headers
- **Secondary Yellow**: `#FEC620` - Secondary color for highlights and info panels
- **Background**: `#D7D7D7` - Light gray background
- **Card Background**: `#FFFFFF` - White for containers

### Text Colors
- **Primary Text**: `#000000` - Main text color
- **White Text**: `#FFFFFF` - Text on dark backgrounds

## Typography

### Font Family
- **Primary Font**: Google Fonts Poppins

### Text Styles
- **Title**: 24px, Bold, Black
- **Body**: 16px, Regular, Black
- **Button**: 16px, Medium, White

## Layout Principles

### Screen Structure
- **Scaffold** with AppBar and body
- **SafeArea** for device compatibility
- **Column** layouts with centered content
- **Padding**: 16px standard spacing

### Component Patterns

#### Primary Button
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFF182A62),
    foregroundColor: Colors.white,
    minimumSize: Size(double.infinity, 50),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
  child: Text('Button Text'),
)
```

#### Content Container
```dart
Container(
  padding: EdgeInsets.all(16),
  margin: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 4,
        offset: Offset(0, 2),
      ),
    ],
  ),
  child: /* content */,
)
```

## Page Specifications

### Page1 (Activation)
- **Purpose**: Device activation and initial setup
- **Layout**: Centered content with activation form
- **Components**:
  - Title: "Activate Device"
  - Input fields for activation code
  - Primary button: "Activate"
  - Status text for activation state

### Page2 (Reports)
- **Purpose**: View transaction reports and analytics
- **Layout**: List view with report cards
- **Components**:
  - Title: "Reports"
  - Report cards with date, amount, status
  - Filter options (date range, status)
  - Export button

### Page3 (Wallet)
- **Purpose**: View balance and transaction history
- **Layout**: Balance display with transaction list
- **Components**:
  - Balance display in prominent card
  - Transaction history list
  - Transaction detail cards
  - Refresh button

## Minimal MVP Page Layouts

### Page1 (Activation)
- **Layout**: Centered AppBar, centered rounded square container, button(s) below
- **Components**:
  - AppBar: Centered title "Activation"
  - Main Content: Centered rounded square (white container with border radius)
  - Container Content: Activation form with input field for activation code
  - Below Container: Primary blue "Activate" button
- **Navigation**: Bottom navigation tabs

### Page2 (Reports)
- **Layout**: Centered AppBar, centered rounded square container, buttons below for generate
- **Components**:
  - AppBar: Centered title "Reports"
  - Main Content: Centered rounded square (white container with border radius)
  - Container Content: Report summary/info display
  - Below Container: "Generate Report" button in primary blue
- **Navigation**: Bottom navigation tabs

### Page3 (Wallet)
- **Layout**: Centered AppBar, rectangular balance display (credit card style), chronological transaction listing
- **Components**:
  - AppBar: Centered title "Wallet"
  - Main Content: Rectangular balance card (credit card style - yellow background)
  - Balance Display: Large balance amount, card number/account info
  - Below Balance: Chronological list of transactions (newest first)
  - Transaction Items: Simple rows with date, description, amount, status
- **Navigation**: Bottom navigation tabs

### Component Hierarchy

```
App Structure
├── Scaffold
│   ├── AppBar (Centered Title)
│   └── Body
│       └── SafeArea
│           └── Column (Centered)
│               ├── SizedBox (Spacing)
│               ├── Container (Rounded Square for Page1/Page2)
│               │   └── Form/Content
│               ├── ElevatedButton (Below container)
│               └── ListView (Transactions for Page3)
```

## Navigation

### Bottom Navigation Bar
- **Page1**: Activation tab
- **Page2**: Reports tab
- **Page3**: Wallet tab
- **Active Color**: `#182A62`
- **Inactive Color**: `#666666`

### Navigation Flow
```
Page1 (Activation) ──► Page3 (Wallet)
    ↘
     Page2 (Reports) ↔ Page3 (Wallet)
```

## Technical Specifications

### Micro-Server Integration
The APK must include a lightweight micro-server component that enables:
- **Local Network Communication**: HTTP server running on device for peer-to-peer connectivity
- **API Endpoints**: RESTful endpoints for transaction processing and data synchronization
- **Background Service**: Persistent server operation independent of UI state
- **Security**: Basic authentication and encrypted communication channels
- **Port Management**: Automatic port allocation and conflict resolution

#### Micro-Server UI Indicators
- **Status Display**: Server status indicator in Page1 (Activation) showing online/offline state
- **Connection Status**: Visual indicator showing active connections and network availability
- **Error Handling**: Clear error messages for server startup failures or network issues

### SMS Parsing Integration
The app must automatically parse incoming SMS messages for transaction processing:
- **Permission Requirements**: SMS_READ permission with user consent flow
- **Message Filtering**: Intelligent filtering for transaction-related SMS (keywords: payment, transaction, received, sent)
- **Data Extraction**: Automatic parsing of amount, sender, timestamp, and reference information
- **Real-time Processing**: Background service monitoring SMS inbox for new messages
- **Security**: Encrypted storage of parsed transaction data

#### SMS Parsing UI Components
- **Permission Request**: Clear dialog explaining SMS access needs during activation
- **Processing Status**: Loading indicators when parsing SMS data
- **Transaction Confirmation**: User verification of auto-parsed transactions before acceptance
- **Manual Override**: Option to manually edit or correct parsed transaction data

### Integration Flow
```
SMS Received → Auto Parse → Validation → User Confirmation → Transaction Recording → Server Sync
```

## Implementation Guidelines

### Theme Configuration
```dart
MaterialApp(
  theme: ThemeData(
    primaryColor: Color(0xFF182A62),
    scaffoldBackgroundColor: Color(0xFFD7D7D7),
    fontFamily: 'Poppins',
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF182A62),
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  ),
)
```

### Consistent Patterns
- Use 16px padding for all containers
- Apply 8px border radius for buttons and cards
- Maintain consistent spacing with 8px increments
- Use primary blue for all interactive elements
- White text on blue backgrounds, black text on white backgrounds

### Permission Management
- Request SMS permissions during Page1 activation flow
- Display clear rationale for required permissions
- Handle permission denials gracefully with fallback options

### Background Services
- Implement micro-server as foreground service with notification
- SMS parsing as background service with battery optimization
- Provide user controls to start/stop services as needed

This design language provides a clean, minimal interface focused on the core functionality of the three-page prototype APK with integrated micro-server and SMS parsing capabilities.
