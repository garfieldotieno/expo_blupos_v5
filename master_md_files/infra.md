# Expo BLUPOS v5 - Infrastructure Documentation

## Project Overview

Expo BLUPOS v5 is a comprehensive Point of Sale (POS) system built with Flask and SQLAlchemy, designed for retail businesses to manage inventory, process sales, and handle user administration. The system features role-based access control, licensing management, and comprehensive reporting capabilities.

## System Architecture

```mermaid
graph TB
    subgraph "Client Layer"
        A[Web Browser]
        B[Mobile Devices]
    end

    subgraph "Application Layer"
        C[Flask Web Server]
        D[Gunicorn WSGI Server]
    end

    subgraph "Data Layer"
        E[SQLite Database]
        F[File System<br/>Templates, Static Assets]
    end

    subgraph "External Services"
        G[ReportLab<br/>PDF Generation]
        H[QR Code Library]
        I[Barcode Generation]
    end

    A --> C
    B --> C
    C --> D
    D --> E
    D --> F
    D --> G
    D --> H
    D --> I
```

## Database Schema

```mermaid
erDiagram
    User ||--o{ SaleRecord : creates
    User {
        integer id PK
        string uid UK
        string user_name UK
        string role
        string password_hash
        string current_session_key
        float session_end_epoch
        datetime created_at
        datetime updated_at
    }

    License {
        integer id PK
        string uid UK
        string license_key UK
        string license_type
        boolean license_status
        datetime license_expiry
        datetime created_at
        datetime updated_at
    }

    SaleItem ||--|| SaleItemStockCount : tracks
    SaleItem {
        integer id PK
        string uid UK
        string name
        string description
        float price
        string item_type
        datetime created_at
        datetime updated_at
    }

    SaleItemStockCount {
        integer id PK
        string item_uid FK
        integer last_stock_count
        integer current_stock_count
        integer re_stock_value
        boolean re_stock_status
        datetime created_at
    }

    SaleItem ||--o{ SaleItemTransaction : involves
    SaleItemTransaction {
        integer id PK
        string item_uid FK
        enum transaction_type
        integer transaction_quantity
        float item_price
        datetime created_at
    }

    SaleRecord {
        integer id PK
        string uid UK
        string sale_clerk
        float sale_total
        float sale_paid_amount
        float sale_balance
        string payment_method
        string payment_reference
        enum payment_gateway
        datetime created_at
        datetime updated_at
    }
```

## User Roles and Permissions

```mermaid
graph TD
    A[Anonymous User] --> B[Login Required]
    B --> C{User Role}

    C --> D[Admin]
    C --> E[Sale]
    C --> F[Inventory]

    D --> G[User Management<br/>/users]
    D --> H[View Records<br/>/records]
    D --> I[Add/Delete Users<br/>/add_user, /delete_user]

    E --> J[Sales Management<br/>/sales]
    E --> K[Add Sale Records<br/>/add_sale_record]

    F --> L[Inventory Management<br/>/inventory]
    F --> M[Add/Edit Items<br/>/add_item_inventory, /edit_item]
    F --> N[Delete Items<br/>/delete_item_inventory]
    F --> O[Update Stock<br/>/update_item_inventory]
    F --> P[Generate Reports<br/>/get_restock_printout, /get_sale_record_printout]

    A -.-> Q[Public Routes<br/>/, /about, /invalid]
```

## Application Routes and Flow

```mermaid
graph TD
    A["Home /"] --> B{"Authentication Check"}
    B -->|"Not Authenticated"| C["Login Form"]
    B -->|"Authenticated"| D{"Role-based Redirect"}

    D -->|"Admin"| E["/users - User Management"]
    D -->|"Sale"| F["/sales - Sales Interface"]
    D -->|"Inventory"| G["/inventory - Inventory Management"]

    C --> H["/verify - Authentication"]
    H -->|"Success"| D
    H -->|"Failure"| I["/invalid - Error Page"]

    E --> J["License Management"]
    E --> K["User CRUD Operations"]

    F --> L["Product Selection"]
    F --> M["Sale Processing"]
    F --> N["Payment Handling"]

    G --> O["Stock Management"]
    G --> P["Item CRUD"]
    G --> Q["Report Generation"]

    J --> R["License Validation"]
    K --> S["User Creation/Deletion"]
    L --> T["Real-time Price Fetch<br/>/item/<uid>"]
    M --> U["Sale Record Creation<br/>/add_sale_record"]
    O --> V["Stock Updates"]
    P --> W["Item Operations"]
    Q --> X["PDF Report Generation"]
```

## Data Flow: Sales Transaction

```mermaid
sequenceDiagram
    participant U as User (Sale Role)
    participant F as Flask App
    participant DB as SQLite Database
    participant R as ReportLab

    U->>F: POST /add_sale_record
    F->>F: Parse JSON payload
    F->>DB: Create SaleItemTransaction records
    F->>DB: Update SaleItemStockCount (decrement)
    F->>DB: Create SaleRecord
    DB-->>F: Transaction committed
    F-->>U: Success response

    U->>F: GET /get_sale_record_printout
    F->>DB: Query SaleRecord data
    DB-->>F: Return sales data
    F->>R: Generate PDF report
    R-->>F: PDF file
    F-->>U: PDF download
```

## Data Flow: Inventory Management

```mermaid
sequenceDiagram
    participant U as User (Inventory Role)
    participant F as Flask App
    participant DB as SQLite Database

    U->>F: POST /add_item_inventory
    F->>F: Validate item data
    F->>DB: Create SaleItem record
    F->>DB: Create SaleItemStockCount record
    DB-->>F: Records created
    F-->>U: Success redirect

    U->>F: GET /inventory
    F->>DB: Query all SaleItem + StockCount
    DB-->>F: Inventory data
    F->>F: Render inventory_management.html
    F-->>U: Inventory dashboard

    U->>F: POST /update_item_inventory
    F->>DB: Update SaleItem fields
    F->>DB: Update SaleItemStockCount
    DB-->>F: Records updated
    F-->>U: Success redirect
```

## Authentication Flow

```mermaid
sequenceDiagram
    participant U as User
    participant F as Flask App
    participant DB as SQLite Database
    participant S as Session Store

    U->>F: POST /verify (username, password)
    F->>DB: Query User by username
    DB-->>F: User record
    F->>F: Verify password hash
    F->>F: Generate session key
    F->>DB: Update user session info
    F->>S: Set session cookie
    S-->>F: Session established
    F-->>U: Redirect to role-specific page

    U->>F: GET /protected_route
    F->>F: Check session middleware
    F->>S: Validate session
    S-->>F: Session valid
    F->>F: Check route permissions
    F-->>U: Render protected content
```

## License Management System

```mermaid
stateDiagram-v2
    [*] --> NoLicense: Application Start
    NoLicense --> LicensePrompt: User attempts restricted action
    LicensePrompt --> KeyValidation: User enters reset key
    KeyValidation --> LicenseCreated: Valid key
    KeyValidation --> InvalidKey: Invalid key
    InvalidKey --> LicensePrompt: Retry
    LicenseCreated --> ActiveLicense: License activated
    ActiveLicense --> ExpiredLicense: License expires
    ExpiredLicense --> LicensePrompt: Renewal required
    ActiveLicense --> [*]: Application shutdown
```

## Deployment Architecture

```mermaid
graph TB
    subgraph "Development Environment"
        A[Local Machine]
        B[SQLite Database]
        C[Flask Dev Server]
    end

    subgraph "Production Environment (Heroku)"
        D[Heroku Dyno]
        E[PostgreSQL Database]
        F[Gunicorn Server]
        G[Static File Serving]
    end

    subgraph "External Dependencies"
        H[Python Packages<br/>requirements.txt]
        I[System Libraries<br/>buildpacks]
    end

    A --> C
    C --> B
    D --> F
    F --> E
    F --> G
    D --> H
    D --> I
```

## Component Dependencies

```mermaid
graph TD
    A[Flask Application] --> B[Flask-SQLAlchemy]
    A --> C[Flask-CORS]
    A --> D[Werkzeug Security]
    A --> E[ReportLab]
    A --> F[QRCode Library]
    A --> G[JsBarcode]
    A --> H[DataTables]
    A --> I[Splide Carousel]
    A --> J[Bootstrap CSS]

    B --> K[SQLAlchemy ORM]
    K --> L[SQLite Database]

    E --> M[PDF Generation]
    F --> N[QR Code Rendering]
    G --> O[Barcode Generation]
```

## Security Architecture

```mermaid
graph TD
    A[Client Request] --> B[CORS Middleware]
    B --> C[Session Validation]
    C --> D{Role-based Access Control}

    D -->|Admin| E[Full Access Routes]
    D -->|Sale| F[Sales Routes Only]
    D -->|Inventory| G[Inventory Routes Only]
    D -->|Anonymous| H[Public Routes Only]

    E --> I[Route Permission Check]
    F --> I
    G --> I
    H --> I

    I --> J[Database Operations]
    J --> K[Input Validation]
    K --> L[SQL Injection Prevention]
    L --> M[Password Hashing]
    M --> N[Session Management]
```

## Testing Architecture

```mermaid
graph TD
    A[Unit Tests] --> B[TestLicenseResetKey]
    A --> C[TestLicense]
    A --> D[TestInventoryOperation]
    A --> E[TestInitUsers]

    B --> F[License Key Management]
    C --> G[License CRUD Operations]
    D --> H[Inventory CRUD Operations]
    E --> I[User Initialization]

    J[Integration Tests] --> K[API Endpoints]
    J --> L[Database Operations]
    J --> M[Authentication Flow]

    N[Test Runner] --> A
    N --> J
    N --> O[Coverage Reports]
```

## Performance Considerations

```mermaid
graph LR
    A[Client Request] --> B{Load Balancer}
    B --> C[Application Server 1]
    B --> D[Application Server 2]
    B --> E[Application Server N]

    C --> F[Database Connection Pool]
    D --> F
    E --> F

    F --> G[(Database)]
    G --> H[Query Optimization]
    H --> I[Indexing Strategy]
    I --> J[Connection Limits]

    K[Caching Layer] --> L[Session Storage]
    K --> M[Static Assets]
    K --> N[Query Results]
```

## Monitoring and Logging

```mermaid
graph TD
    A[Application Events] --> B[Flask Logging]
    B --> C[Console Output]
    B --> D[File Logging]

    E[Database Operations] --> F[SQLAlchemy Logging]
    F --> C
    F --> D

    G[Error Handling] --> H[Exception Middleware]
    H --> I[Error Pages]
    H --> J[Error Logging]

    K[Performance Metrics] --> L[Response Times]
    K --> M[Database Query Times]
    K --> N[Memory Usage]

    C --> O[Development Monitoring]
    D --> P[Production Log Aggregation]
```

## Backup and Recovery

```mermaid
graph TD
    A[Database Backup] --> B[SQLite Dump]
    B --> C[File System Storage]
    C --> D[Cloud Storage]

    E[Configuration Backup] --> F[shop_config.json]
    E --> G[.pos_keys.yml]
    E --> H[Static Assets]

    I[Recovery Process] --> J[Database Restore]
    I --> K[Configuration Restore]
    I --> L[Application Restart]

    J --> M[Data Integrity Check]
    K --> N[Configuration Validation]
    L --> O[Health Check]
```

## Future Enhancements

```mermaid
mindmap
  root((Expo BLUPOS v6))
    Database
      PostgreSQL Migration
      Database Sharding
      Read Replicas
    API
      REST API Endpoints
      GraphQL Integration
      API Documentation
    Frontend
      React/Vue.js Migration
      Progressive Web App
      Mobile App Development
    Security
      OAuth2 Integration
      Two-Factor Authentication
      Audit Logging
    Analytics
      Sales Analytics Dashboard
      Inventory Forecasting
      Customer Insights
    Integration
      Payment Gateway APIs
      Barcode Scanner Hardware
      Receipt Printer APIs
    Cloud
      AWS/Azure Deployment
      Container Orchestration
      Auto Scaling
```

## Technology Stack Summary

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| Backend Framework | Flask | 2.0.2 | Web application framework |
| Database ORM | SQLAlchemy | 1.4.27 | Database abstraction layer |
| Database | SQLite | - | Data persistence |
| WSGI Server | Gunicorn | 20.1.0 | Production server |
| PDF Generation | ReportLab | 4.0.4 | Report generation |
| QR Codes | qrcode | 7.4.2 | QR code generation |
| Barcodes | JsBarcode | - | Barcode generation |
| UI Framework | Bootstrap | - | Responsive design |
| Data Tables | DataTables | 1.13.6 | Interactive tables |
| Carousel | Splide | 3.1.2 | Image carousel |
| Authentication | Werkzeug | 2.0.2 | Password hashing |
| CORS | Flask-CORS | 3.0.10 | Cross-origin requests |
| Validation | Pydantic | 2.3.0 | Data validation |
| Configuration | YAML | 6.0.1 | Configuration files |

## Environment Configuration

### Development
- **Python**: 3.8+
- **Database**: SQLite (pos_test.db)
- **Server**: Flask development server
- **Port**: 5000 (default)

### Production
- **Platform**: Heroku
- **WSGI Server**: Gunicorn
- **Database**: SQLite (or PostgreSQL on Heroku)
- **Static Files**: Served by web server
- **Environment Variables**: Configured via Heroku dashboard

### Key Configuration Files
- `shop_config.json`: Shop-specific settings
- `.pos_keys.yml`: License reset keys
- `requirements.txt`: Python dependencies
- `Procfile`: Heroku deployment configuration

## API Endpoints Reference

| Endpoint | Method | Role Required | Description |
|----------|--------|---------------|-------------|
| `/` | GET | None | Home page |
| `/verify` | POST | None | User authentication |
| `/logout` | GET | Any | Session termination |
| `/users` | GET | Admin | User management dashboard |
| `/add_user` | POST | Admin | Create new user |
| `/delete_user` | POST | Admin | Delete user |
| `/sales` | GET | Sale | Sales interface |
| `/add_sale_record` | POST | Sale | Process sale transaction |
| `/inventory` | GET | Inventory | Inventory dashboard |
| `/add_item_inventory` | POST | Inventory | Add new inventory item |
| `/update_item_inventory` | POST | Inventory | Update inventory item |
| `/delete_item_inventory` | POST | Inventory | Delete inventory item |
| `/get_restock_printout` | GET | Inventory | Generate restock report |
| `/get_sale_record_printout` | GET | Inventory | Generate sales report |
| `/item/<uid>` | GET | Sale | Get item details for sale |

## Database Migration Path

For future database migrations from SQLite to PostgreSQL:

1. **Schema Export**: Use SQLAlchemy reflection to export current schema
2. **Data Export**: Export all data to JSON/CSV format
3. **Schema Creation**: Create PostgreSQL schema with proper constraints
4. **Data Import**: Import data with type conversions
5. **Testing**: Validate data integrity and application functionality
6. **Performance Tuning**: Add appropriate indexes and optimize queries

## Conclusion

Expo BLUPOS v5 represents a robust, scalable POS solution with comprehensive features for retail management. The modular architecture supports easy maintenance and future enhancements, while the role-based security ensures appropriate access controls. The system's use of modern web technologies and comprehensive testing suite ensures reliability and maintainability.
