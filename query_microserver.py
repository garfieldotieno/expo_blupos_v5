#!/usr/bin/env python3
"""
Interactive Micro-Server Endpoint Query Tool for BluPOS
Queries the predefined micro-server endpoints at any given time

Usage:
    python query_microserver.py          # Interactive mode
    python query_microserver.py [endpoint] # Direct query mode

Endpoints:
    health              - Health check and server status
    message/<id>       - Get specific SMS message by ID
    sms/shortcodes     - SMS from approved shortcodes only
    sms/not-shortcodes - SMS from regular phone numbers (scams)
    sms/read          - Read SMS only
    sms/not-read      - Unread SMS only
    activate           - Check activation status
    test               - Run test utilities

Examples:
    python query_microserver.py health
    python query_microserver.py sms/shortcodes
    python query_microserver.py sms/not-read
    python query_microserver.py message/1767812249000
"""

import requests
import json
import sys
import sqlite3
import threading
import time
from datetime import datetime

# Configuration
MICROSERVER_BASE_URL = "http://localhost:8085"
REQUEST_TIMEOUT = 10

class MicroServerQuerier:
    """Query tool for micro-server endpoints"""

    def __init__(self, base_url=None):
        if base_url is None:
            base_url = self._detect_server_url()
        self.base_url = base_url.rstrip('/')
        self.session = requests.Session()

    def _detect_server_url(self):
        """Auto-detect the best server URL for connecting to micro-server"""
        base_port = int(MICROSERVER_BASE_URL.split(':')[2])
        possible_ports = [base_port, base_port + 1, base_port - 1]  # Try 8085, 8086, 8084

        for port in possible_ports:
            # First try localhost (for standalone server or direct access)
            localhost_url = f"http://localhost:{port}"

            # Check if localhost is accessible
            try:
                response = requests.get(f"{localhost_url}/health", timeout=2)
                if response.status_code == 200:
                    if port != base_port:
                        print(f"🔗 Auto-detected server on alternative port {port}")
                    return localhost_url
            except requests.exceptions.RequestException:
                pass

            # If localhost doesn't work, try emulator IP
            emulator_url = f"http://10.0.2.2:{port}"
            try:
                response = requests.get(f"{emulator_url}/health", timeout=2)
                if response.status_code == 200:
                    print(f"🔗 Auto-detected emulator connection on port {port}")
                    return emulator_url
            except requests.exceptions.RequestException:
                pass

        # Default fallback
        print("⚠️ Could not auto-detect server, using default configuration")
        return MICROSERVER_BASE_URL

    def check_server_status(self):
        """Check if the micro-server is running and accessible"""
        try:
            print("🔍 Checking micro-server connectivity...")
            response = self.session.get(f"{self.base_url}/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                print("✅ Micro-server is running and responding")
                print(f"   📱 Device ID: {data.get('server_info', {}).get('device_id', 'Unknown')}")
                print(f"   📊 Status: {data.get('status', 'Unknown')}")
                return True
            else:
                print(f"⚠️ Micro-server responded with status {response.status_code}")
                return False
        except requests.exceptions.RequestException as e:
            print(f"❌ Cannot connect to micro-server: {e}")
            print("\n💡 TROUBLESHOOTING:")
            print("   • Make sure the Flutter app is running")
            print("   • The micro-server runs on port 8085 when the app starts")
            print("   • Check if any firewall is blocking the connection")
            print("   • Try starting the micro-server manually:")
            print("     python start_microserver.py")
            return False

    def query_endpoint(self, endpoint, method='GET', **kwargs):
        """Query a specific endpoint"""
        url = f"{self.base_url}/{endpoint.lstrip('/')}"

        print(f"🔍 Querying: {method} {url}")
        print(f"⏰ Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("-" * 60)

        try:
            if method.upper() == 'GET':
                response = self.session.get(url, timeout=REQUEST_TIMEOUT, **kwargs)
            elif method.upper() == 'POST':
                response = self.session.post(url, timeout=REQUEST_TIMEOUT, **kwargs)
            else:
                print(f"❌ Unsupported method: {method}")
                return False

            print(f"📊 Status: {response.status_code}")
            print(f"📏 Response Size: {len(response.text)} bytes")
            print(f"⚡ Response Time: {response.elapsed.total_seconds():.3f}s")
            print()

            # Try to parse JSON
            try:
                data = response.json()
                self._pretty_print_json(data)
                return True
            except json.JSONDecodeError:
                print("📄 Raw Response:")
                print(response.text)
                return response.status_code == 200

        except requests.exceptions.RequestException as e:
            print(f"❌ Request failed: {e}")
            return False

    def _pretty_print_json(self, data, indent=0):
        """Pretty print JSON response"""
        if isinstance(data, dict):
            for key, value in data.items():
                if isinstance(value, (dict, list)):
                    print("  " * indent + f"📁 {key}:")
                    self._pretty_print_json(value, indent + 1)
                else:
                    print("  " * indent + f"📄 {key}: {value}")
        elif isinstance(data, list):
            for i, item in enumerate(data):
                if isinstance(item, (dict, list)):
                    print("  " * indent + f"📋 [{i}]:")
                    self._pretty_print_json(item, indent + 1)
                else:
                    print("  " * indent + f"📋 [{i}]: {item}")
        else:
            print("  " * indent + str(data))

    def export_valid_payments(self):
        """Process only shortcodes and exports them to backend"""
        print("🔄 Exporting valid payments from shortcodes to backend...")

        try:
            # Query SMS from approved shortcodes
            url = f"{self.base_url}/sms/shortcodes"
            response = self.session.get(url, timeout=REQUEST_TIMEOUT)

            if response.status_code != 200:
                print(f"❌ Failed to get shortcode SMS: {response.status_code}")
                return False

            sms_data = response.json()
            messages = sms_data.get('messages', [])

            if not messages:
                print("ℹ️ No shortcode SMS messages found")
                return True

            print(f"📱 Found {len(messages)} shortcode messages")

            # Backend URL for payment processing
            backend_url = "http://localhost:8080"  # Assuming backend runs on 8080

            # Process each message
            exported_count = 0
            for msg in messages:
                try:
                    # Extract payment info from message - adjust field names based on actual microserver response
                    # Microserver returns 'body' instead of 'message', and channel needs to be extracted from content
                    message_text = msg.get('body', '')  # Use 'body' field from microserver

                    # Extract channel from message content (Account number in the message)
                    channel = ''
                    reference = ''
                    if 'account' in message_text.lower():
                        # Extract account number from message like "Account 80872" or "merchant account 57938"
                        import re
                        account_match = re.search(r'(?:merchant\s+)?[Aa]ccount\s+(\d+)', message_text)
                        if account_match:
                            channel = account_match.group(1)

                        # Extract reference (multiple formats)
                        # Format 1: "ref #ABC123" (57938 merchant account format)
                        ref_match = re.search(r'ref\s*#\s*([A-Z0-9]+)', message_text, re.IGNORECASE)
                        if ref_match:
                            reference = ref_match.group(1)
                            print(f"   🔗 Reference extracted via 'ref #' format: '{reference}'")
                        else:
                            # Format 2: "ABC123~" (reference before tilde, 80872 account format)
                            tilde_match = re.search(r'([A-Z0-9]+)~', message_text)
                            if tilde_match:
                                reference = tilde_match.group(1)
                                print(f"   🔗 Reference extracted via '~' format: '{reference}'")
                            else:
                                print(f"   ⚠️ No reference found in message")

                    # Debug: Print message data to see what's available
                    print(f"🔍 Processing message ID {msg.get('id', 'unknown')}:")
                    print(f"   📄 Full message data: {msg}")
                    print(f"   🔍 Extracted channel: '{channel}' (length: {len(channel)})")
                    print(f"   🔗 Extracted reference: '{reference}' (length: {len(reference)})")
                    print(f"   📝 Extracted message: '{message_text[:50]}...' (length: {len(message_text)})")

                    # Validate required fields
                    if not channel or not message_text:
                        print(f"⚠️ Skipping message {msg.get('id', 'unknown')}: missing channel or message")
                        continue

                    # Send to backend SMS processing endpoint (microserver version bypasses auth)
                    payment_data = {
                        'channel': channel,
                        'message': message_text,
                        'reference': reference if reference else None
                    }

                    backend_response = requests.post(
                        f"{backend_url}/api/sms/process_microserver",
                        json=payment_data,
                        timeout=10
                    )

                    if backend_response.status_code == 200:
                        exported_count += 1
                        print(f"✅ Exported payment from channel {channel}")
                    else:
                        print(f"⚠️ Failed to export payment from channel {channel}: {backend_response.status_code}")
                        # Print backend error response for debugging
                        try:
                            error_data = backend_response.json()
                            print(f"   Backend error: {error_data.get('message', 'Unknown error')}")
                        except:
                            print(f"   Backend response: {backend_response.text[:200]}...")

                except Exception as e:
                    print(f"❌ Error processing message {msg.get('id', 'unknown')}: {e}")

            print(f"📊 Successfully exported {exported_count}/{len(messages)} payments to backend")
            return True

        except Exception as e:
            print(f"❌ Error in export_valid_payments: {e}")
            return False

    def sync_inventory(self):
        """Start background process to download inventory data from backend into sqlite tables"""
        print("🔄 Starting inventory synchronization...")

        def sync_worker():
            """Background worker for inventory sync"""
            try:
                print("🔄 Inventory sync worker started")

                # Backend URL
                backend_url = "http://localhost:8080"

                # Create local database tables if they don't exist
                db_path = "microserver_inventory.db"
                with sqlite3.connect(db_path) as conn:
                    cursor = conn.cursor()

                    # Create inventory tables
                    cursor.execute('''
                        CREATE TABLE IF NOT EXISTS inventory_items (
                            uid TEXT PRIMARY KEY,
                            name TEXT NOT NULL,
                            description TEXT,
                            price REAL NOT NULL,
                            item_type TEXT,
                            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                        )
                    ''')

                    cursor.execute('''
                        CREATE TABLE IF NOT EXISTS inventory_stock (
                            item_uid TEXT PRIMARY KEY,
                            current_stock INTEGER DEFAULT 0,
                            last_stock_count INTEGER DEFAULT 0,
                            re_stock_value INTEGER DEFAULT 0,
                            re_stock_status BOOLEAN DEFAULT FALSE,
                            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (item_uid) REFERENCES inventory_items (uid)
                        )
                    ''')

                    cursor.execute('''
                        CREATE TABLE IF NOT EXISTS sync_status (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            sync_type TEXT NOT NULL,
                            last_sync TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            status TEXT DEFAULT 'success',
                            records_synced INTEGER DEFAULT 0
                        )
                    ''')

                    conn.commit()

                print("📊 Local inventory database initialized")

                # Sync inventory data recursively
                page = 1
                total_synced = 0

                while True:
                    try:
                        # Get paginated inventory data from backend (microserver version bypasses auth)
                        response = requests.get(
                            f"{backend_url}/api/inventory/items_microserver/{page}",
                            timeout=REQUEST_TIMEOUT
                        )

                        if response.status_code != 200:
                            print(f"⚠️ Failed to get inventory page {page}: {response.status_code}")
                            break

                        data = response.json()
                        items = data.get('items', [])
                        total_pages = data.get('total_pages', 1)

                        if not items:
                            break

                        print(f"📦 Processing page {page}/{total_pages} ({len(items)} items)")

                        # Store items in local database
                        with sqlite3.connect(db_path) as conn:
                            cursor = conn.cursor()

                            for item in items:
                                # Check for existing item to ensure atomicity
                                cursor.execute('SELECT uid FROM inventory_items WHERE uid = ?', (item['uid'],))
                                existing_item = cursor.fetchone()

                                if existing_item:
                                    # Update existing item
                                    cursor.execute('''
                                        UPDATE inventory_items
                                        SET name = ?, description = ?, price = ?, item_type = ?, updated_at = CURRENT_TIMESTAMP
                                        WHERE uid = ?
                                    ''', (
                                        item['name'],
                                        item.get('description', ''),
                                        item['price'],
                                        item['item_type'],
                                        item['uid']
                                    ))
                                    print(f"🔄 Updated existing item: {item['uid']}")
                                else:
                                    # Insert new item
                                    cursor.execute('''
                                        INSERT INTO inventory_items
                                        (uid, name, description, price, item_type, updated_at)
                                        VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                                    ''', (
                                        item['uid'],
                                        item['name'],
                                        item.get('description', ''),
                                        item['price'],
                                        item['item_type']
                                    ))
                                    print(f"➕ Added new item: {item['uid']}")

                                # Handle stock data with atomicity
                                cursor.execute('SELECT item_uid FROM inventory_stock WHERE item_uid = ?', (item['uid'],))
                                existing_stock = cursor.fetchone()

                                if existing_stock:
                                    # Update existing stock
                                    cursor.execute('''
                                        UPDATE inventory_stock
                                        SET current_stock = ?, last_stock_count = ?, re_stock_value = ?, re_stock_status = ?
                                        WHERE item_uid = ?
                                    ''', (
                                        item.get('current_stock_count', 0),
                                        item.get('last_stock_count', 0),
                                        item.get('re_stock_value', 0),
                                        item.get('re_stock_status', False),
                                        item['uid']
                                    ))
                                else:
                                    # Insert new stock record
                                    cursor.execute('''
                                        INSERT INTO inventory_stock
                                        (item_uid, current_stock, last_stock_count, re_stock_value, re_stock_status)
                                        VALUES (?, ?, ?, ?, ?)
                                    ''', (
                                        item['uid'],
                                        item.get('current_stock_count', 0),
                                        item.get('last_stock_count', 0),
                                        item.get('re_stock_value', 0),
                                        item.get('re_stock_status', False)
                                    ))

                            # Update sync status
                            cursor.execute('''
                                INSERT INTO sync_status (sync_type, records_synced, status)
                                VALUES ('inventory_page', ?, 'success')
                            ''', (len(items),))

                            conn.commit()

                        total_synced += len(items)
                        page += 1

                        # Stop if we've reached the last page
                        if page > total_pages:
                            break

                        # Small delay between requests
                        time.sleep(0.5)

                    except Exception as e:
                        print(f"❌ Error syncing page {page}: {e}")
                        break

                # Final sync status update
                with sqlite3.connect(db_path) as conn:
                    cursor = conn.cursor()
                    cursor.execute('''
                        INSERT INTO sync_status (sync_type, records_synced, status)
                        VALUES ('inventory_complete', ?, 'completed')
                    ''', (total_synced,))
                    conn.commit()

                print(f"✅ Inventory sync completed: {total_synced} items synchronized")

            except Exception as e:
                print(f"❌ Inventory sync failed: {e}")

        # Start background thread
        sync_thread = threading.Thread(target=sync_worker, daemon=True)
        sync_thread.start()

        print("🔄 Inventory synchronization started in background")
        print("📊 Check microserver_inventory.db for synchronized data")
        return True

    def payment_reconciliation_status(self):
        """Check payment reconciliation status with tabulated data from available sources"""
        print("🔍 Checking payment reconciliation status...")

        try:
            # Backend URL
            backend_url = "http://localhost:8080"

            # Since backend returns PDF for reconciliation, we'll gather reconciliation data
            # from multiple available sources and present it in tabulated format

            # Source 1: Get pending payments (unreconciled transactions)
            pending_payments = []
            try:
                pending_response = requests.get(
                    f"{backend_url}/api/sms/pending_payments",
                    timeout=REQUEST_TIMEOUT
                )

                if pending_response.status_code == 200:
                    pending_data = pending_response.json()
                    pending_payments = pending_data.get('payments', [])
            except Exception as e:
                print(f"⚠️ Could not fetch pending payments: {e}")

            # Source 2: Get SMS messages from microserver (processed transactions)
            processed_messages = []
            try:
                sms_response = self.session.get(f"{self.base_url}/sms/shortcodes", timeout=REQUEST_TIMEOUT)
                if sms_response.status_code == 200:
                    sms_data = sms_response.json()
                    processed_messages = sms_data.get('messages', [])
            except Exception as e:
                print(f"⚠️ Could not fetch SMS messages: {e}")

            # Source 3: Try to get sale records (if available)
            sale_records = []
            try:
                # Try the PDF endpoint but see if we can get any metadata
                pdf_response = requests.get(
                    f"{backend_url}/get_sale_record_printout?format=json",
                    timeout=REQUEST_TIMEOUT
                )
                if pdf_response.status_code == 200 and not pdf_response.text.startswith('%PDF'):
                    try:
                        pdf_data = pdf_response.json()
                        sale_records = pdf_data.get('records', [])
                    except:
                        pass
            except Exception as e:
                print(f"⚠️ Could not fetch sale records: {e}")

            # Now compile reconciliation data from all sources
            reconciliation_records = []

            # Add processed SMS messages as reconciled transactions
            for msg in processed_messages:
                # Extract payment info from SMS message
                message_text = msg.get('body', '')
                amount = 0
                reference = ''
                channel = ''

                # Try to extract amount
                import re
                amount_match = re.search(r'Kshs?\s*([\d,]+\.?\d*)', message_text, re.IGNORECASE)
                if amount_match:
                    amount_str = amount_match.group(1).replace(',', '')
                    try:
                        amount = float(amount_str)
                    except:
                        pass

                # Try to extract reference (multiple formats)
                reference = ''

                # Format 1: "Reference: ABC123"
                ref_match = re.search(r'Reference:\s*([A-Z0-9]+)', message_text, re.IGNORECASE)
                if ref_match:
                    reference = ref_match.group(1)
                else:
                    # Format 2: "ABC123~" (reference before tilde, possibly with other text before)
                    tilde_match = re.search(r'([A-Z0-9]+)~', message_text)
                    if tilde_match:
                        reference = tilde_match.group(1)

                # Try to extract channel/account (handle both "Account" and "merchant account")
                channel_match = re.search(r'(?:merchant\s+)?[Aa]ccount\s+(\d+)', message_text)
                if channel_match:
                    channel = channel_match.group(1)

                reconciliation_records.append({
                    'id': str(msg.get('id', 'SMS_' + str(len(reconciliation_records))))[:14],
                    'amount': amount,
                    'status': 'reconciled',
                    'method': 'SMS_Payment',
                    'reference': reference[:14] if reference else 'N/A',
                    'channel': channel,
                    'date': str(msg.get('timestamp', 'N/A'))[:11],
                    'validated': True,
                    'source': 'sms_processed'
                })

            # Add pending payments as unreconciled transactions
            for payment in pending_payments:
                reconciliation_records.append({
                    'id': str(payment.get('id', 'PENDING_' + str(len(reconciliation_records))))[:14],
                    'amount': payment.get('amount', 0),
                    'status': 'pending',
                    'method': payment.get('sender', 'Unknown')[:9],
                    'reference': str(payment.get('reference', 'N/A'))[:14],
                    'channel': str(payment.get('channel', 'N/A')),
                    'date': str(payment.get('created_at', 'N/A'))[:11],
                    'validated': False,
                    'source': 'backend_pending'
                })

            # Add sale records if available
            for sale in sale_records:
                if isinstance(sale, dict):
                    reconciliation_records.append({
                        'id': str(sale.get('id', 'SALE_' + str(len(reconciliation_records))))[:14],
                        'amount': sale.get('amount', sale.get('total', 0)),
                        'status': sale.get('status', 'completed'),
                        'method': sale.get('payment_method', 'Sale')[:9],
                        'reference': str(sale.get('reference', 'N/A'))[:14],
                        'channel': str(sale.get('channel', 'N/A')),
                        'date': str(sale.get('date', 'N/A'))[:11],
                        'validated': sale.get('validated', True),
                        'source': 'sale_record'
                    })

            if not reconciliation_records:
                print("ℹ️ No reconciliation data available from any source")
                print("💡 Sources checked:")
                print("   • Pending payments API")
                print("   • SMS processed messages")
                print("   • Sale records (if available)")
                return True

            print(f"📊 Payment Reconciliation Status (Aggregated Data):")
            print("=" * 130)
            print(f"{'Transaction ID':<15} {'Amount':<10} {'Status':<12} {'Method':<10} {'Reference':<15} {'Channel':<8} {'Date':<12} {'Validated':<10} {'Source':<10}")
            print("=" * 130)

            total_amount = 0
            status_counts = {}
            validated_count = 0
            source_counts = {}

            for record in reconciliation_records:
                transaction_id = record.get('id', 'N/A')[:14]
                amount = record.get('amount', 0)
                status = str(record.get('status', 'unknown'))[:11]
                method = str(record.get('method', 'N/A'))[:9]
                reference = str(record.get('reference', 'N/A'))[:14]
                channel = str(record.get('channel', 'N/A'))[:7]
                date = str(record.get('date', 'N/A'))[:11]
                validated = '✅' if record.get('validated', False) else '❌'
                source = str(record.get('source', 'unknown'))[:9]

                print(f"{transaction_id:<15} {amount:<10.2f} {status:<12} {method:<10} {reference:<15} {channel:<8} {date:<12} {validated:<10} {source:<10}")

                total_amount += amount if isinstance(amount, (int, float)) else 0

                # Count statuses
                status_counts[status] = status_counts.get(status, 0) + 1

                # Count sources
                source_counts[source] = source_counts.get(source, 0) + 1

                # Count validated payments
                if record.get('validated', False):
                    validated_count += 1

            print("=" * 130)
            print(f"📈 Summary:")
            print(f"   💰 Total Amount: KES {total_amount:.2f}")
            print(f"   ✅ Validated Payments: {validated_count}/{len(reconciliation_records)}")
            print(f"   📊 Status Breakdown:")
            for status, count in status_counts.items():
                print(f"      {status.title()}: {count}")

            print(f"   📊 Data Sources:")
            for source, count in source_counts.items():
                source_name = source.replace('_', ' ').title()
                print(f"      {source_name}: {count} records")

            # PDF Report Info
            print(f"   📄 PDF Report: Available at backend endpoint")
            print(f"      Size: ~44KB (detailed printable version)")

            return True

        except Exception as e:
            print(f"❌ Error checking payment reconciliation status: {e}")
            return False

    def pending_payments(self):
        """View pending payments stored in the backend database"""
        print("📋 Viewing pending payments in backend database...")

        try:
            # Backend URL (not microserver - backend runs on port 8080)
            backend_url = "http://localhost:8080"

            # Query backend for pending payments
            response = requests.get(
                f"{backend_url}/api/sms/pending_payments",
                timeout=REQUEST_TIMEOUT
            )

            if response.status_code != 200:
                print(f"❌ Failed to get pending payments: {response.status_code}")
                try:
                    error_data = response.json()
                    print(f"   Backend error: {error_data.get('message', 'Unknown error')}")
                except:
                    print(f"   Backend response: {response.text[:200]}...")
                return False

            try:
                data = response.json()
                payments = data.get('payments', [])

                if not payments:
                    print("ℹ️ No pending payments found in database")
                    return True

                print(f"📊 Found {len(payments)} pending payments:")
                print("-" * 100)
                print(f"{'ID':<5} {'Channel':<8} {'Amount':<10} {'Account':<10} {'Sender':<15} {'Reference':<12} {'Status':<10}")
                print("-" * 100)

                for payment in payments:
                    payment_id = payment.get('id', 'N/A')
                    channel = payment.get('channel', 'N/A')
                    amount = payment.get('amount', 0)
                    account = payment.get('account', 'N/A')
                    sender = payment.get('sender', 'N/A')[:14]  # Truncate long names
                    reference = payment.get('reference', 'N/A')[:11]  # Truncate long refs
                    status = payment.get('status', 'N/A')

                    print(f"{payment_id:<5} {channel:<8} {amount:<10.2f} {account:<10} {sender:<15} {reference:<12} {status:<10}")

                print("-" * 100)

                # Summary statistics
                total_amount = sum(p.get('amount', 0) for p in payments)
                status_counts = {}
                for p in payments:
                    status = p.get('status', 'unknown')
                    status_counts[status] = status_counts.get(status, 0) + 1

                print(f"📈 Summary:")
                print(f"   💰 Total Amount: KES {total_amount:.2f}")
                print(f"   📊 Status Breakdown:")
                for status, count in status_counts.items():
                    print(f"      {status.title()}: {count}")

                return True

            except json.JSONDecodeError:
                print("⚠️ Backend returned non-JSON response, checking raw data...")
                print(f"📄 Response: {response.text[:1000]}...")
                return False

        except Exception as e:
            print(f"❌ Error viewing pending payments: {e}")
            return False

    def list_inventory(self):
        """Interactive pagination for viewing local inventory database (direct SQLite query)"""
        print("📦 Interactive Inventory Browser")

        try:
            import os

            # Check if database exists
            db_path = "microserver_inventory.db"
            if not os.path.exists(db_path):
                print("❌ Inventory database not found")
                print("💡 Run option 10 (sync_inventory) first to create and populate the database")
                return False

            # Connect to database
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()

            try:
                # Verify tables exist
                cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='inventory_items'")
                if not cursor.fetchone():
                    print("❌ Inventory database exists but tables are missing")
                    print("💡 Run option 10 (sync_inventory) first to create and populate the database")
                    return False

                # Query microserver for paginated inventory
                page = 1
                page_size = 20

                while True:
                    # Calculate offset for pagination
                    offset = (page - 1) * page_size

                    # Get total count
                    cursor.execute("SELECT COUNT(*) FROM inventory_items")
                    total_items = cursor.fetchone()[0]
                    total_pages = (total_items + page_size - 1) // page_size  # Ceiling division

                    # Validate page number
                    if page > total_pages and total_items > 0:
                        print(f"❌ Page {page} exceeds total pages ({total_pages})")
                        page = total_pages
                        offset = (page - 1) * page_size
                    elif page < 1:
                        page = 1
                        offset = 0

                    # Query paginated inventory with JOIN
                    cursor.execute('''
                        SELECT
                            i.uid, i.name, i.description, i.price, i.item_type, i.updated_at,
                            s.current_stock, s.last_stock_count, s.re_stock_value, s.re_stock_status
                        FROM inventory_items i
                        LEFT JOIN inventory_stock s ON i.uid = s.item_uid
                        ORDER BY i.updated_at DESC
                        LIMIT ? OFFSET ?
                    ''', (page_size, offset))

                    items = cursor.fetchall()

                    if not items and page == 1:
                        print("ℹ️ No inventory items found in local database")
                        print("💡 Try running sync_inventory first to populate the database")
                        return True

                    # Clear screen and show header
                    print("\n" + "=" * 80)
                    print(f"📦 LOCAL INVENTORY DATABASE - Page {page}/{max(total_pages, 1)} (Total: {total_items} items)")
                    print("=" * 80)

                    # Table header
                    print(f"{'UID':<12} {'Name':<20} {'Type':<10} {'Price':<8} {'Stock':<6} {'Restock':<8} {'Status':<8}")
                    print("-" * 80)

                    # Display items
                    for item in items:
                        uid = str(item[0])[:11] if item[0] else 'N/A'
                        name = str(item[1])[:19] if item[1] else 'N/A'
                        item_type = str(item[4])[:9] if item[4] else 'N/A'
                        price = f"{item[3] or 0:.1f}"
                        stock = str(item[6] or 0)
                        restock = str(item[8] or 0)
                        status = "🟢 OK" if (item[6] or 0) > (item[8] or 0) else "🔴 LOW"

                        print(f"{uid:<12} {name:<20} {item_type:<10} {price:<8} {stock:<6} {restock:<8} {status:<8}")

                    print("-" * 80)

                    # Navigation prompt
                    if total_pages > 1:
                        print(f"\n📄 Page {page} of {total_pages}")
                        print("Navigation: [n]ext, [p]revious, [f]irst, [l]ast, [g]oto page, [q]uit")

                        while True:
                            nav_choice = input("Choose action: ").strip().lower()

                            if nav_choice in ['n', 'next']:
                                if page < total_pages:
                                    page += 1
                                    break
                                else:
                                    print("❌ Already on last page")
                            elif nav_choice in ['p', 'prev', 'previous']:
                                if page > 1:
                                    page -= 1
                                    break
                                else:
                                    print("❌ Already on first page")
                            elif nav_choice in ['f', 'first']:
                                page = 1
                                break
                            elif nav_choice in ['l', 'last']:
                                page = total_pages
                                break
                            elif nav_choice in ['g', 'goto']:
                                try:
                                    goto_page = int(input(f"Enter page number (1-{total_pages}): "))
                                    if 1 <= goto_page <= total_pages:
                                        page = goto_page
                                        break
                                    else:
                                        print(f"❌ Invalid page number. Must be between 1 and {total_pages}")
                                except ValueError:
                                    print("❌ Invalid input. Please enter a number")
                            elif nav_choice in ['q', 'quit', 'exit']:
                                print("\n👋 Exiting inventory browser")
                                return True
                            else:
                                print("❌ Invalid choice. Use: n, p, f, l, g, q")
                    else:
                        # Only one page, ask to continue or quit
                        choice = input("\nPress Enter to continue or 'q' to quit: ").strip().lower()
                        if choice in ['q', 'quit', 'exit']:
                            print("\n👋 Exiting inventory browser")
                            return True
                        else:
                            # Stay on same page (only one page exists)
                            pass

            finally:
                conn.close()

        except KeyboardInterrupt:
            print("\n\n⚠️ Inventory browsing interrupted by user")
            return True
        except Exception as e:
            print(f"❌ Error in inventory browser: {e}")
            return False

    def reset_inventory_db(self):
        """Reset/clear local microserver inventory database"""
        print("🗑️ Resetting local microserver inventory database...")

        try:
            db_path = "microserver_inventory.db"

            # Check if database exists
            import os
            if not os.path.exists(db_path):
                print("ℹ️ No inventory database found to reset")
                return True

            # Connect and drop all tables
            with sqlite3.connect(db_path) as conn:
                cursor = conn.cursor()

                # Drop tables if they exist
                cursor.execute("DROP TABLE IF EXISTS inventory_items")
                cursor.execute("DROP TABLE IF EXISTS inventory_stock")
                cursor.execute("DROP TABLE IF EXISTS sync_status")

                conn.commit()

            # Optionally delete the database file
            try:
                os.remove(db_path)
                print(f"🗑️ Deleted database file: {db_path}")
            except Exception as e:
                print(f"⚠️ Could not delete database file: {e}")
                print("📁 Database tables were dropped but file remains")

            print("✅ Local inventory database reset successfully")
            print("💡 Run sync_inventory to repopulate the database")
            return True

        except Exception as e:
            print(f"❌ Error resetting inventory database: {e}")
            return False

    def interactive_menu(self):
        """Run interactive menu for querying endpoints"""
        endpoints = {
            '1': ('health', 'Health check and server status'),
            '2': ('sms/shortcodes', 'SMS from approved shortcodes only'),
            '3': ('sms/not-shortcodes', 'SMS from regular phone numbers (scams)'),
            '4': ('sms/read', 'Read SMS only'),
            '5': ('sms/not-read', 'Unread SMS only'),
            '6': ('activate?action=check_expiry', 'Check license status (POST)'),
            '7': ('message/<id>', 'Get specific SMS message by ID'),
            '8': ('test?action=get_status&device_id=device_123', 'Get device status (POST)'),
            '9': ('export_valid_payments', 'Export valid payments from shortcodes to backend'),
            '10': ('sync_inventory', 'Sync inventory data from backend to local SQLite'),
            '11': ('payment_reconciliation_status', 'Check payment reconciliation status'),
            '12': ('pending_payments', 'View pending payments stored in backend database'),
            '13': ('list_inventory', 'Interactive inventory browser (local database)'),
            '14': ('reset_inventory_db', 'Reset/clear local microserver inventory database'),
        }

        # Check server connectivity first
        print("\n🔍 Checking micro-server connectivity...")
        if not self.check_server_status():
            print("\n❌ Cannot connect to micro-server. Please ensure it's running:")
            print("   • Start the Flutter app (micro-server runs automatically)")
            print("   • Or run: python start_microserver.py")
            print("\n💡 The micro-server runs on port 8085")
            return

        print("\n✅ Micro-server is accessible. Starting interactive query mode...\n")

        while True:
            print("\n" + "=" * 70)
            print("🎯 BluPOS Micro-Server Interactive Query Tool")
            print("=" * 70)
            print(f"📡 Server: {self.base_url}")
            print("⏰ Time: " + datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
            print()

            print("📋 AVAILABLE ENDPOINTS:")
            for key, (endpoint, description) in endpoints.items():
                print(f"  {key:>2}. {endpoint:<35} - {description}")

            print()
            print("  0. Exit")
            print("  h. Show this help")
            print()

            choice = input("Select endpoint (0-14 or 'h' for help): ").strip().lower()

            if choice == '0' or choice == 'exit':
                print("\n👋 Goodbye!")
                break
            elif choice == 'h' or choice == 'help':
                continue
            elif choice in endpoints:
                endpoint, description = endpoints[choice]

                # Handle special function calls (options 9, 10, 11, 12, 13, 14)
                if choice in ['9', '10', '11', '12', '13', '14']:
                    print(f"\n🎯 Executing: {description}")

                    if choice == '9':
                        success = self.export_valid_payments()
                    elif choice == '10':
                        success = self.sync_inventory()
                    elif choice == '11':
                        success = self.payment_reconciliation_status()
                    elif choice == '12':
                        success = self.pending_payments()
                    elif choice == '13':
                        success = self.list_inventory()
                    elif choice == '14':
                        success = self.reset_inventory_db()

                    if success:
                        print("\n✅ Operation completed successfully")
                    else:
                        print("\n❌ Operation failed")

                else:
                    # Handle URL endpoint queries (options 1-8)
                    # Handle special case for message/<id>
                    if '<id>' in endpoint:
                        message_id = input("Enter message ID: ").strip()
                        if message_id:
                            endpoint = f"message/{message_id}"
                        else:
                            print("❌ Message ID is required")
                            continue

                    # Determine method
                    method = 'POST' if endpoint.startswith(('activate', 'test')) else 'GET'
                    data = None

                    if method == 'POST' and 'action=' in endpoint:
                        # Parse action and device_id from endpoint for POST requests
                        parts = endpoint.split('&')
                        action_part = parts[0]
                        if len(parts) > 1 and 'device_id=' in parts[1]:
                            device_id_part = parts[1]
                            device_id = device_id_part.split('=')[1]
                            data = {'action': action_part.split('=')[1], 'device_id': device_id}
                        else:
                            data = {'action': action_part.split('=')[1]}

                    print(f"\n🎯 Querying: {description}")
                    success = self.query_endpoint(endpoint, method=method, json=data if data else None)

                    if success:
                        print("\n✅ Query completed successfully")
                    else:
                        print("\n❌ Query failed")
                        print("💡 Make sure the micro-server is running:")
                        print("   • Start Flutter app, or")
                        print("   • Run: python start_microserver.py")

                input("\nPress Enter to continue...")
            else:
                print("❌ Invalid choice. Please select 0-14 or 'h'.")

def show_usage():
    """Show usage information"""
    print("""
╔══════════════════════════════════════════════════════════════╗
║          BluPOS Micro-Server Interactive Query Tool           ║
║                                                              ║
║  Query predefined micro-server endpoints at any given time   ║
╚══════════════════════════════════════════════════════════════╝

USAGE:
    python query_microserver.py          # Interactive mode
    python query_microserver.py [endpoint] # Direct query mode

AVAILABLE ENDPOINTS:
    health                      - Health check and server status
    sms/shortcodes             - SMS from approved shortcodes only
    sms/not-shortcodes         - SMS from regular phone numbers (scams)
    sms/read                   - Read SMS only
    sms/not-read               - Unread SMS only
    message/<id>               - Get specific SMS message by ID

ACTIVATION ENDPOINTS (POST):
    activate?action=check_expiry - Check license status

TEST ENDPOINTS (POST):
    test?action=get_status&device_id=<id> - Get device status

SPECIAL OPERATIONS (Interactive Menu Only):
    9. export_valid_payments    - Export valid payments from shortcodes to backend
    10. sync_inventory         - Sync inventory data from backend to local SQLite
    11. payment_reconciliation_status - Check payment reconciliation status

EXAMPLES:
    python query_microserver.py                # Interactive menu
    python query_microserver.py health
    python query_microserver.py sms/shortcodes
    python query_microserver.py sms/not-read
    python query_microserver.py message/1767812249000

REQUIREMENTS:
    • Micro-server must be running (start Flutter app or use start_microserver.py)
    • Backend must be running on port 8080 for operations 9-11
    • Default URL: http://localhost:8085

TROUBLESHOOTING:
    • If connection fails, ensure micro-server is running on port 8085
    • For operations 9-11, ensure backend is running on port 8080
    • Check that no firewall is blocking the connection
    • Verify the endpoint name is spelled correctly
""")

def main():
    """Main entry point"""
    if len(sys.argv) == 1:
        # Interactive mode
        querier = MicroServerQuerier()
        querier.interactive_menu()
    elif len(sys.argv) == 2:
        if sys.argv[1] in ['-h', '--help', 'help']:
            show_usage()
            return

        # Direct query mode
        endpoint = sys.argv[1]
        querier = MicroServerQuerier()

        print("BluPOS Micro-Server Endpoint Query Tool")
        print("=" * 50)

        # Check server connectivity first
        if not querier.check_server_status():
            print("\n❌ Cannot connect to micro-server. Please ensure it's running:")
            print("   • Start the Flutter app (micro-server runs automatically)")
            print("   • Or run: python start_microserver.py")
            print("\n💡 The micro-server runs on port 8085")
            sys.exit(1)

        # Determine method based on endpoint
        method = 'GET'
        data = None

        if endpoint.startswith(('activate', 'test')):
            method = 'POST'
            if 'action=' in endpoint:
                # Parse action and device_id from endpoint
                parts = endpoint.split('&')
                action_part = parts[0]
                if len(parts) > 1 and 'device_id=' in parts[1]:
                    device_id_part = parts[1]
                    device_id = device_id_part.split('=')[1]
                    data = {'action': action_part.split('=')[1], 'device_id': device_id}
                else:
                    data = {'action': action_part.split('=')[1]}

        success = querier.query_endpoint(endpoint, method=method, json=data if data else None)

        if success:
            print("\n✅ Query completed successfully")
        else:
            print("\n❌ Query failed")
            print("💡 Make sure the micro-server is running:")
            print("   • Start Flutter app, or")
            print("   • Run: python start_microserver.py")
    else:
        show_usage()

if __name__ == "__main__":
    main()
