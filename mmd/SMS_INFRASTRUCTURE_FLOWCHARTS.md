# SMS Infrastructure Flowcharts

## Overview

This document contains comprehensive Mermaid flowcharts documenting the SMS payment verification and synchronization system, including the current broken flow and the proposed fixed flow using auto-discovery.

## Current SMS Flow (Broken)

### Broken SMS Processing Flow
```mermaid
graph TD
    A[SMS Received] --> B{All SMS: Platform Test}
    A --> C{Is Payment Message?}

    B --> D[Show Blinking SMS Icon<br/>3-Second Animation]
    D --> E[Restore Balance Display]

    C -->|No - Other SMS| F[Animation Only<br/>No Payment Flow]
    C -->|Yes - Payment SMS| G[Extract Payment Data<br/>Channel, Amount, Account]

    G --> H[Send to Backend API<br/>POST /api/sms/process]
    H --> I[APK Tries: localhost:8081]
    I --> J{Connection to 8081?}
    
    J -->|No Connection| K[❌ FAIL: Connection Error]
    J -->|Connection Success| L[Backend Processing]
    
    K --> M[Payment Stuck in Queue]
    M --> N[Sales Remain Pending]
    N --> O[Inventory Not Updated]
    O --> P[Financial Discrepancies]
    
    L --> Q[Payment Reconciliation Service]
    Q --> R{Query Unpaid Sales}
    R --> S[Validate Amount & Account]
    S --> T{Match Found?}

    T -->|Yes| U[Update Sale Record<br/>Clear Balance]
    T -->|No| V[Create Pending Payment<br/>Manual Review]

    U --> W[Success Response<br/>Unblock Sales]
    V --> X[Pending Response<br/>Queue for Clerk]

    W --> Y[Update UI<br/>Payment Status]
    X --> Y

    F --> Z[End - No Payment Processing]
    Y --> AA[End - Payment Processed]
```

### Current Port Configuration Issues
```mermaid
graph TB
    A[APK SMS Service] --> B[Hardcoded: localhost:8081]
    B --> C{Port 8081 Available?}
    C -->|No| D[❌ Connection Failed]
    C -->|Yes| E[Connect to SMS Service]
    
    F[Backend SMS Service] --> G[Runs on: localhost:8081]
    G --> H[Separate Process]
    
    I[Main Backend] --> J[Runs on: localhost:8080]
    J --> K[Network Discovery: 8888]
    
    L[Auto-Discovery System] --> M[Discovers: localhost:8080]
    M --> N[APK Uses: localhost:8080]
    
    O[Problem] --> P[APK connects to 8081<br/>but SMS service runs on 8080]
    P --> Q[Complete Communication Failure]
```

## Proposed Fixed SMS Flow (With Auto-Discovery)

### Fixed SMS Processing Flow
```mermaid
graph TD
    A[SMS Received] --> B{All SMS: Platform Test}
    A --> C{Is Payment Message?}

    B --> D[Show Blinking SMS Icon<br/>3-Second Animation]
    D --> E[Restore Balance Display]

    C -->|No - Other SMS| F[Animation Only<br/>No Payment Flow]
    C -->|Yes - Payment SMS| G[Extract Payment Data<br/>Channel, Amount, Account]

    G --> H[Use Auto-Discovery<br/>Get Backend URL]
    H --> I[Discover Port: 8080]
    I --> J[Send to Backend API<br/>POST /api/sms/process]
    J --> K[Backend Processing]
    
    K --> L[Payment Reconciliation Service]
    L --> M{Query Unpaid Sales}
    M --> N[Validate Amount & Account]
    N --> O{Match Found?}

    O -->|Yes| P[Update Sale Record<br/>Clear Balance]
    O -->|No| Q[Create Pending Payment<br/>Manual Review]

    P --> R[Success Response<br/>Unblock Sales]
    Q --> S[Pending Response<br/>Queue for Clerk]

    R --> T[Update UI<br/>Payment Status]
    S --> T

    F --> U[End - No Payment Processing]
    T --> V[End - Payment Processed]
```

### Auto-Discovery Integration Flow
```mermaid
graph TB
    A[APK SMS Service] --> B[Initialize Auto-Discovery]
    B --> C[Scan Network: 8888]
    C --> D{Broadcast Response?}
    
    D -->|Yes| E[Get Backend IP:Port]
    D -->|No| F[Port Scanning: 5000, 8080, 8000]
    
    E --> G[Store: discovered_url]
    F --> H{Port Found?}
    H -->|Yes| I[Store: discovered_url]
    H -->|No| J[Use Default: localhost:8080]
    
    I --> K[Use discovered_url for SMS API]
    J --> K
    G --> K
    
    K --> L[Send SMS to: discovered_url/api/sms/process]
    L --> M[Success: Dynamic Port Resolution]
```

### Unified Service Architecture
```mermaid
graph TB
    A[Main Backend Service] --> B[Port: 8080]
    B --> C[Network Discovery: 8888]
    
    C --> D[APK Discovers: localhost:8080]
    D --> E[All Services on Single Port]
    
    E --> F[Sales Endpoints: /api/sales/*]
    E --> G[SMS Endpoints: /api/sms/*]
    E --> H[User Endpoints: /api/users/*]
    E --> I[Inventory Endpoints: /api/inventory/*]
    
    J[APK Services] --> K[Use discovered_url]
    K --> L[Sales Service: discovered_url/api/sales]
    K --> M[SMS Service: discovered_url/api/sms]
    K --> N[User Service: discovered_url/api/users]
    K --> O[Inventory Service: discovered_url/api/inventory]
    
    P[Benefits] --> Q[Single Port Management]
    P --> R[Unified Monitoring]
    P --> S[Simplified Deployment]
    P --> T[Automatic Port Resolution]
```

## SMS Payment Reconciliation Flow

### Enhanced Reconciliation with Payment Queue
```mermaid
graph TD
    A[SMS Payment Detected] --> B[Parse Payment Data]
    B --> C[Check for Pending Checkout]
    
    C -->|No Pending Checkout| D[Create Pending Payment Record]
    C -->|Pending Checkout Found| E[Add to Payment Queue]
    
    E --> F[Queue Payment for Clerk Selection]
    F --> G{Payment Queue Has Items?}
    
    G -->|Yes| H[Show Payment Selection UI]
    G -->|No| I[Wait for Payments]
    
    H --> J{Clerk Selects Payment?}
    J -->|Yes| K[Show Selected Payment Details]
    J -->|No| L[Keep Waiting]
    
    K --> M{Clerk Confirms Match?}
    M -->|No| N[Return to Selection]
    M -->|Yes| O[Update Sale Record with Balance]
    
    O --> P[Remove Payment from Queue]
    P --> Q[Update Sale Tables]
    Q --> R[Update APK UI]
    R --> S[Show Latest 4 Payments]
    S --> T{Balance = 0?}
    
    T -->|Yes| U[Unblock New Sales]
    T -->|No| V[Keep Sales Blocked]
    
    D --> W[Return Pending Created]
    N --> X[Return Rejected]
    W --> Y[Return Success]
    X --> Y
    U --> Z[End - Sales Unblocked]
    V --> AA[End - Sales Still Blocked]
```

### Payment Queue Management
```mermaid
graph TD
    A[Payment Queue] --> B[Queue Entry Structure]
    B --> C[Payment ID]
    B --> D[Payment Data]
    B --> E[Pending Checkout Info]
    B --> F[Received Time]
    B --> G[Status]
    
    H[Queue Operations] --> I[Add Payment]
    H --> J[Select Payment]
    H --> K[Confirm Payment]
    H --> L[Reject Payment]
    H --> M[Clear Queue]
    
    I --> N[Generate Unique ID]
    I --> O[Store Payment Data]
    I --> P[Link to Pending Checkout]
    I --> Q[Set Status: queued]
    
    J --> R[Find Payment by ID]
    J --> S[Return Payment Details]
    J --> T[Return Pending Checkout]
    
    K --> U[Validate Payment Match]
    K --> V[Update Sale Record]
    K --> W[Remove from Queue]
    K --> X[Update Status: reconciled]
    
    L --> Y[Remove from Queue]
    L --> Z[Set Status: rejected]
    
    M --> AA[Clear All Payments]
    M --> BB[Reset Queue Length]
```

## Database Schema Relationships

### Enhanced Sale Record with Blocking Status
```mermaid
erDiagram
    SaleRecord ||--o{ PendingPayment : "has_pending"
    SaleRecord ||--|| PaymentQueue : "has_queue"
    
    SaleRecord {
        int id PK
        string uid
        string sale_clerk
        float sale_total
        float sale_paid_amount
        float sale_balance
        string payment_method
        string payment_reference
        string payment_gateway
        datetime created_at
        datetime updated_at
        string checkout_id
        string checkout_status
    }
    
    PendingPayment {
        int id PK
        string channel
        float amount
        string account
        string sender
        string reference
        text message
        datetime received_at
        string status
        int matched_sale_id FK
        text notes
    }
    
    PaymentQueue {
        string payment_id PK
        json payment_data
        json pending_checkout
        datetime received_at
        string status
    }
    
    PendingPayment }o--|| SaleRecord : "matched_to"
```

### Payment Flow State Transitions
```mermaid
stateDiagram-v2
    [*] --> SMS_Received: SMS Detected
    SMS_Received --> Payment_Parsed: Extract Data
    Payment_Parsed --> Pending_Checkout_Check: Check Status
    
    Pending_Checkout_Check --> Payment_Queue: Add to Queue
    Pending_Checkout_Check --> Pending_Payment: Create Manual Review
    
    Payment_Queue --> Clerk_Selection: Show Queue
    Clerk_Selection --> Payment_Selected: Select Payment
    Clerk_Selection --> Payment_Queue: Keep Waiting
    
    Payment_Selected --> Clerk_Confirmation: Show Details
    Clerk_Confirmation --> Payment_Confirmed: Confirm Match
    Clerk_Confirmation --> Payment_Rejected: Reject Payment
    
    Payment_Confirmed --> Sale_Updated: Update Record
    Payment_Rejected --> Payment_Queue: Return to Queue
    
    Pending_Payment --> Manual_Review: Review Required
    Manual_Review --> Sale_Updated: Match Found
    Manual_Review --> Pending_Payment: Keep Pending
    
    Sale_Updated --> Sales_Unblocked: Balance = 0
    Sale_Updated --> Sales_Blocked: Balance > 0
    
    Sales_Unblocked --> [*]
    Sales_Blocked --> Payment_Queue: Wait for More Payments
```

## Auto-Discovery Service Architecture

### Network Discovery Flow
```mermaid
sequenceDiagram
    participant APK as APK App
    participant ND as Network Discovery
    participant BC as Backend Service
    participant DB as Database
    
    APK->>ND: Start Discovery (Port 8888)
    ND->>BC: Broadcast Request
    BC->>ND: Broadcast Response
    ND->>APK: Return Backend URL
    
    APK->>BC: HTTP Request (Discovered Port)
    BC->>DB: Process Request
    DB->>BC: Return Data
    BC->>APK: HTTP Response
    
    Note over APK,BC: Fallback: Port Scanning (5000, 8080, 8000)
    Note over APK,BC: Default: localhost:8080
```

### Service Integration Architecture
```mermaid
graph TB
    subgraph "APK Layer"
        A[SMS Service] --> B[Reconciliation Service]
        B --> C[Auto-Discovery Service]
        C --> D[API Client]
    end
    
    subgraph "Network Layer"
        E[UDP Broadcast: 8888]
        F[HTTP Communication]
        G[Port Scanning]
    end
    
    subgraph "Backend Layer"
        H[Main Service: 8080]
        I[Sales Endpoints]
        J[SMS Endpoints]
        K[User Endpoints]
        L[Inventory Endpoints]
        M[Database]
    end
    
    D --> E
    D --> F
    D --> G
    F --> H
    H --> I
    H --> J
    H --> K
    H --> L
    H --> M
```

## Error Handling and Recovery

### Error Recovery Flow
```mermaid
graph TD
    A[Error Occurred] --> B{Error Type}
    
    B -->|Network Error| C[Retry with Exponential Backoff]
    B -->|Parsing Error| D[Log Error, Create Pending Payment]
    B -->|Validation Error| E[Return Error to User]
    B -->|Database Error| F[Rollback Transaction, Log Error]
    
    C --> G{Retry Count < Max?}
    G -->|Yes| H[Wait and Retry]
    G -->|No| I[Give Up, Create Manual Review]
    
    H --> J{Success?}
    J -->|Yes| K[Continue Processing]
    J -->|No| L[Increment Retry Count]
    L --> C
    
    I --> M[Log Error Details]
    M --> N[Notify Administrator]
    N --> O[Manual Intervention Required]
    
    D --> P[Store in Pending Payments]
    E --> Q[Show User Error Message]
    F --> R[Alert System Administrator]
```

### Service Health Monitoring
```mermaid
graph TB
    A[Service Health Check] --> B{Service Available?}
    
    B -->|Yes| C[Service Healthy]
    B -->|No| D[Service Unhealthy]
    
    C --> E[Update Status: Healthy]
    E --> F[Continue Normal Operation]
    
    D --> G[Check Service Dependencies]
    G --> H{Dependencies Healthy?}
    
    H -->|Yes| I[Service Restart Required]
    H -->|No| J[Dependency Issue]
    
    I --> K[Restart Service]
    K --> L{Restart Success?}
    L -->|Yes| M[Service Restored]
    L -->|No| N[Escalate to Admin]
    
    J --> O[Fix Dependencies]
    O --> P[Service Restored]
    
    M --> Q[Update Status: Healthy]
    P --> Q
    N --> R[Manual Intervention]
```

## Performance Optimization

### Caching Strategy
```mermaid
graph TD
    A[Request Received] --> B{Cache Hit?}
    
    B -->|Yes| C[Return Cached Response]
    B -->|No| D[Process Request]
    
    D --> E[Store in Cache]
    E --> F[Return Response]
    
    G[Cache Management] --> H[LRU Eviction]
    G --> I[Time-based Expiry]
    G --> J[Memory Usage Monitoring]
    
    H --> K[Remove Oldest Items]
    I --> L[Remove Expired Items]
    J --> M[Monitor Cache Size]
```

### Load Balancing Strategy
```mermaid
graph TB
    A[Request Load] --> B[Load Balancer]
    B --> C{Load Distribution}
    
    C --> D[Backend Instance 1]
    C --> E[Backend Instance 2]
    C --> F[Backend Instance N]
    
    D --> G[Process Request]
    E --> G
    F --> G
    
    G --> H[Response Aggregation]
    H --> I[Return Response]
    
    J[Health Monitoring] --> K[Instance Status]
    K --> L{Instance Healthy?}
    L -->|No| M[Remove from Pool]
    L -->|Yes| N[Keep in Pool]
```

These flowcharts provide a comprehensive view of the SMS infrastructure, highlighting the current issues and the proposed solutions using auto-discovery to create a robust, scalable, and maintainable SMS payment verification system.
