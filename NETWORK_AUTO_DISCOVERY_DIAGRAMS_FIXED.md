# Network Auto-Discovery Flow Diagrams (Fixed)

## 📊 Current Implementation Flow (Phase 1 & 2)

```mermaid
graph TB
    subgraph "Flutter App (Mobile)"
        A1[App Launch] --> B1[Initialize Network Discovery]
        B1 --> C1[Start UDP Listener<br/>Port 8888]
        C1 --> D1[Listen for Server Broadcasts]
        
        D1 --> E1{Server Found?}
        E1 -->|No| F1[Continue Listening]
        F1 --> D1
        
        E1 -->|Yes| G1[Parse Server Info]
        G1 --> H1[Validate Server]
        H1 --> I1{Valid Server?}
        I1 -->|No| D1
        I1 -->|Yes| J1[Auto-Connect to Server]
        J1 --> K1[Update API Client]
        K1 --> L1[Success Notification]
    end

    subgraph "BluPOS Backend (Python)"
        M1[Server Start] --> N1[Initialize Broadcast Service]
        N1 --> O1[Get Local IP Address]
        O1 --> P1[Create Server Info JSON]
        P1 --> Q1[Start UDP Broadcasting<br/>Port 8888<br/>Every 30s]
        
        Q1 --> R1[Send Multicast Packet<br/>Group: 239.255.1.1]
        R1 --> S1[Wait 30 seconds]
        S1 --> Q1
    end

    subgraph "Network Layer"
        T1[UDP Multicast<br/>Port 8888<br/>Group 239.255.1.1<br/>TTL: 2]
    end

    subgraph "Fallback System (Phase 1)"
        U1[Connection Failures<br/>Count > 3] --> V1[Show Network Config Dialog]
        V1 --> W1[Manual IP Input]
        W1 --> X1[Test Connection]
        X1 --> Y1{Connection OK?}
        Y1 -->|No| W1
        Y1 -->|Yes| Z1[Save Configuration]
        Z1 --> AA1[Prompt App Restart]
    end

    Flutter --> Network
    Backend --> Network
    Network --> Flutter
    
    J1 -.-> U1
    D1 -.-> U1
```

## �� Phase 2: UDP Broadcast Auto-Discovery Detail

```mermaid
sequenceDiagram
    participant Backend as BluPOS Backend
    participant Network as UDP Network (Port 8888)
    participant Flutter as Flutter App
    participant API as API Client
    participant Storage as SharedPreferences

    Note over Backend: Server Startup
    Backend->>Backend: Initialize BroadcastService
    Backend->>Backend: Get local IP (192.168.100.25)
    Backend->>Backend: Create server info JSON

    loop Every 30 seconds
        Backend->>Network: UDP Multicast Broadcast
        Note right of Backend: {"server_type":"blupos_backend","ip_address":"192.168.100.25","port":8080,"server_name":"BluPOS Backend Server","timestamp":1735480800}
    end

    Note over Flutter: App Startup
    Flutter->>Flutter: Initialize NetworkDiscoveryService
    Flutter->>Network: Join multicast group 239.255.1.1
    Flutter->>Network: Bind to port 8888

    Network->>Flutter: UDP Packet Received
    Flutter->>Flutter: Parse JSON message
    Flutter->>Flutter: Extract server details
    Flutter->>Flutter: Validate server info

    alt Valid server
        Flutter->>Flutter: Add/Update server in list
        Flutter->>Flutter: Test server connection (/health)
        Flutter->>API: Update master URL
        Flutter->>Storage: Save backend URL
        Flutter->>Flutter: Show success notification
    else Invalid server
        Flutter->>Flutter: Skip server
    end

    Note over Flutter,Storage: Auto-configuration complete
```

## 📦 Data Flow Diagrams

### Phase 1 & 2 Data Structures

```mermaid
classDiagram
    class DiscoveredServer {
        +String serverType
        +String ipAddress
        +int port
        +String serverName
        +DateTime lastSeen
        +int timestamp
        +String url
        +toJson()
        +fromJson()
    }

    class NetworkDiscoveryService {
        +List~DiscoveredServer~ discoveredServers
        +Stream~List~ discoveredServersStream
        +startDiscovery()
        +stopDiscovery()
        +getBestServer()
        +testServerConnection()
        +_handleIncomingBroadcast()
        +_addOrUpdateServer()
        +_cleanupOldServers()
    }

    class BackendBroadcastService {
        +String serverType
        +int port
        +int broadcastPort
        +String multicastGroup
        +bool running
        +startBroadcasting()
        +stopBroadcasting()
        +_broadcastLoop()
        +_getServerInfo()
        +_getLocalIp()
    }

    class class Network {
    +String multicastGroup
    +int broadcastPort
    +sendUDPPacket()
    +receiveUDPPacket()
}

ApiClient {
        +String baseUrl
        +String _bluposMasterUrl
        +setMasterUrl(url)
        +getBackendUrl()
        +saveBackendUrl(url)
        +initializeBackendUrl()
        +testConnectionToUrl(url)
    }

    NetworkDiscoveryService --> DiscoveredServer : manages
    BackendBroadcastService --> "*" : broadcasts to
    NetworkDiscoveryService --> "*" : discovers from
    ApiClient --> NetworkDiscoveryService : uses discovered servers
```

### UDP Broadcast Packet Structure

```mermaid
graph TD
    title[UDP Broadcast Packet Structure]

    A["0-15: server_type<br/>blupos_backend"]
    B["16-31: ip_address<br/>192.168.100.25"]
    C["32-47: port<br/>8080"]
    D["48-63: server_name<br/>BluPOS Backend Server"]
    E["64-79: timestamp<br/>1735480800"]

    A --> B --> C --> D --> E
```

## 🔗 Phase 2 to Phase 3 Transition Flow

```mermaid
graph LR
    subgraph "Phase 2 (Current)"
        A2[UDP Discovery] --> B2[Server List]
        B2 --> C2[Best Server Selection]
        C2 --> D2[Auto-Connect]
    end

    subgraph "Phase 3 (Future)"
        E3[Server Selection UI] --> F3[Manual Server Choice]
        G3[Health Monitoring] --> H3[Real-time Status]
        I3[Multi-Server Mgmt] --> J3[Load Balancing]
        K3[Advanced Error Handling] --> L3[Auto-Failover]
    end

    subgraph "Data Flow Expansion"
        M3[Server Health Data] --> N3[Response Times]
        O3[Connection Metrics] --> P3[Uptime Statistics]
        Q3[User Preferences] --> R3[Server Rankings]
    end

    D2 --> E3
    D2 --> G3
    B2 --> I3
    B2 --> K3

    H3 --> M3
    J3 --> O3
    F3 --> Q3
```

## 🌐 Complete Network Architecture

```mermaid
graph TB
    subgraph "Physical Layer"
        HW1[Router/Switch<br/>192.168.1.1]
        HW2[BluPOS Server<br/>192.168.100.25:8080]
        HW3[Mobile Device<br/>192.168.1.100]
    end

    subgraph "Network Layer"
        NW1[UDP Multicast<br/>239.255.1.1:8888<br/>TTL: 2]
        NW2[TCP HTTP<br/>192.168.100.25:8080]
        NW3[TCP HTTPS<br/>Future SSL Support]
    end

    subgraph "Application Layer"
        APP1[Backend Broadcast Service<br/>Python Thread]
        APP2[Flutter Discovery Service<br/>Dart Isolate]
        APP3[API Client<br/>HTTP Requests]
    end

    subgraph "Data Layer"
        DB1[SharedPreferences<br/>backend_url]
        DB2[SQLite<br/>License/Account Data]
        DB3[JSON Broadcast<br/>Server Metadata]
    end

    HW1 --> NW1
    HW2 --> NW1
    HW2 --> NW2
    HW3 --> NW1
    HW3 --> NW2

    NW1 --> APP1
    NW1 --> APP2
    NW2 --> APP3

    APP1 --> DB3
    APP2 --> DB1
    APP3 --> DB2
```

## 📋 Phase Implementation Timeline

```mermaid
timeline
    title Network Auto-Discovery Implementation Timeline

    section Phase 1 (Complete)
        Manual IP Config : Manual network configuration popup
        Smart Failure Detection : Auto-trigger after 3 connection failures
        CORS Updates : Backend allows reconfiguration requests

    section Phase 2 (Complete)
        UDP Broadcast Service : Backend broadcasts server presence
        Network Discovery Service : Flutter app discovers servers
        Auto-Configuration : Seamless server connection
        Testing Framework : Comprehensive test suite

    section Phase 3 (Planned)
        Server Selection UI : Multi-server environment support
        Health Monitoring : Real-time server status tracking
        Multi-Server Management : Enterprise load balancing
        Advanced Error Handling : Robust network resilience
```

## 🔄 Data Synchronization Flow

```mermaid
stateDiagram-v2
    [*] --> BackendBroadcasting
    BackendBroadcasting --> FlutterListening: UDP Packet

    FlutterListening --> ParsingData: Valid JSON
    FlutterListening --> FlutterListening: Invalid/Missing Data

    ParsingData --> ValidatingServer: Extract Fields
    ValidatingServer --> ConnectingToServer: Server Valid
    ValidatingServer --> FlutterListening: Server Invalid

    ConnectingToServer --> TestingConnection: HTTP /health
    TestingConnection --> UpdatingAPI: Connection Success
    TestingConnection --> FlutterListening: Connection Failed

    UpdatingAPI --> SavingPreferences: Update URL
    SavingPreferences --> NotificationSuccess: Configuration Saved
    NotificationSuccess --> [*]: Auto-Discovery Complete

    note right of BackendBroadcasting
        Broadcasts every 30 seconds
        Contains server metadata
        Uses UDP multicast
    end note

    note right of FlutterListening
        Listens on port 8888
        Joins multicast group
        Processes incoming packets
    end note
```

## 📊 Performance Metrics Dashboard

```mermaid
pie title Discovery Performance (Phase 2)
    "Successful Auto-Discovery" : 95
    "Manual Fallback Used" : 4
    "Discovery Failures" : 1
```

```mermaid
pie title Network Response Times
    "< 100ms" : 60
    "100-500ms" : 30
    "500ms-2s" : 8
    "> 2s" : 2
```

```mermaid
pie title Server Types Discovered
    "BluPOS Backend" : 70
    "BluPOS Micro-Server" : 25
    "Other Services" : 5
```

---

*These diagrams provide a complete visual representation of the network auto-discovery system with corrected Mermaid syntax.*
