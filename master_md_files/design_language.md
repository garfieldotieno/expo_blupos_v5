- **Yellow Card Content**: Updates based on license state

## Payments Interface Master Interface - Exporting Prototype APK

### Overview
This section outlines the integration of the mobile APK payment interface into the master Python BluPOS web application. A new section will be introduced in the Python BluPOS project, similar to the existing license management section, featuring a blank canvas with two yellow solid rectangles for structured content organization.

### Master Interface Layout
- **Section Position**: Below license management section in Python BluPOS web application
- **Parent Container**: White-ish background (`#F8F9FA` or similar light tone)
- **Layout**: Two-column responsive grid system matching application structure
- **Spacing**: Consistent padding around split content containers

#### Rectangle Specifications
- **Rectangle 1 (APK Interface Replication)**:
  - **Width**: 1/3 of available space (calibrated)
  - **Purpose**: Direct replication of mobile APK payment interface
  - **Content**: Embedded iframe/WebView of Flutter Web module
  - **Background**: Yellow (`#FEC620`) solid fill
  - **Padding**: Consistent padding around container edges

- **Rectangle 2 (Future Content)**:
  - **Width**: 2/3 of available space (calibrated)
  - **Purpose**: Reserved for additional payment features and analytics
  - **Content**: Currently blank, to be defined in future development
  - **Background**: Yellow (`#FEC620`) solid fill
  - **Padding**: Consistent padding around container edges

#### Layout Structure
```
┌─────────────────────┬─────────────────────┐
│                     │                     │
│   APK Interface     │   Future Content     │
│   Replication       │   (To Be Defined)    │
│   (1/3 width)       │   (2/3 width)        │
│                     │                     │
│   [Embedded         │   [Blank Canvas]     │
│    Flutter Web]     │                     │
│                     │                     │
└─────────────────────┴─────────────────────┘
```

### Integration Points
- **APK Replication**: 1/3 section hosts embedded mobile payment interface
- **Content Expansion**: 2/3 section available for additional features
- **Responsive Design**: Grid adapts to different screen sizes
- **Visual Consistency**: Yellow theme maintains design coherence

## APK BluPOS Export: Master Page

### Overview
The APK serves as an extendable component that can be seamlessly integrated into the master BluPOS web interface. This section outlines the export and integration specifications for embedding the mobile APK functionality into the primary web-based BluPOS system.

### Export Architecture
- **Component Type**: Embeddable Flutter Web Module
- **Integration Method**: iframe/WebView container within master BluPOS interface
- **Communication**: RESTful API bridge between web and mobile components

### Integration Points
- **License Management**: Centralized license validation across web and mobile platforms
- **Data Synchronization**: Real-time sync of transaction data and user preferences
- **UI Consistency**: Unified design language maintained across platforms
- **Authentication**: Single sign-on capability between web and mobile interfaces

### Export Specifications
- **Build Target**: Flutter Web with CanvasKit renderer for optimal performance
- **Bundle Size**: Optimized for web deployment with tree-shaking and code splitting
- **API Endpoints**: Full REST API compatibility for cross-platform communication
- **State Management**: Shared state persistence across web and mobile sessions

### Deployment Requirements
- **Web Server**: Nginx/Apache configuration for Flutter Web hosting
- **CORS Policy**: Cross-origin resource sharing setup for API communication
- **SSL Certificate**: HTTPS requirement for secure data transmission
- **Performance Monitoring**: Load time and responsiveness tracking

## Web Interface Testing Procedures

This section documents the testing procedures for the web interface APK implementation, including JavaScript API calls, UI state changes, and expected behaviors that mirror the Flutter application.

### Web Interface API Integration

The web interface uses JavaScript to communicate with the micro-server, providing identical functionality to the Flutter APK. All API calls and responses match the Flutter implementation exactly.

#### JavaScript Functions Available

Run these functions in the browser console to test web interface behavior:

##### 1. Device Activation Test
```javascript
// Simulate clicking the activation button
handleActivation()
```
**Expected Behavior**:
- Button text changes to "Activating..."
- API call to `POST /activate` with generated device ID
- Success: Yellow card updates to show "Active" status, balance changes to "KES 12,345.67", expiry date appears, background turns light green, activation button disappears
- Failure: Error alert with server response message

##### 2. Force License Expiry Test
```javascript
forceExpiry()
```
**Expected Behavior**:
- API call to `POST /test` with action "force_expiry"
- Success: License status changes to "Not Activated", balance resets to "KES 0.00", expiry shows "--/--/----", background turns grey, activation button reappears
- Failure: Error alert if device not activated first

##### 3. Reset to First-Time State
```javascript
resetToFirstTime()
```
**Expected Behavior**:
- Local storage cleared for activation state
- UI immediately resets to first-time appearance
- Yellow card shows "Not Activated", "KES 0.00", "--/--/----"
- Activation button becomes visible
- Background changes to grey

#### UI State Transitions - Web Interface

##### First-Time → Active State Transition
1. **Trigger**: Click "Activate Device" button
2. **API Call**: `POST /activate` with `action: "first_time"`
3. **UI Changes**:
   - License Status: "Not Activated" → "Active"
   - Balance Display: "KES 0.00" → "KES 12,345.67"
   - Expiry Date: "--/--/----" → Formatted date (e.g., "12/31/2025")
   - Background Color: Grey (#D7D7D7) → Light Green (#90EE90)
   - Activation Button: Visible → Hidden

##### Active → Expired State Transition
1. **Trigger**: Call `forceExpiry()` in console
2. **API Call**: `POST /test` with `action: "force_expiry"`
3. **UI Changes**:
   - License Status: "Active" → "Not Activated"
   - Balance Display: "KES 12,345.67" → "KES 0.00"
   - Expiry Date: Formatted date → "--/--/----"
   - Background Color: Light Green (#90EE90) → Grey (#D7D7D7)
   - Activation Button: Hidden → Visible

##### Any State → First-Time Reset
1. **Trigger**: Call `resetToFirstTime()` in console
2. **Local Storage**: Cleared (no API call)
3. **UI Changes**: Immediate reset to first-time appearance

#### Web Interface vs Flutter APK Comparison

| Feature | Flutter APK | Web Interface | Status |
|---------|-------------|---------------|---------|
| Yellow Card Display | ✅ Native widgets | ✅ HTML/CSS absolute positioning | ✅ Equivalent |
| Network Time Display | ✅ Dynamic | ✅ Static (14:30) | ✅ Functional |
| License Status Updates | ✅ Real-time | ✅ Real-time via JS | ✅ Equivalent |
| Balance Display | ✅ Formatted | ✅ Formatted strings | ✅ Equivalent |
| Background Color Changes | ✅ State-based | ✅ State-based via JS | ✅ Equivalent |
| Activation Button | ✅ Native button | ✅ HTML button | ✅ Equivalent |
| API Integration | ✅ HTTP client | ✅ Fetch API | ✅ Equivalent |
| State Persistence | ✅ Secure storage | ✅ localStorage | ✅ Equivalent |
| Error Handling | ✅ Native dialogs | ✅ Browser alerts | ✅ Equivalent |
| Test Functions | ✅ Debug mode | ✅ Console functions | ✅ Equivalent |

#### Web-Specific Testing Commands

##### Browser Console Testing
```javascript
// Check if micro-server is accessible
checkServerStatus()

// Monitor current activation state
console.log('Activated:', localStorage.getItem('device_activated'))
console.log('Device ID:', localStorage.getItem('device_id'))
console.log('License Type:', localStorage.getItem('license_type'))
console.log('Expiry:', localStorage.getItem('license_expiry'))
```

##### Manual UI Element Testing
```javascript
// Directly update UI elements for testing
document.querySelector('#license-status-text').textContent = 'Active'
document.querySelector('#total-balance-text').textContent = 'KES 12,345.67'
document.querySelector('#payments-interface-container').style.backgroundColor = '#90EE90'
```

#### Expected UI Update Behavior

##### Real-Time Updates
- **Latency**: < 100ms for localStorage updates, < 500ms for API responses
- **Persistence**: State maintained across page refreshes
- **Synchronization**: UI state matches server response immediately

##### Error Scenarios
- **Network Failure**: "Activation failed. Please check micro-server connection."
- **Invalid License**: "Activation failed: Invalid activation code"
- **Server Down**: "Micro-server connection failed" (logged to console)

##### Performance Metrics
- **API Response Time**: < 200ms for local micro-server
- **UI Update Time**: < 50ms for DOM manipulation
- **State Persistence**: Instant (localStorage synchronous)

## Technical Specifications

### Micro-Server API Endpoints (for Rapid Prototyping)

#### GET /health
Health check endpoint to verify server status and license information.
- **Response**: `{"status": "ok", "timestamp": "2025-12-21T17:12:30Z", "server": "BluPOS Micro-Server", "version": "1.0.0"}`

#### POST /activate
Device activation and license management with comprehensive state handling.
- **Parameters**:
  - `action`: `"first_time" | "check_expiry" | "reactivate"`
  - `device_id`: Device identifier (string)
  - `activation_code`: Required for `"first_time"` and `"reactivate"` actions (string)

- **Actions**:
  - **First Time Activation**:
    - **Request**: `{"action": "first_time", "device_id": "xxx", "activation_code": "BLUPOS2025|DEMO2025"}`
    - **Success Response**: `{"status": "success", "message": "Device activated successfully", "license_expiry": "2025-12-31T00:00:00.000Z", "app_state": "active", "license_type": "BLUPOS2025|DEMO2025", "license_days": 30|7}`
    - **Error Responses**:
      - Invalid code: `{"status": "error", "message": "Invalid activation code"}`
      - Already activated: `{"status": "error", "message": "Device already activated"}`

  - **License Check**:
    - **Request**: `{"action": "check_expiry", "device_id": "xxx"}`
    - **Active Response**: `{"status": "success", "app_state": "active", "license_expiry": "2025-12-31T00:00:00.000Z", "days_remaining": 10, "license_type": "BLUPOS2025|DEMO2025"}`
    - **Expired Response**: `{"status": "success", "app_state": "expired", "license_expiry": "2025-12-20T00:00:00.000Z", "days_overdue": 1, "license_type": "BLUPOS2025|DEMO2025"}`
    - **Not Activated Response**: `{"status": "success", "app_state": "first_time", "message": "Device not activated"}`

  - **Reactivation**:
    - **Request**: `{"action": "reactivate", "device_id": "xxx", "activation_code": "BLUPOS2025|DEMO2025"}`
    - **Success Response**: `{"status": "success", "message": "License reactivated successfully", "license_expiry": "2025-12-31T00:00:00.000Z", "app_state": "active", "license_type": "BLUPOS2025|DEMO2025"}`
    - **Error Responses**:
      - Invalid code: `{"status": "error", "message": "Invalid activation code"}`
      - Not previously activated: `{"status": "error", "message": "Device not previously activated"}`

#### POST /test
Testing utilities for UI iteration and state management testing.
- **Parameters**:
  - `action`: `"force_expiry" | "reset_first_time" | "update_license" | "get_status"`
  - `device_id`: Device identifier (string)
  - `license_type`: Required for `"update_license"` action (string: "BLUPOS2025" | "DEMO2025")

- **Actions**:
  - **Force Expiry**:
    - **Request**: `{"action": "force_expiry", "device_id": "xxx"}`
    - **Response**: `{"status": "success", "message": "License expired", "app_state": "expired", "license_expiry": "EXPIRED"}`

  - **Reset to First Time**:
    - **Request**: `{"action": "reset_first_time", "device_id": "xxx"}`
    - **Response**: `{"status": "success", "message": "Reset to first time", "app_state": "first_time"}`

  - **Update License Type**:
    - **Request**: `{"action": "update_license", "device_id": "xxx", "license_type": "BLUPOS2025|DEMO2025"}`
    - **Success Response**: `{"status": "success", "message": "License updated", "license_type": "BLUPOS2025|DEMO2025", "license_expiry": "2025-12-31T00:00:00.000Z"}`
    - **Error Response**: `{"status": "error", "message": "Invalid license type. Use BLUPOS2025 or DEMO2025"}`

  - **Get Status**:
    - **Request**: `{"action": "get_status", "device_id": "xxx"}`
    - **Response**: `{"status": "success", "app_state": "active|expired|first_time", "license_type": "BLUPOS2025|DEMO2025|null", "license_expiry": "2025-12-31T00:00:00.000Z|null", "days_remaining": 10, "activation_code": "BLUPOS2025|DEMO2025|null"}`

#### Error Response Format
All endpoints return errors in this format:
```json
{
  "status": "error",
  "message": "Descriptive error message",
  "code": "ERROR_CODE"
}
```

#### Supported License Types
- **BLUPOS2025**: 30-day full license (wallet, reports, activation features)
- **DEMO2025**: 7-day demo license (wallet, reports only)

#### Test Commands for UI Reactivity

Run these curl commands in a terminal to test the micro-server endpoints and observe UI changes:

##### 1. First Time Activation (BLUPOS2025 - Direct Navigation)
```bash
curl -X POST http://localhost:8085/activate \
  -H "Content-Type: application/json" \
  -d '{
    "action": "first_time",
    "device_id": "1766328909629",
    "activation_code": "BLUPOS2025"
  }'
```
**Expected Response**: Direct navigation to active page with green background and action buttons

##### 2. First Time Activation (DEMO2025 - Normal Flow)
```bash
curl -X POST http://localhost:8085/activate \
  -H "Content-Type: application/json" \
  -d '{
    "action": "first_time",
    "device_id": "1766328909629",
    "activation_code": "DEMO2025"
  }'
```
**Expected Response**: 7-day demo license activation

##### 3. Check License Status
```bash
curl -X POST http://localhost:8085/activate \
  -H "Content-Type: application/json" \
  -d '{
    "action": "check_expiry",
    "device_id": "1766328909629"
  }'
```
**Expected Response**: Current license status with days remaining

##### 4. Force License Expiry (Test Expired State)
```bash
curl -X POST http://localhost:8085/test \
  -H "Content-Type: application/json" \
  -d '{
    "action": "force_expiry",
    "device_id": "1766328909629"
  }'
```
**Expected Response**: License immediately expires, UI shows expired state

##### 5. Reset to First Time State
```bash
curl -X POST http://localhost:8085/test \
  -H "Content-Type: application/json" \
  -d '{
    "action": "reset_first_time",
    "device_id": "1766328909629"
  }'
```
**Expected Response**: App resets to first-time state with KES 0.00 balance

##### 6. Get Complete Status
```bash
curl -X POST http://localhost:8085/test \
  -H "Content-Type: application/json" \
  -d '{
    "action": "get_status",
    "device_id": "1766328909629"
  }'
```
**Expected Response**: Complete device and license status information

##### 7. Update License Type
```bash
curl -X POST http://localhost:8085/test \
  -H "Content-Type: application/json" \
  -d '{
    "action": "update_license",
    "device_id": "1766328909629",
    "license_type": "DEMO2025"
  }'
```
**Expected Response**: License type updated to DEMO2025 (7 days)

##### 8. Reactivate License
```bash
curl -X POST http://localhost:8085/activate \
  -H "Content-Type: application/json" \
  -d '{
    "action": "reactivate",
    "device_id": "1766328909629",
    "activation_code": "BLUPOS2025"
  }'
```
**Expected Response**: License extended/reactivated

#### UI State Transitions to Test

1. **First Time → Active**: Use activation commands, observe green background and action buttons
2. **Active → Expired**: Use force_expiry, observe status change in yellow card
3. **Expired → Active**: Use reactivation, observe return to active state
4. **Any → First Time**: Use reset_first_time, observe KES 0.00 and "Not Activated" status
5. **License Updates**: Use update_license, observe expiry date changes

#### Expected UI Changes

- **Background Color**: Gray (first/expired) ↔ Green (active)
- **Balance Display**: KES 0.00 (first time) ↔ KES 12,345.67 (active)
- **License Status**: "Not Activated" → "Active" → "Expired"
- **Action Buttons**: Single "Activate" (first time) ↔ Three buttons (active)
- **Yellow Card Content**: Updates based on license state
