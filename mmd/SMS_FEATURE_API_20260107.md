# SMS Feature API Documentation - January 7, 2026

## Overview

This document outlines the SMS Feature API endpoints implemented in the BluPOS Wallet microserver. These endpoints provide programmatic access to SMS data for debugging, monitoring, and external integrations.

## API Endpoints

### Base URL
```
http://localhost:8085
```

### 1. `/on-boot-sms-total-count` - On-Boot SMS Total Count
**Method**: `GET`  
**Description**: Returns SMS counts captured at application initialization/boot time
**Purpose**: Provides baseline SMS metrics representing the device's SMS inbox state when the app first starts

#### Key Characteristics of On-Boot Data
- **📱 Source**: Only device inbox SMS (`read = 0` from Android SMS provider)
- **⏰ Timing**: Captured during SMS service initialization
- **📊 Content**: Represents SMS that existed before app runtime activity
- **🔄 State**: Static snapshot of inbox at boot time
- **🎯 Purpose**: Baseline for comparing against runtime changes

#### Response Format
```json
{
  "status": "success",
  "context": "on_boot",
  "timestamp": "2026-01-07T20:41:03.557308Z",
  "counts": {
    "total_messages": 12,
    "read_messages": 10,
    "unread_messages": 2,
    "payment_messages": 1,
    "system_messages": 3
  },
  "breakdown": {
    "opened": 10,
    "unopened": 2,
    "payment_opened": 1,
    "payment_unopened": 0
  },
  "sources": ["inbox"],
  "last_updated": "2026-01-07T20:41:03.557308Z",
  "boot_context": {
    "captured_at": "app_initialization",
    "includes_existing_inbox": true,
    "excludes_runtime_messages": true,
    "represents_baseline": true
  }
}
```

#### Usage Examples
```bash
curl http://localhost:8085/on-boot-sms-total-count
```

```javascript
fetch('http://localhost:8085/on-boot-sms-total-count')
  .then(res => res.json())
  .then(data => console.log('Boot SMS counts:', data.counts));
```

### 2. `/after-boot-total-count` - After-Boot SMS Total Count
**Method**: `GET`  
**Description**: Returns current SMS counts after application boot  
**Purpose**: Provides real-time SMS metrics showing changes since boot

#### Response Format
```json
{
  "status": "success",
  "context": "after_boot",
  "timestamp": "2026-01-07T20:41:03.557308Z",
  "counts": {
    "total_messages": 17,
    "read_messages": 9,
    "unread_messages": 8,
    "payment_messages": 4,
    "system_messages": 2
  },
  "breakdown": {
    "opened": 9,
    "unopened": 8,
    "payment_opened": 3,
    "payment_unopened": 1
  },
  "sources": ["inbox", "incoming_broadcast", "payment_broadcast"],
  "last_updated": "2026-01-07T20:41:03.557308Z"
}
```

#### Usage Examples
```bash
curl http://localhost:8085/after-boot-total-count
```

```javascript
fetch('http://localhost:8085/after-boot-total-count')
  .then(res => res.json())
  .then(data => console.log('Current SMS counts:', data.counts));
```

### 3. `/message/<id>` - Get SMS Message by ID
**Method**: `GET`  
**Description**: Retrieves a specific SMS message by its unique identifier  
**Purpose**: Provides detailed access to individual SMS messages for inspection

#### Path Parameters
- `id` (string): The unique message identifier

#### Response Format (Success)
```json
{
  "status": "success",
  "message_id": "1767812249000",
  "data": {
    "id": "1767812249000",
    "sender": "+254700123456",
    "message": "Payment Of Kshs 150.00 Has Been Received By Jaystar Investments Ltd For Account 80872, From John Smith on 07/01/26 at 09.57pm",
    "timestamp": 1767812249000,
    "read": false,
    "amount": 150.0,
    "reference": "YL4ZEC9B6Y",
    "source": "payment_broadcast",
    "channel": "80872",
    "parsed_at": "2026-01-07T20:41:03.557308Z"
  },
  "metadata": {
    "retrieved_at": "2026-01-07T20:41:03.557308Z",
    "cache_status": "live",
    "source": "sms_service"
  }
}
```

#### Response Format (Not Found)
```json
{
  "status": "error",
  "message": "Message not found"
}
```

#### Response Format (Error)
```json
{
  "status": "error",
  "message": "Message ID is required"
}
```

#### Usage Examples
```bash
curl http://localhost:8085/message/1767812249000
```

```javascript
fetch('http://localhost:8085/message/1767812249000')
  .then(res => res.json())
  .then(data => {
    if (data.status === 'success') {
      console.log('Message:', data.data.message);
      console.log('Amount:', data.data.amount);
    }
  });
```

## Data Structures

### SMS Count Object
```typescript
interface SmsCounts {
  total_messages: number;      // Total SMS in memory
  read_messages: number;       // Read SMS count
  unread_messages: number;     // Unread SMS count
  payment_messages: number;    // Payment-related SMS
  system_messages: number;     // System/technical SMS
}
```

### SMS Breakdown Object
```typescript
interface SmsBreakdown {
  opened: number;              // Total read SMS
  unopened: number;            // Total unread SMS
  payment_opened: number;      // Read payment SMS
  payment_unopened: number;    // Unread payment SMS
}
```

### SMS Message Object
```typescript
interface SmsMessage {
  id: string;                  // Unique message ID
  sender: string;              // Sender phone number
  message: string;             // Full message text
  timestamp: number;           // Unix timestamp
  read: boolean;               // Read status
  amount?: number;             // Parsed payment amount
  reference?: string;          // Payment reference
  source: string;              // Message source type
  channel?: string;            // Payment channel
  parsed_at: string;           // ISO timestamp of parsing
}
```

## Error Handling

### HTTP Status Codes
- `200` - Success
- `400` - Bad Request (missing parameters)
- `404` - Not Found (message doesn't exist)
- `500` - Internal Server Error

### Error Response Format
```json
{
  "status": "error",
  "message": "Human-readable error description"
}
```

## Implementation Notes

### Current Implementation Status
- **Endpoints**: ✅ All endpoints implemented
- **Data Source**: 🔄 Mock data (placeholder for real SMS service integration)
- **Authentication**: ❌ None required (local microserver)
- **CORS**: ✅ Enabled for web compatibility

### Future Enhancements
1. **Real Data Integration**: Connect to actual SMS service instead of mock data
2. **Authentication**: Add API key or device-based authentication
3. **Pagination**: Add pagination for large message lists
4. **Filtering**: Add query parameters for filtering messages
5. **WebSocket Support**: Real-time SMS updates via WebSocket

### Security Considerations
- Endpoints are only accessible on localhost
- No authentication required (intended for local debugging)
- CORS enabled for web development
- Data validation on all inputs

## Testing Examples

### Test Script (Bash)
```bash
#!/bin/bash

# Test all SMS API endpoints
echo "Testing SMS API endpoints..."

# Test on-boot counts
echo "1. On-boot SMS counts:"
curl -s http://localhost:8085/on-boot-sms-total-count | jq '.counts'

# Test after-boot counts
echo "2. After-boot SMS counts:"
curl -s http://localhost:8085/after-boot-total-count | jq '.counts'

# Test message retrieval
echo "3. Message by ID:"
curl -s http://localhost:8085/message/1767812249000 | jq '.data.message'

echo "SMS API testing complete."
```

### Test Script (JavaScript)
```javascript
// Test SMS API endpoints
async function testSmsApi() {
  try {
    // Test on-boot counts
    const bootResponse = await fetch('http://localhost:8085/on-boot-sms-total-count');
    const bootData = await bootResponse.json();
    console.log('Boot counts:', bootData.counts);

    // Test after-boot counts
    const currentResponse = await fetch('http://localhost:8085/after-boot-total-count');
    const currentData = await currentResponse.json();
    console.log('Current counts:', currentData.counts);

    // Test message retrieval
    const messageResponse = await fetch('http://localhost:8085/message/1767812249000');
    const messageData = await messageResponse.json();
    console.log('Message:', messageData.data?.message);

  } catch (error) {
    console.error('SMS API test failed:', error);
  }
}

testSmsApi();
```

## Key Differences: On-Boot vs After-Boot SMS Counts

### Conceptual Separation

The **on-boot** and **after-boot** endpoints serve different analytical purposes in the SMS lifecycle:

#### 🎯 **On-Boot SMS Counts** (`/on-boot-sms-total-count`)
**What it represents**: The baseline state of the device's SMS inbox at application initialization
- **📅 Timing**: Captured when SMS service first initializes during app boot
- **📱 Source**: Direct query of Android SMS provider (`read = 0` from device inbox)
- **🎯 Purpose**: Provides reference point for measuring SMS activity during app session
- **🔄 Static**: Represents SMS that existed before the app's runtime activity began
- **📊 Content**: Only truly unread messages from device inbox (no runtime additions)

#### 🚀 **After-Boot SMS Counts** (`/after-boot-total-count`)
**What it represents**: The current state of SMS processing during active app usage
- **📅 Timing**: Dynamic, reflects current state during app runtime
- **📱 Source**: Combined from device inbox + runtime SMS processing
- **🎯 Purpose**: Shows accumulated SMS activity since app launch
- **🔄 Dynamic**: Includes SMS received and processed during app session
- **📊 Content**: All SMS in memory (inbox + incoming broadcasts + payment processing)

### Practical Example

**Scenario**: App starts with 10 unread SMS in device inbox, then receives 5 new SMS during usage:

```
Boot Time (On-Boot API):
├── Device Inbox: 10 unread SMS
├── Runtime SMS: 0 (app just started)
└── Total: 10 unread SMS

After Boot (After-Boot API):
├── Device Inbox: 10 unread SMS
├── Runtime SMS: 5 new incoming SMS
└── Total: 15 unread SMS
```

### Use Cases

#### On-Boot Counts
- **📈 Baseline Measurement**: Compare against after-boot to measure SMS activity
- **🔍 Inbox Analysis**: Understand device's SMS state at app launch
- **📊 Session Tracking**: Calculate SMS received during app usage (`after - on = delta`)

#### After-Boot Counts
- **📊 Current State**: Real-time view of all SMS being processed
- **🔄 Runtime Monitoring**: Track SMS processing during active usage
- **📈 Activity Metrics**: Measure SMS throughput and processing efficiency

### Implementation Context

**Current Status**: Both endpoints return mock data with different baseline counts
**Future Integration**: Will connect to actual SMS service with real separation logic

## Integration with SMS Service

### Current Architecture
```
SMS Service (Dart) ↔ Microserver API ↔ External Clients
       ↓                        ↓                        ↓
   Message Storage        HTTP Endpoints          Web/Mobile Apps
   Count Tracking         JSON Responses          REST API Calls
   Real-time Updates      CORS Enabled            Data Visualization
```

### Data Flow
1. **SMS Received** → Dart SMS Service → Memory Storage
2. **API Called** → Microserver Handler → Query Mock Data
3. **Response Sent** → JSON Format → Client Consumption

### Future Real Implementation
```dart
// Real implementation would access SMS service directly
static Future<Map<String, dynamic>> _getCurrentSmsCounts(String context) async {
  final smsService = SmsService(); // Get singleton instance
  final messages = smsService.smsMessages;

  // Calculate real counts from actual SMS data
  final counts = {
    'total_messages': messages.length,
    'read_messages': messages.where((m) => m['read'] == true).length,
    'unread_messages': messages.where((m) => m['read'] == false).length,
    // ... etc
  };

  return counts;
}
```

## Monitoring and Debugging

### Health Check Integration
The SMS API endpoints are designed to integrate with the existing health check system:

```json
{
  "status": "ok",
  "sms_api": {
    "endpoints_available": 3,
    "last_request": "2026-01-07T20:41:03.557308Z",
    "total_messages": 17,
    "unread_messages": 8
  }
}
```

### Logging
All API requests are logged with timestamps and request details:
```
📱 SMS API: Getting on-boot SMS total count
📱 SMS API: Getting message by ID: 1767812249000
📨 Retrieved SMS message: ID=1767812249000, Sender=+254700123456
```

## Conclusion

The SMS Feature API provides a comprehensive interface for accessing SMS data programmatically. While currently using mock data, the endpoints are designed to easily integrate with the real SMS service when ready. The API supports debugging, monitoring, and external integrations while maintaining security through localhost-only access.

**Endpoints**: 3 functional  
**Data Format**: JSON with consistent structure  
**Error Handling**: Comprehensive HTTP status codes  
**Future Ready**: Easy migration to real SMS service data
