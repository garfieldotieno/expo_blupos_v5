# Activation Flow Goal - Timestamp: 2026-01-12 20:09:07 UTC+3

## Overview
The activation flow from the Flutter app to the backend previously worked but is now taking an awfully long time (effectively not working). We suspect blocking I/O and network operations are hampering the flow.

## Desired Behavior

### On Boot Sequence:
1. **Discover Broadcast Details**: Find broadcast details from the server
2. **Update Preferences**: Store/update network preferences with discovered details
3. **Query Backend**: Use stored network details to query backend for active state of the system

### Activation State Check:
- **If Activated**: Proceed with normal app flow
- **If Not Activated**: Show landing interface with activate button

### Activation Interface Flow:
1. **On Activate Button Click**: Render activation interface
2. **Skip Discovery**: Do NOT perform new network discovery
3. **Load Network Data**: Use previously stored network data from preferences
4. **IP Input Only**: Show activation view with IP input field (pre-populated if available)
5. **Submit Activation Code**: When activation code is submitted, send action to backend

## Key Optimizations Needed:
- Eliminate blocking I/O operations
- Optimize network operations
- Ensure smooth, responsive UI during activation flow
- Prevent unnecessary network discovery retries
- Use cached/preference-stored network details efficiently

## Success Criteria:
- Fast boot-to-activation-check time
- Responsive UI during activation process
- Reliable backend communication using stored network details
- No unnecessary blocking operations

## Implementation Flowcharts

### Current State (Problematic Implementation)
```mermaid
flowchart TD
    A[App Boot] --> B[Perform Network Discovery<br/>⚠️ BLOCKING I/O]
    B --> C[Update Preferences<br/>with Discovery Results]
    C --> D[Query Backend for Activation State<br/>⚠️ BLOCKING NETWORK CALL]
    D --> E{Is Activated?}

    E -->|Yes| F[Proceed with Normal App Flow]
    E -->|No| G[Show Landing Interface<br/>with Activate Button]

    G --> H[User Clicks Activate Button]
    H --> I[Perform Network Discovery Again<br/>⚠️ BLOCKING I/O - REDUNDANT]
    I --> J[Show Activation Interface<br/>with Full Network Discovery UI]
    J --> K[User Enters Network Details<br/>+ Activation Code]
    K --> L[Submit to Backend<br/>⚠️ BLOCKING NETWORK CALL]
    L --> M[Handle Response]

    style B fill:#ffcccc
    style D fill:#ffcccc
    style I fill:#ffcccc
    style L fill:#ffcccc
```

### Desired State (Optimized Implementation)
```mermaid
flowchart TD
    A[App Boot] --> B[Discover Broadcast Details<br/>✅ SYNCHRONOUS - REQUIRED FOR BOOT]
    B --> C[Update Preferences<br/>Store Network Data]
    C --> D[Query Backend for Activation State<br/>✅ ASYNC using Stored Network Details]
    D --> E{Is Activated?}

    E -->|Yes| F[Proceed with Normal App Flow]
    E -->|No| G[Show Landing Interface<br/>with Activate Button]

    G --> H[User Clicks Activate Button]
    H --> I[Render Activation Interface Immediately<br/>✅ NO DISCOVERY - UI FIRST]
    I --> J[Load Network Data from Preferences<br/>✅ ALWAYS AVAILABLE POST-BOOT]
    J --> K[Show IP Input Field Only<br/>✅ ALWAYS PRE-POPULATED]
    K --> L[User Enters Activation Code<br/>+ Submits]
    L --> M[Send to Backend<br/>✅ ASYNC NETWORK CALL]
    M --> N[Handle Response<br/>with Loading Indicators]

    style B fill:#ccffcc
    style D fill:#ccffcc
    style I fill:#ccffcc
    style J fill:#ccffcc
    style M fill:#ccffcc
```
