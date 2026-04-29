#!/usr/bin/env python3
"""
SMS Payment Verification and Synchronization Service
Phase 1: Backend Infrastructure Implementation
"""

import re
import json
import logging
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3
import threading
import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SMSPaymentParser:
    """Parse SMS messages and extract payment information"""
    
    def __init__(self):
        self.channel_patterns = {
            '80872': {
                'amount_pattern': r'Kshs\s*(\d+\.?\d*)',
                'account_pattern': r'Account\s*(\d+)',
                'sender_pattern': r'From\s*([A-Za-z\s]+)\s+on',
                'date_pattern': r'on\s*(\d{2}/\d{2}/\d{2})',
                'time_pattern': r'at\s*(\d{2}\.\d{2}(?:am|pm))'
            },
            '57938': {
                'amount_pattern': r'KES\s*(\d+\.?\d*)',
                'account_pattern': r'account\s*(\d+)',
                'ref_pattern': r'ref\s*#(\w+)',
                'sender_pattern': r'from\s*([A-Za-z\s]+)\s+\d{10}',
                'phone_pattern': r'(\d{10})',
                'datetime_pattern': r'on\s*(\d{2}-[A-Za-z]{3}-\d{4}\s+\d{2}:\d{2}:\d{2})'
            }
        }
    
    def parse_message(self, channel: str, message: str) -> Dict:
        """Parse SMS message and return payment data"""
        if channel not in self.channel_patterns:
            raise ValueError(f"Unknown channel: {channel}")
        
        pattern = self.channel_patterns[channel]
        result = {'channel': channel, 'message': message}
        
        # Extract amount
        amount_match = re.search(pattern['amount_pattern'], message)
        if amount_match:
            result['amount'] = float(amount_match.group(1))
        
        # Extract account
        account_match = re.search(pattern['account_pattern'], message)
        if account_match:
            result['account'] = account_match.group(1)
        
        # Extract sender
        sender_match = re.search(pattern['sender_pattern'], message)
        if sender_match:
            result['sender'] = sender_match.group(1).strip()
        
        # Extract reference (if available)
        if 'ref_pattern' in pattern:
            ref_match = re.search(pattern['ref_pattern'], message)
            if ref_match:
                result['reference'] = ref_match.group(1)
        
        # Extract date/time
        if 'datetime_pattern' in pattern:
            datetime_match = re.search(pattern['datetime_pattern'], message)
            if datetime_match:
                result['datetime'] = datetime_match.group(1)
        else:
            # Handle separate date and time patterns
            date_match = re.search(pattern['date_pattern'], message)
            time_match = re.search(pattern['time_pattern'], message)
            if date_match and time_match:
                result['datetime'] = f"{date_match.group(1)} {time_match.group(1)}"
        
        return result

class PaymentReconciliationService:
    """Handle SMS payment reconciliation with blocking checkout structure and payment queue"""
    
    def __init__(self, db_path: str = None):
        self.parser = SMSPaymentParser()
        self.payment_queue = []  # In-memory queue for pending payments

        # Use instance database path to match Flask SQLAlchemy configuration
        if db_path is None:
            import os
            instance_path = os.path.join(os.getcwd(), 'instance', 'pos_test.db')
            # Ensure instance directory exists
            os.makedirs(os.path.dirname(instance_path), exist_ok=True)
            self.db_path = instance_path
        else:
            self.db_path = db_path

        self._init_database()
    
    def _init_database(self):
        """Initialize database tables"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Create SaleRecord table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS sale_record (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        uid TEXT UNIQUE NOT NULL,
                        sale_clerk TEXT NOT NULL,
                        sale_total REAL NOT NULL,
                        sale_paid_amount REAL NOT NULL,
                        sale_balance REAL NOT NULL,
                        payment_method TEXT,
                        payment_reference TEXT,
                        payment_gateway TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        checkout_id TEXT UNIQUE,
                        checkout_status TEXT DEFAULT 'PENDING_PAYMENT'
                    )
                ''')
                
                # Create PendingPayment table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS pending_payment (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        channel TEXT NOT NULL,
                        amount REAL NOT NULL,
                        account TEXT NOT NULL,
                        sender TEXT,
                        reference TEXT,
                        message TEXT NOT NULL,
                        received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        status TEXT DEFAULT 'pending',
                        matched_sale_id INTEGER,
                        notes TEXT,
                        FOREIGN KEY (matched_sale_id) REFERENCES sale_record (id)
                    )
                ''')
                
                conn.commit()
                logger.info("Database tables initialized successfully")
        except Exception as e:
            logger.error(f"Database initialization failed: {e}")
            raise
    
    def process_sms_payment(self, channel: str, message: str) -> Dict:
        """Process incoming SMS with payment queue logic"""
        try:
            # Parse SMS message
            payment_data = self.parser.parse_message(channel, message)
            
            # Get current pending checkout (only one allowed at a time)
            pending_checkout = self.get_current_pending_checkout()
            
            if pending_checkout:
                # Add payment to queue for clerk selection
                payment_entry = {
                    'id': f"payment_{datetime.now().timestamp()}",
                    'payment_data': payment_data,
                    'pending_checkout': {
                        'id': pending_checkout['id'],
                        'uid': pending_checkout['uid'],
                        'remaining_balance': pending_checkout['sale_balance'],
                        'payment_amount': payment_data.get('amount', 0),
                        'balance_after_payment': pending_checkout['sale_balance'] - payment_data.get('amount', 0)
                    },
                    'received_at': datetime.now(),
                    'status': 'queued'
                }
                
                self.payment_queue.append(payment_entry)
                
                return {
                    'status': 'queued',
                    'action': 'payment_queued',
                    'payment_id': payment_entry['id'],
                    'queue_length': len(self.payment_queue),
                    'message': f'Payment queued. {len(self.payment_queue)} payment(s) waiting for selection.'
                }
            else:
                # No pending checkout - create pending payment for manual review
                return self.create_pending_payment(payment_data)
                
        except Exception as e:
            logger.error(f"Error processing SMS payment: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def get_payment_queue(self) -> Dict:
        """Get current payment queue for clerk selection"""
        return {
            'status': 'success',
            'queue': self.payment_queue,
            'queue_length': len(self.payment_queue)
        }
    
    def select_payment_for_reconciliation(self, payment_id: str) -> Dict:
        """Select payment from queue for reconciliation"""
        try:
            # Find payment in queue
            selected_payment = None
            for payment in self.payment_queue:
                if payment['id'] == payment_id:
                    selected_payment = payment
                    break
            
            if not selected_payment:
                return {
                    'status': 'error',
                    'message': 'Payment not found in queue'
                }
            
            # Get pending checkout
            pending_checkout = self.get_current_pending_checkout()
            if not pending_checkout:
                return {
                    'status': 'error',
                    'message': 'No pending checkout found'
                }
            
            return {
                'status': 'success',
                'action': 'show_payment_details',
                'payment_data': selected_payment['payment_data'],
                'pending_checkout': selected_payment['pending_checkout'],
                'message': 'Payment selected for reconciliation'
            }
            
        except Exception as e:
            logger.error(f"Error selecting payment: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def confirm_payment_match(self, payment_id: str, clerk_confirmation: bool) -> Dict:
        """Process clerk confirmation and update sale record"""
        try:
            if not clerk_confirmation:
                # Remove payment from queue
                self.payment_queue = [p for p in self.payment_queue if p['id'] != payment_id]
                return {
                    'status': 'rejected',
                    'action': 'payment_rejected',
                    'queue_length': len(self.payment_queue),
                    'message': 'Payment rejected and removed from queue'
                }
            
            # Find payment in queue
            selected_payment = None
            for payment in self.payment_queue:
                if payment['id'] == payment_id:
                    selected_payment = payment
                    break
            
            if not selected_payment:
                return {
                    'status': 'error',
                    'message': 'Payment not found in queue'
                }
            
            # Get pending checkout
            pending_checkout = self.get_current_pending_checkout()
            if not pending_checkout:
                return {
                    'status': 'error',
                    'message': 'No pending checkout found'
                }
            
            payment_amount = selected_payment['payment_data'].get('amount', 0)
            remaining_balance = pending_checkout['sale_balance']
            
            # Update sale record in database
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Update payment method and reference
                # Use the same payment_reference field that manual MPESA payments use
                payment_reference = selected_payment['payment_data'].get('reference', '')
                payment_account = selected_payment['payment_data'].get('account', '')
                
                cursor.execute('''
                    UPDATE sale_record 
                    SET payment_method = ?, payment_reference = ?, payment_gateway = ?, 
                        sale_paid_amount = ?, sale_balance = ?, updated_at = ?
                    WHERE id = ?
                ''', (
                    'MPESA',
                    payment_reference,  # Same field used for manual MPESA payments
                    payment_account,    # Store account number in payment_gateway
                    pending_checkout['sale_paid_amount'] + payment_amount,
                    max(0, remaining_balance - payment_amount),
                    datetime.now(),
                    pending_checkout['id']
                ))
                
                # Remove payment from queue
                self.payment_queue = [p for p in self.payment_queue if p['id'] != payment_id]
                
                # Determine if sale is completed
                new_balance = max(0, remaining_balance - payment_amount)
                if new_balance <= 0:
                    checkout_status = 'COMPLETED'
                    unblock_sales = True
                else:
                    checkout_status = 'PENDING_PAYMENT'
                    unblock_sales = False
                
                # Update checkout status
                cursor.execute('''
                    UPDATE sale_record 
                    SET checkout_status = ?
                    WHERE id = ?
                ''', (checkout_status, pending_checkout['id']))
                
                conn.commit()
            
            return {
                'status': 'success',
                'action': 'payment_confirmed',
                'sale_id': pending_checkout['id'],
                'sale_uid': pending_checkout['uid'],
                'amount_reconciled': payment_amount,
                'remaining_balance': new_balance,
                'unblock_sales': unblock_sales,
                'queue_length': len(self.payment_queue),
                'message': f'Payment confirmed. Remaining balance: KES {new_balance}'
            }
            
        except Exception as e:
            logger.error(f"Error confirming payment match: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def get_current_pending_checkout(self) -> Optional[Dict]:
        """Get the current pending checkout (only one allowed at a time)"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    SELECT id, uid, sale_clerk, sale_total, sale_paid_amount, sale_balance,
                           payment_method, payment_reference, payment_gateway, created_at, updated_at,
                           checkout_id, checkout_status
                    FROM sale_record 
                    WHERE sale_balance > 0 
                      AND (payment_method IS NULL OR payment_method = '')
                      AND (payment_reference IS NULL OR payment_reference = '')
                    ORDER BY created_at DESC 
                    LIMIT 1
                ''')
                
                result = cursor.fetchone()
                if result:
                    columns = [desc[0] for desc in cursor.description]
                    return dict(zip(columns, result))
                return None
                
        except Exception as e:
            logger.error(f"Error getting pending checkout: {e}")
            return None
    
    def create_pending_payment(self, payment_data: Dict) -> Dict:
        """Create pending payment record for unmatched SMS"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT INTO pending_payment 
                    (channel, amount, account, sender, reference, message, status)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    payment_data['channel'],
                    payment_data.get('amount', 0),
                    payment_data.get('account', ''),
                    payment_data.get('sender', ''),
                    payment_data.get('reference', ''),
                    payment_data['message'],
                    'pending'
                ))
                
                conn.commit()
                
                return {
                    'status': 'pending',
                    'action': 'created_pending',
                    'pending_id': cursor.lastrowid,
                    'message': 'No pending checkout found, created pending payment for review'
                }
                
        except Exception as e:
            logger.error(f"Error creating pending payment: {e}")
            return {'status': 'error', 'message': str(e)}

# Flask Application Setup
app = Flask(__name__)
CORS(app, origins="*")

# Initialize services
reconciliation_service = PaymentReconciliationService()

# API Endpoints

@app.route('/api/sms/process', methods=['POST'])
def process_incoming_sms():
    """Process incoming SMS payment notification"""
    try:
        data = request.get_json()
        channel = data.get('channel')
        message = data.get('message')
        
        if not channel or not message:
            return jsonify({'status': 'error', 'message': 'Missing channel or message'}), 400
        
        result = reconciliation_service.process_sms_payment(channel, message)
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error in /api/sms/process: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/sms/reconcile', methods=['POST'])
def reconcile_sms_payment():
    """Reconcile SMS payment with existing sales record"""
    try:
        data = request.get_json()
        payment_id = data.get('payment_id')
        clerk_confirmation = data.get('clerk_confirmation', False)
        
        if not payment_id:
            return jsonify({'status': 'error', 'message': 'Missing payment_id'}), 400
        
        result = reconciliation_service.confirm_payment_match(payment_id, clerk_confirmation)
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error in /api/sms/reconcile: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/sms/status', methods=['GET'])
def get_sms_status():
    """Get SMS processing status and statistics"""
    try:
        queue_data = reconciliation_service.get_payment_queue()
        pending_checkout = reconciliation_service.get_current_pending_checkout()
        
        return jsonify({
            'status': 'success',
            'queue_length': queue_data['queue_length'],
            'pending_checkout': pending_checkout is not None,
            'pending_checkout_details': pending_checkout,
            'message': 'SMS processing status retrieved successfully'
        })
        
    except Exception as e:
        logger.error(f"Error in /api/sms/status: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/sms/select-payment', methods=['POST'])
def select_payment():
    """Select payment from queue for reconciliation"""
    try:
        data = request.get_json()
        payment_id = data.get('payment_id')
        
        if not payment_id:
            return jsonify({'status': 'error', 'message': 'Missing payment_id'}), 400
        
        result = reconciliation_service.select_payment_for_reconciliation(payment_id)
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error in /api/sms/select-payment: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/sms/queue', methods=['GET'])
def get_payment_queue():
    """Get current payment queue"""
    try:
        result = reconciliation_service.get_payment_queue()
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error in /api/sms/queue: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/sms/test', methods=['POST'])
def test_sms_processing():
    """Test endpoint for SMS processing"""
    try:
        # Test SMS messages
        test_messages = [
            {
                'channel': '80872',
                'message': 'Payment Of Kshs 130.00 Has Been Received By Jaystar Investments Ltd For Account 80872, From Jane Doe on 26/12/25 at 06.49pm'
            },
            {
                'channel': '57938',
                'message': 'Dear Jeffithah, Your merchant account 57938 has been credited with KES 50.00 ref #TLQ4G2B2YR from John Doe 254717xxx123 on 26-Dec-2025 15:27:17.'
            }
        ]
        
        results = []
        for test_msg in test_messages:
            result = reconciliation_service.process_sms_payment(test_msg['channel'], test_msg['message'])
            results.append({
                'channel': test_msg['channel'],
                'status': result['status'],
                'message': result['message']
            })
        
        return jsonify({
            'status': 'success',
            'test_results': results,
            'message': 'SMS processing test completed'
        })
        
    except Exception as e:
        logger.error(f"Error in /api/sms/test: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/sms/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        response_data = {
            'status': 'healthy',
            'service': 'SMS Payment Verification Service',
            'timestamp': datetime.now().isoformat(),
            'queue_length': len(reconciliation_service.payment_queue)
        }
        return jsonify(response_data)
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    logger.info("Starting SMS Payment Verification Service...")
    logger.info("Phase 1: Backend Infrastructure Implementation")
    
    # Start the Flask server
    app.run(host='0.0.0.0', port=8081, debug=True)
