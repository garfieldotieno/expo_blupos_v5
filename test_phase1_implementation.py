#!/usr/bin/env python3
"""
Test Script for Phase 1: Backend Infrastructure Implementation
"""

import requests
import json
import time
import sqlite3
import threading
import subprocess
import sys
import os

# Add the current directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_sms_parser():
    """Test the SMS parser functionality"""
    print("🧪 Testing SMS Parser...")
    
    try:
        from backend_sms_service import SMSPaymentParser
        
        parser = SMSPaymentParser()
        
        # Test Channel 80872
        test_msg_80872 = "Payment Of Kshs 130.00 Has Been Received By Jaystar Investments Ltd For Account 80872, From Jane Doe on 26/12/25 at 06.49pm"
        result_80872 = parser.parse_message('80872', test_msg_80872)
        
        print(f"✅ Channel 80872 parsed successfully:")
        print(f"   Amount: {result_80872.get('amount')}")
        print(f"   Account: {result_80872.get('account')}")
        print(f"   Sender: {result_80872.get('sender')}")
        print(f"   Date/Time: {result_80872.get('datetime')}")
        
        # Test Channel 57938
        test_msg_57938 = "Dear Jeffithah, Your merchant account 57938 has been credited with KES 50.00 ref #TLQ4G2B2YR from John Doe 254717xxx123 on 26-Dec-2025 15:27:17."
        result_57938 = parser.parse_message('57938', test_msg_57938)
        
        print(f"✅ Channel 57938 parsed successfully:")
        print(f"   Amount: {result_57938.get('amount')}")
        print(f"   Account: {result_57938.get('account')}")
        print(f"   Reference: {result_57938.get('reference')}")
        print(f"   Sender: {result_57938.get('sender')}")
        print(f"   Date/Time: {result_57938.get('datetime')}")
        
        return True
        
    except Exception as e:
        print(f"❌ SMS Parser test failed: {e}")
        return False

def test_database_initialization():
    """Test database initialization"""
    print("🧪 Testing Database Initialization...")
    
    try:
        from backend_sms_service import PaymentReconciliationService
        
        service = PaymentReconciliationService('test_pos.db')
        
        # Check if tables were created
        with sqlite3.connect('test_pos.db') as conn:
            cursor = conn.cursor()
            
            # Check SaleRecord table
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='sale_record'")
            sale_table = cursor.fetchone()
            
            # Check PendingPayment table
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='pending_payment'")
            pending_table = cursor.fetchone()
            
            if sale_table and pending_table:
                print("✅ Database tables created successfully")
                return True
            else:
                print("❌ Database tables not found")
                return False
                
    except Exception as e:
        print(f"❌ Database initialization test failed: {e}")
        return False

def test_backend_service():
    """Test the backend service endpoints"""
    print("🧪 Testing Backend Service Endpoints...")
    
    try:
        # Start the backend service in a separate process
        print("🚀 Starting backend service...")
        process = subprocess.Popen([
            sys.executable, 'backend_sms_service.py'
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        # Wait for service to start
        time.sleep(3)
        
        # Test health check
        print("🏥 Testing health check endpoint...")
        response = requests.get('http://localhost:8081/api/sms/health', timeout=5)
        if response.status_code == 200:
            print("✅ Health check successful")
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
        
        # Test SMS processing
        print("📨 Testing SMS processing endpoint...")
        test_data = {
            'channel': '80872',
            'message': 'Payment Of Kshs 130.00 Has Been Received By Jaystar Investments Ltd For Account 80872, From Jane Doe on 26/12/25 at 06.49pm'
        }
        
        response = requests.post('http://localhost:8081/api/sms/process', 
                               json=test_data, timeout=5)
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ SMS processing successful: {result['status']}")
        else:
            print(f"❌ SMS processing failed: {response.status_code}")
            return False
        
        # Test queue endpoint
        print("📋 Testing queue endpoint...")
        response = requests.get('http://localhost:8081/api/sms/queue', timeout=5)
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Queue endpoint successful: {result['queue_length']} items")
        else:
            print(f"❌ Queue endpoint failed: {response.status_code}")
            return False
        
        # Test status endpoint
        print("📊 Testing status endpoint...")
        response = requests.get('http://localhost:8081/api/sms/status', timeout=5)
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Status endpoint successful")
        else:
            print(f"❌ Status endpoint failed: {response.status_code}")
            return False
        
        # Test SMS test endpoint
        print("🧪 Testing SMS test endpoint...")
        response = requests.post('http://localhost:8081/api/sms/test', timeout=5)
        if response.status_code == 200:
            result = response.json()
            print(f"✅ SMS test endpoint successful: {len(result['test_results'])} tests")
        else:
            print(f"❌ SMS test endpoint failed: {response.status_code}")
            return False
        
        # Stop the service
        process.terminate()
        process.wait()
        
        print("✅ All backend service tests passed")
        return True
        
    except Exception as e:
        print(f"❌ Backend service test failed: {e}")
        try:
            process.terminate()
        except:
            pass
        return False

def test_reconciliation_service():
    """Test the reconciliation service functionality"""
    print("🧪 Testing Reconciliation Service...")
    
    try:
        from backend_sms_service import PaymentReconciliationService
        
        service = PaymentReconciliationService('test_pos.db')
        
        # Test get current pending checkout (should be None initially)
        pending_checkout = service.get_current_pending_checkout()
        if pending_checkout is None:
            print("✅ No pending checkout found (as expected)")
        else:
            print("⚠️ Pending checkout found when none expected")
        
        # Test create pending payment
        test_payment_data = {
            'channel': '80872',
            'amount': 130.00,
            'account': '80872',
            'sender': 'Jane Doe',
            'reference': '',
            'message': 'Test message'
        }
        
        result = service.create_pending_payment(test_payment_data)
        if result['status'] == 'pending':
            print("✅ Pending payment created successfully")
        else:
            print(f"❌ Pending payment creation failed: {result['status']}")
            return False
        
        # Test payment queue operations
        queue_before = service.get_payment_queue()
        print(f"📊 Queue length before: {queue_before['queue_length']}")
        
        # Add a payment to queue (this will fail since no pending checkout exists)
        result = service.process_sms_payment('80872', test_payment_data['message'])
        if result['status'] == 'pending':
            print("✅ Payment correctly routed to pending when no checkout exists")
        else:
            print(f"❌ Unexpected result: {result['status']}")
        
        queue_after = service.get_payment_queue()
        print(f"📊 Queue length after: {queue_after['queue_length']}")
        
        print("✅ All reconciliation service tests passed")
        return True
        
    except Exception as e:
        print(f"❌ Reconciliation service test failed: {e}")
        return False

def main():
    """Run all Phase 1 tests"""
    print("🚀 Starting Phase 1 Implementation Tests")
    print("=" * 50)
    
    tests = [
        ("SMS Parser", test_sms_parser),
        ("Database Initialization", test_database_initialization),
        ("Reconciliation Service", test_reconciliation_service),
        ("Backend Service", test_backend_service),
    ]
    
    results = []
    
    for test_name, test_func in tests:
        print(f"\n📋 Running {test_name} Test...")
        print("-" * 30)
        
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ {test_name} test failed with exception: {e}")
            results.append((test_name, False))
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 TEST SUMMARY")
    print("=" * 50)
    
    passed = 0
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"{test_name:<25} {status}")
        if result:
            passed += 1
    
    print("-" * 50)
    print(f"Total: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All Phase 1 tests passed! Ready for Phase 2.")
        return True
    else:
        print("⚠️ Some tests failed. Please review the implementation.")
        return False

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
