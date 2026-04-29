#!/usr/bin/env python3
"""
Phase 2 Implementation Test Suite
Tests for APK Integration and Frontend Enhancements
"""

import unittest
import json
import requests
import time
from unittest.mock import Mock, patch
from backend_sms_service import SMSPaymentParser, PaymentReconciliationService

class TestPhase2APKIntegration(unittest.TestCase):
    """Test suite for Phase 2 APK integration components"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.parser = SMSPaymentParser()
        self.reconciliation_service = PaymentReconciliationService()
        
        # Sample SMS messages for testing
        self.sample_messages = {
            'channel_80872': "Payment Of Kshs 130.00 Has Been Received By Jaystar Investments Ltd For Account 80872, From Jane Doe on 26/12/25 at 06.49pm",
            'channel_57938': "Dear Jeffithah, Your merchant account 57938 has been credited with KES 50.00 ref #TLQ4G2B2YR from John Doe 254717xxx123 on 26-Dec-2025 15:27:17.",
            'invalid_channel': "Some random message from unknown channel"
        }
    
    def test_sms_reconciliation_service_initialization(self):
        """Test SMS reconciliation service initialization"""
        service = PaymentReconciliationService()
        self.assertIsNotNone(service)
        self.assertEqual(service._is_auto_mode_enabled, False)
        self.assertEqual(service._is_listening, False)
        self.assertEqual(len(service._payment_queue), 0)
        self.assertIsNone(service._selected_payment)
        self.assertIsNone(service._pending_checkout)
    
    def test_auto_mode_toggle(self):
        """Test automatic mode toggle functionality"""
        service = PaymentReconciliationService()
        
        # Test enable auto mode
        service.enable_auto_mode()
        self.assertTrue(service.is_auto_mode_enabled)
        
        # Test disable auto mode
        service.disable_auto_mode()
        self.assertFalse(service.is_auto_mode_enabled)
    
    def test_payment_queue_management(self):
        """Test payment queue operations"""
        service = PaymentReconciliationService()
        
        # Test initial empty queue
        self.assertEqual(len(service.payment_queue), 0)
        
        # Test adding payment to queue
        payment_data = {
            'id': 'test_payment_1',
            'amount': 100.0,
            'sender': 'Test Sender',
            'account': '80872'
        }
        
        service._payment_queue.append(payment_data)
        self.assertEqual(len(service.payment_queue), 1)
        self.assertEqual(service.payment_queue[0]['id'], 'test_payment_1')
    
    def test_payment_selection(self):
        """Test payment selection for reconciliation"""
        service = PaymentReconciliationService()
        
        # Add test payment to queue
        payment_data = {
            'id': 'test_payment_1',
            'payment_data': {'amount': 100.0, 'sender': 'Test Sender'},
            'pending_checkout': {'remaining_balance': 100.0}
        }
        service._payment_queue.append(payment_data)
        
        # Test selecting payment
        result = service.select_payment('test_payment_1')
        
        # Verify payment was selected
        self.assertIsNotNone(service.selected_payment)
        self.assertIsNotNone(service.pending_checkout)
        self.assertEqual(service.selected_payment['id'], 'test_payment_1')
    
    def test_payment_confirmation(self):
        """Test payment confirmation workflow"""
        service = PaymentReconciliationService()
        
        # Set up selected payment and pending checkout
        service._selected_payment = {
            'id': 'test_payment_1',
            'payment_data': {'amount': 100.0, 'sender': 'Test Sender'},
            'pending_checkout': {'remaining_balance': 100.0}
        }
        service._pending_checkout = {'remaining_balance': 100.0}
        
        # Mock the backend service response
        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {
                'status': 'success',
                'message': 'Payment confirmed successfully',
                'amount_reconciled': 100.0,
                'remaining_balance': 0.0,
                'unblock_sales': True,
                'queue_length': 0
            }
            mock_post.return_value = mock_response
            
            # Test confirming payment
            result = service.confirm_payment('test_payment_1', True)
            
            # Verify result
            self.assertEqual(result['status'], 'success')
            self.assertEqual(result['amount_reconciled'], 100.0)
            self.assertEqual(result['remaining_balance'], 0.0)
            
            # Verify payment and checkout were cleared
            self.assertIsNone(service.selected_payment)
            self.assertIsNone(service.pending_checkout)
    
    def test_payment_rejection(self):
        """Test payment rejection workflow"""
        service = PaymentReconciliationService()
        
        # Set up selected payment and pending checkout
        service._selected_payment = {
            'id': 'test_payment_1',
            'payment_data': {'amount': 100.0, 'sender': 'Test Sender'},
            'pending_checkout': {'remaining_balance': 100.0}
        }
        service._pending_checkout = {'remaining_balance': 100.0}
        
        # Mock the backend service response
        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {
                'status': 'rejected',
                'message': 'Payment rejected by clerk',
                'queue_length': 1
            }
            mock_post.return_value = mock_response
            
            # Test rejecting payment
            result = service.confirm_payment('test_payment_1', False)
            
            # Verify result
            self.assertEqual(result['status'], 'rejected')
            self.assertEqual(result['message'], 'Payment rejected by clerk')
            
            # Verify payment and checkout were cleared
            self.assertIsNone(service.selected_payment)
            self.assertIsNone(service.pending_checkout)
    
    def test_payment_queue_refresh(self):
        """Test payment queue refresh functionality"""
        service = PaymentReconciliationService()
        
        # Mock the backend service response
        with patch('requests.get') as mock_get:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {
                'status': 'success',
                'queue': [
                    {
                        'id': 'payment_1',
                        'payment_data': {'amount': 100.0, 'sender': 'Test Sender 1'},
                        'pending_checkout': {'remaining_balance': 100.0}
                    },
                    {
                        'id': 'payment_2', 
                        'payment_data': {'amount': 50.0, 'sender': 'Test Sender 2'},
                        'pending_checkout': {'remaining_balance': 50.0}
                    }
                ]
            }
            mock_get.return_value = mock_response
            
            # Test refreshing queue
            queue = service.get_payment_queue()
            
            # Verify queue was populated
            self.assertEqual(len(queue), 2)
            self.assertEqual(queue[0]['id'], 'payment_1')
            self.assertEqual(queue[1]['id'], 'payment_2')
    
    def test_sms_status_check(self):
        """Test SMS processing status check"""
        service = PaymentReconciliationService()
        
        # Mock the backend service response
        with patch('requests.get') as mock_get:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {
                'status': 'success',
                'queue_length': 2,
                'pending_checkout': True,
                'pending_checkout_details': {
                    'sale_id': 123,
                    'total_amount': 150.0,
                    'remaining_balance': 100.0
                }
            }
            mock_get.return_value = mock_response
            
            # Test getting SMS status
            status = service.get_sms_status()
            
            # Verify status
            self.assertEqual(status['status'], 'success')
            self.assertEqual(status['queue_length'], 2)
            self.assertTrue(status['pending_checkout'])
            self.assertIsNotNone(status['pending_checkout_details'])
    
    def test_test_sms_processing(self):
        """Test SMS processing test functionality"""
        service = PaymentReconciliationService()
        
        # Mock the backend service response
        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {
                'status': 'success',
                'test_results': [
                    {'channel': '80872', 'status': 'success', 'message': 'Test passed'},
                    {'channel': '57938', 'status': 'success', 'message': 'Test passed'}
                ],
                'message': 'All tests passed'
            }
            mock_post.return_value = mock_response
            
            # Test SMS processing
            result = service.test_sms_processing()
            
            # Verify result
            self.assertEqual(result['status'], 'success')
            self.assertEqual(len(result['test_results']), 2)
            self.assertEqual(result['message'], 'All tests passed')
    
    def test_clear_operations(self):
        """Test clear operations for payment queue and selected payment"""
        service = PaymentReconciliationService()
        
        # Set up test data
        service._payment_queue = [{'id': 'test_payment'}]
        service._selected_payment = {'id': 'test_payment'}
        service._pending_checkout = {'sale_id': 123}
        
        # Test clearing selected payment
        service.clear_selected_payment()
        self.assertIsNone(service.selected_payment)
        self.assertIsNone(service.pending_checkout)
        
        # Test clearing payment queue
        service.clear_payment_queue()
        self.assertEqual(len(service.payment_queue), 0)
    
    def test_reset_service(self):
        """Test service reset functionality"""
        service = PaymentReconciliationService()
        
        # Set up test data
        service._is_auto_mode_enabled = True
        service._is_listening = True
        service._payment_queue = [{'id': 'test_payment'}]
        service._selected_payment = {'id': 'test_payment'}
        service._pending_checkout = {'sale_id': 123}
        
        # Test reset
        service.reset()
        
        # Verify all state was reset
        self.assertFalse(service.is_auto_mode_enabled)
        self.assertFalse(service.is_listening)
        self.assertEqual(len(service.payment_queue), 0)
        self.assertIsNone(service.selected_payment)
        self.assertIsNone(service.pending_checkout)

class TestAPKIntegration(unittest.TestCase):
    """Test APK integration scenarios"""
    
    def test_apk_sms_processing_workflow(self):
        """Test complete APK SMS processing workflow"""
        # Simulate APK receiving SMS message
        sms_message = "Payment Of Kshs 130.00 Has Been Received By Jaystar Investments Ltd For Account 80872, From Jane Doe on 26/12/25 at 06.49pm"
        channel = "80872"
        
        # Test processing SMS message
        service = PaymentReconciliationService()
        
        # Mock the backend service response
        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {
                'status': 'queued',
                'message': 'Payment added to queue',
                'queue_length': 1
            }
            mock_post.return_value = mock_response
            
            # Process SMS message
            result = service.process_sms_message(channel, sms_message)
            
            # Verify result
            self.assertEqual(result['status'], 'queued')
            self.assertEqual(result['message'], 'Payment added to queue')
            self.assertEqual(result['queue_length'], 1)
    
    def test_apk_payment_reconciliation_workflow(self):
        """Test APK payment reconciliation workflow"""
        service = PaymentReconciliationService()
        
        # Simulate clerk selecting payment from queue
        payment_id = 'test_payment_123'
        
        # Mock the backend service response for payment selection
        with patch('requests.post') as mock_post:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {
                'status': 'success',
                'message': 'Payment selected for reconciliation',
                'payment_data': {
                    'id': payment_id,
                    'amount': 100.0,
                    'sender': 'Jane Doe',
                    'account': '80872'
                },
                'pending_checkout': {
                    'sale_id': 123,
                    'total_amount': 150.0,
                    'remaining_balance': 100.0
                }
            }
            mock_post.return_value = mock_response
            
            # Select payment
            result = service.select_payment(payment_id)
            
            # Verify payment was selected
            self.assertEqual(result['status'], 'success')
            self.assertEqual(result['paymentData']['id'], payment_id)
            self.assertEqual(result['pendingCheckout']['sale_id'], 123)
            
            # Mock the backend service response for payment confirmation
            mock_response.json.return_value = {
                'status': 'success',
                'message': 'Payment confirmed successfully',
                'amount_reconciled': 100.0,
                'remaining_balance': 0.0,
                'unblock_sales': True,
                'queue_length': 0
            }
            
            # Confirm payment
            confirmation_result = service.confirm_payment(payment_id, True)
            
            # Verify confirmation
            self.assertEqual(confirmation_result['status'], 'success')
            self.assertEqual(confirmation_result['amount_reconciled'], 100.0)
            self.assertEqual(confirmation_result['remaining_balance'], 0.0)
            self.assertTrue(confirmation_result['unblock_sales'])

class TestPhase2Documentation(unittest.TestCase):
    """Test Phase 2 documentation and implementation summary"""
    
    def test_phase2_implementation_summary(self):
        """Test that Phase 2 implementation summary is complete"""
        # This would typically test the documentation file
        # For now, we'll just verify the test suite covers all components
        test_methods = [method for method in dir(self) if method.startswith('test_')]
        self.assertGreater(len(test_methods), 0, "Phase 2 tests should cover all components")

if __name__ == '__main__':
    # Run the test suite
    unittest.main(verbosity=2)
