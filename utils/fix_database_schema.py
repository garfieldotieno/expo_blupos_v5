#!/usr/bin/env python3
"""
Database Schema Fix Script for Expo BLUPOS v5
This script adds missing columns to the restored database.
"""

import sys
import os
import sqlite3

# Add the current directory to the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def fix_sale_item_transaction_table():
    """Add missing sale_id column to sale_item_transaction table"""
    db_path = 'instance/pos_test.db'

    if not os.path.exists(db_path):
        print(f"❌ Database file not found: {db_path}")
        return False

    try:
        # Connect to the database
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check if sale_id column already exists
        cursor.execute("PRAGMA table_info(sale_item_transaction)")
        columns = cursor.fetchall()
        column_names = [col[1] for col in columns]

        if 'sale_id' in column_names:
            print("✅ sale_id column already exists in sale_item_transaction table")
            conn.close()
            return True

        print("🔧 Adding sale_id column to sale_item_transaction table...")

        # Add the sale_id column
        # Since it's a foreign key and nullable, we can add it without issues
        cursor.execute("""
            ALTER TABLE sale_item_transaction
            ADD COLUMN sale_id INTEGER REFERENCES sale_record(id)
        """)

        # Commit the changes
        conn.commit()
        conn.close()

        print("✅ Successfully added sale_id column to sale_item_transaction table")
        return True

    except Exception as e:
        print(f"❌ Error fixing database schema: {e}")
        if 'conn' in locals():
            conn.close()
        return False

def verify_database_schema():
    """Verify that the database schema is correct"""
    db_path = 'instance/pos_test.db'

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check sale_item_transaction table
        cursor.execute("PRAGMA table_info(sale_item_transaction)")
        columns = cursor.fetchall()

        print("📋 sale_item_transaction table schema:")
        for col in columns:
            print(f"  - {col[1]} ({col[2]}) {'PRIMARY KEY' if col[5] else ''}")

        # Check if sale_id column exists
        column_names = [col[1] for col in columns]
        if 'sale_id' in column_names:
            print("✅ sale_id column found")
        else:
            print("❌ sale_id column missing")

        # Check sale_record table
        cursor.execute("PRAGMA table_info(sale_record)")
        sale_record_columns = cursor.fetchall()
        print("
📋 sale_record table schema:"        for col in sale_record_columns:
            print(f"  - {col[1]} ({col[2]}) {'PRIMARY KEY' if col[5] else ''}")

        conn.close()
        return True

    except Exception as e:
        print(f"❌ Error verifying database schema: {e}")
        return False

def main():
    print("🔧 Expo BLUPOS v5 Database Schema Fix")
    print("=" * 50)

    # Verify current schema
    print("\n📊 Current Database Schema:")
    verify_database_schema()

    # Fix the schema
    print("\n🔨 Applying Schema Fixes:")
    success = fix_sale_item_transaction_table()

    if success:
        print("\n📊 Updated Database Schema:")
        verify_database_schema()
        print("\n✅ Database schema fix completed successfully!")
        print("🎉 The /inventory route should now work properly.")
    else:
        print("\n❌ Database schema fix failed!")

if __name__ == "__main__":
    main()
