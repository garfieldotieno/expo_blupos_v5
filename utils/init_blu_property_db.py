#!/usr/bin/env python3
"""
Script to initialize the Blu Property database tables
"""

from backend import app, db

def init_blu_property_tables():
    """Initialize the new Blu Property database tables"""
    with app.app_context():
        try:
            # Create all tables including the new ones
            db.create_all()
            print("✅ Database tables created successfully!")
            print("📋 New tables added:")
            print("   - Receipt")
            print("   - PaymentConfirmation")
            print("   - Otp")
        except Exception as e:
            print(f"❌ Error creating database tables: {e}")

if __name__ == "__main__":
    init_blu_property_tables()
