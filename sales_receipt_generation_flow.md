# Sales Receipt Generation Flow

## Overview

This document describes the complete flow of sales receipt generation in the POS (Point of Sale) system, from item selection through payment processing to receipt generation and printing.

## User Journey Flow

### Phase 1: Item Selection and Cart Management

#### Auto Sale Mode (Default)
1. **Interface**: `templates/sales_management.html`
2. **User Action**: Scan item codes or manually enter them in the code input field
3. **JavaScript Function**: `upload_item_code()` or `fetch_item(item_code)`
4. **Process**:
   - Item code is sent to `/item/<uid>` endpoint
   - Backend fetches item details from `SaleItem` table
   - Item is added to cart via `add_item()` function
   - Cart data stored in localStorage as `current_items_pack`
5. **Display**: Items appear in the cart table with ID, Name, Price, and Delete button

#### Manual Sale Mode
1. **Switch Mode**: Click "Manual" button to toggle input modes
2. **User Action**: Enter item codes manually in the text input
3. **Process**: Same as Auto Sale but with manual input validation

### Phase 2: Checkout Process

#### Initiate Checkout
1. **Trigger**: Click "Checkout" button when items are in cart
2. **Action**: `switch_to_checkout()` function
3. **UI Change**:
   - Sale container hidden
   - Checkout container displayed
   - Items listed in checkout table
   - Current timestamp added to receipt preview

#### Payment Processing
1. **Payment Method Selection**:
   - **Cash**: Shows cash payment input field
   - **MPESA**: Shows gateway selection, payment amount, and reference fields

2. **Payment Validation**:
   - Click "Add" button calls `update_payment()`
   - Validates payment amount ≥ sale total
   - Updates payment details in localStorage

3. **Finalize Sale**:
   - Click "Checkout" button calls `add_sale_record()`
   - Sends POST request to `/add_sale_record` endpoint
   - Backend processes sale record creation

### Phase 3: Sale Record Creation

#### Backend Processing (`/add_sale_record`)
1. **Sale Record Creation**:
   - Creates `SaleRecord` entry with:
     - Unique ID (10-character random string)
     - Clerk name, total, payment amount, balance
     - Payment method, reference, gateway

2. **Item Transactions**:
   - Creates `SaleItemTransaction` records for each item
   - Links transactions to sale via `sale_id`
   - Records quantity and price per item

3. **Inventory Update**:
   - Reduces `current_stock_count` in `SaleItemStockCount` table
   - Updates stock for each sold item

4. **Response**: Returns sale record with ID and UID

### Phase 4: Receipt Generation (PDF Download)

#### Primary Option: PDF Receipt Download
1. **Trigger**: After successful checkout, "Download Receipt" button appears
2. **Function**: `download_sale_receipt()` retrieves stored sale_id and initiates PDF download
3. **Process**:
   - Retrieves `last_sale_id` from localStorage (stored after successful checkout)
   - Constructs PDF download URL: `/download-sale-receipt/{sale_id}`
   - Creates temporary link element and triggers browser download
   - Backend endpoint processes the request and returns PDF file

#### Backend PDF Generation Details
1. **Endpoint**: `GET /download-sale-receipt/<int:sale_id>`
2. **Authentication**: User session validation (currently bypassed for development)
3. **Data Retrieval**:
   - Fetches sale record from `SaleRecord` table
   - Retrieves associated `SaleItemTransaction` records
   - Gathers shop configuration data
4. **Content Generation**:
   - Generates barcode and QR code using backend functions
   - Renders `sales_receipt_template.html` with complete sale data
   - Converts HTML to PDF using `xhtml2pdf` library
   - Returns PDF file with filename `receipt_{sale_uid}.pdf`

#### PDF Receipt Features
- **Professional Layout**: A4-sized receipt with structured formatting
- **Complete Sale Details**: Items, totals, payment information, clerk details
- **Embedded Codes**: Base64-encoded barcode and QR code images
- **Shop Branding**: Logo, contact information, and styling
- **Digital Timestamp**: Generation time and sale date/time

## Technical Components

### Frontend Components
- **HTML Template**: `templates/sales_management.html`
- **JavaScript**: `static/js/main.js`
- **Libraries**:
  - JsBarcode: For barcode generation in thermal receipts
  - QRCode.js: For QR code generation in thermal receipts
  - printJS: For thermal printing functionality

### Backend Components
- **Main Application**: `backend.py`
- **Database Models**:
  - `SaleRecord`: Sale transaction data
  - `SaleItemTransaction`: Individual item sales
  - `SaleItem`: Product catalog
  - `SaleItemStockCount`: Inventory tracking
- **Libraries**:
  - `xhtml2pdf`: HTML to PDF conversion
  - `reportlab`: Barcode generation for PDF
  - `qrcode`: QR code generation for PDF

### Receipt Templates
- **PDF Receipt**: `templates/sales_receipt_template.html`
  - A4-sized professional layout
  - Full sale details, barcodes, QR codes
- **Thermal Receipt**: Built into `sales_management.html` (#print_template div)
  - 80mm width optimized for thermal printers
  - Immediate printing capability

## Data Flow Diagram

```
User Action → JavaScript → localStorage → Backend API → Database → Receipt Generation
     ↓             ↓             ↓            ↓           ↓              ↓
1. Scan/Add → fetch_item() → current_items_pack → /add_sale_record → SaleRecord → PDF Download
2. Items     → add_item()   → item_array[]      → POST payload      → Transactions → /download-sale-receipt/<id>
3. Payment  → set_payment() → payment_details   → validation        → Stock Update → last_sale_id stored
4. Checkout → add_sale_record() → server response → success/failure → Download Receipt button
```

## Key Functions and Endpoints

### JavaScript Functions (main.js)
- `fetch_item(item_code)`: API call to get item details
- `add_item()`: Add item to cart
- `update_payment()`: Validate and set payment details
- `add_sale_record()`: Submit sale to backend, stores sale_id in localStorage
- `download_sale_receipt()`: Initiates PDF download using stored sale_id
- `generateBarcode()` / `generateQRCode()`: Client-side code generation (legacy)

### Backend Endpoints (backend.py)
- `GET /item/<uid>`: Fetch item details
- `POST /add_sale_record`: Create sale record and transactions
- `GET /download-sale-receipt/<sale_id>`: Generate and download PDF receipt

### Backend Helper Functions
- `generate_barcode_base64()`: ReportLab barcode for PDF
- `generate_qrcode_base64()`: qrcode library for QR codes
- `load_shop_data()`: Get shop configuration

## Error Handling and Validation

### Frontend Validation
- Item code existence check
- Payment amount validation (must be ≥ sale total)
- Empty input prevention
- localStorage availability check

### Backend Validation
- User authentication for receipt downloads
- Sale record existence verification
- Item availability in inventory
- Payment method and gateway validation

## Receipt Content Structure

### Thermal Receipt (Immediate Print)
```
┌─────────────────────────────────────────┐
│           SHOP HEADER                   │
│  Logo, Name, Address, Phone             │
├─────────────────────────────────────────┤
│           ITEMS LIST                    │
│  # Item Name                    Price   │
│  1 Product A                   $10.00   │
├─────────────────────────────────────────┤
│           TOTALS                       │
│  Sub Total: $10.00                     │
│  VAT Total: $1.60                      │
│  Total: $11.60                         │
│  Cash: $12.00                          │
│  Change: $0.40                         │
├─────────────────────────────────────────┤
│           TRANSACTION CODE              │
│           1234567890                    │
├─────────────────────────────────────────┤
│           BARCODES                      │
│  [Barcode Image]     [QR Code Image]    │
├─────────────────────────────────────────┤
│           TIMESTAMP                     │
│  Served by: Clerk Name                  │
│  Date/Time: 2025-12-17 18:46:00         │
│  Thanks for shopping with us!           │
└─────────────────────────────────────────┘
```

### PDF Receipt (Download)
- Professional A4 layout with full details
- Company branding and contact information
- Complete itemization with descriptions
- Payment and transaction details
- Embedded barcode and QR code images
- Digital timestamp and receipt number

## Integration Points

### Inventory Management
- Stock levels updated on successful sale
- Low stock alerts triggered
- Transaction history maintained

### Payment Processing
- Cash payments: Direct amount validation
- MPESA payments: Gateway selection and reference tracking
- Balance/change calculations

### User Management
- Sale clerk tracking per transaction
- Role-based access control
- Session management for secure operations

## Performance Considerations

### Client-Side Optimization
- localStorage for cart persistence
- Immediate UI feedback
- Minimal API calls during item scanning

### Server-Side Optimization
- Efficient database queries
- Image generation caching opportunities
- PDF generation on-demand

## Security Measures

### Data Protection
- User session validation
- Input sanitization
- SQL injection prevention via SQLAlchemy

### Access Control
- Role-based permissions (Admin, Sale, Inventory)
- Route protection middleware
- Authentication required for sensitive operations

## Future Enhancements

### Potential Improvements
1. **Real-time Inventory Sync**: Live stock updates across devices
2. **Offline Mode**: Cart persistence and sync when online
3. **Receipt Customization**: User-configurable templates
4. **Email Receipts**: Automated customer notifications
5. **Multi-store Support**: Location-based configurations
6. **Advanced Payment Options**: Card payments, digital wallets

---

*This document provides a comprehensive overview of the sales receipt generation flow. For technical implementation details, refer to the individual component documentation and source code.*
