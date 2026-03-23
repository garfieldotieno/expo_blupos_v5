# Menu Interface Design Adjustments - APK

**Date:** January 22, 2026, 11:34 PM (Africa/Nairobi, UTC+3:00)
**Timestamp:** 20260122_233400

## Overview
Adjusting the menu interface in the APK to have a more cohesive design with the payment listing interface. The menu will be redesigned to match the payment card styling with lighter, glass-like blue theme.

## Current Menu Structure
- Back Button
- Checkout Button
- Sales Button
- Items Button
- Share Button

## Proposed Menu Structure
- Checkout (with summary data display)
- Sales (navigates to PDF report)
- Items (navigates to PDF report)
- About (plain display, no navigation)

## Design Requirements

### Visual Style
- Match the payment listing interface design
- Use lighter, glass-like blue color scheme (persist blue theme but lighter)
- Rounded corners, borders, shadows consistent with payment cards
- Full-width button layout maintained

### Functional Requirements

#### Checkout Button
- **Display:** Always show summary data from latest sales report
- **Data Points:** Total sales amount, total transactions, total paid, total balance
- **Layout:** Display in clockwise fashion (circular arrangement)
- **Navigation:** No navigation (static display)

#### Sales Button
- **Display:** Standard button
- **Navigation:** Opens sales report PDF interface (existing functionality)

#### Items Button
- **Display:** Show inventory restock summary data
- **Data Points:** Select 4 vital inventory metrics
- **Layout:** Display in clockwise fashion (circular arrangement)
- **Navigation:** Opens items report PDF interface (existing functionality)

#### About Button
- **Display:** Plain button with basic app information
- **Navigation:** No navigation (static display)

### Backend Integration
- Update/create endpoints to provide summary data for checkout and items displays
- Ensure summary data is extracted from existing sales report and inventory systems
- Maintain real-time data updates where applicable

### Navigation Logic
- Checkout: No navigation
- Sales: PDF report interface
- Items: PDF report interface
- About: No navigation

## Implementation Plan
1. Analyze current backend endpoints for summary data availability
2. Create/update backend endpoints for checkout summary and inventory summary
3. Update Flutter UI to match payment listing styling
4. Implement clockwise data display for checkout and items
5. Apply glass-like blue theme
6. Update navigation logic
7. Test all functionality

## Color Theme
- Base: Current blue (#FF182A62)
- New: Lighter glass-like variant with transparency effects
- Maintain consistency with existing blue theme but with lighter opacity

## Data Sources
- Checkout Summary: Latest sales report data (total_sales, transactions, paid_amount, balance)
- Items Summary: Inventory restock data (select 4 vital metrics from restock system)
- About: Static app information (version, developer, etc.)

## Progress Update
- [x] Explore current APK structure and menu interface
- [x] Generate timestamped .md file with design discussion
- [x] Analyze backend endpoints for necessary updates
- [x] Update UI to match EXACT pending payment card format
- [x] Implement clickable menu buttons with proper navigation
- [x] Apply glass-like gradient background
- [x] Update navigation logic: checkout (no nav), sales/items (PDF reports), about (snackbar)
- [x] Display real backend summary data from PDF source in pending payment format
- [x] Sales button shows summary data from `/api/sales_report_data` (same as PDF generation)
