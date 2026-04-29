#!/usr/bin/env python3
"""
Migrate pending_payment data from root pos_test.db to instance/pos_test.db
This script resolves the database inconsistency issue.
"""

import sqlite3
import os
import shutil
from datetime import datetime

def migrate_pending_payments():
    """Migrate pending_payment table and data from root to instance database"""

    # Define paths
    root_db = 'pos_test.db'
    instance_db = 'instance/pos_test.db'

    # Ensure instance directory exists
    os.makedirs('instance', exist_ok=True)

    print("🔄 Starting pending_payment data migration...")
    print(f"📁 Source: {root_db}")
    print(f"📁 Target: {instance_db}")

    # Check if root database exists and has pending_payment table
    if not os.path.exists(root_db):
        print(f"❌ Root database {root_db} does not exist")
        return False

    # Check if root database has pending_payment table
    try:
        root_conn = sqlite3.connect(root_db)
        root_cursor = root_conn.cursor()

        # Check if pending_payment table exists in root
        root_cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='pending_payment'")
        if not root_cursor.fetchone():
            print("ℹ️ No pending_payment table found in root database")
            root_conn.close()
            return True

        # Get data from root database
        root_cursor.execute("SELECT COUNT(*) FROM pending_payment")
        count = root_cursor.fetchone()[0]
        print(f"📊 Found {count} records in root pending_payment table")

        if count == 0:
            print("ℹ️ No data to migrate")
            root_conn.close()
            return True

        # Get all pending payment data
        root_cursor.execute("""
            SELECT id, channel, amount, account, sender, reference, message, received_at, status, matched_sale_id, notes
            FROM pending_payment
            ORDER BY id
        """)
        pending_payments = root_cursor.fetchall()

        root_conn.close()

    except Exception as e:
        print(f"❌ Error reading from root database: {e}")
        return False

    # Now migrate to instance database
    try:
        # Connect to instance database (creates if doesn't exist)
        instance_conn = sqlite3.connect(instance_db)
        instance_cursor = instance_conn.cursor()

        # Create pending_payment table in instance database (if it doesn't exist)
        instance_cursor.execute('''
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

        # Clear any existing data in instance (to avoid duplicates)
        instance_cursor.execute("DELETE FROM pending_payment")

        # Insert migrated data
        migrated_count = 0
        for payment in pending_payments:
            try:
                instance_cursor.execute('''
                    INSERT INTO pending_payment
                    (id, channel, amount, account, sender, reference, message, received_at, status, matched_sale_id, notes)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', payment)
                migrated_count += 1
            except Exception as e:
                print(f"⚠️ Failed to migrate payment ID {payment[0]}: {e}")

        instance_conn.commit()
        instance_conn.close()

        print(f"✅ Successfully migrated {migrated_count}/{len(pending_payments)} records")

        # Optional: Backup and clean root database
        backup_name = f"pos_test_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
        shutil.copy2(root_db, backup_name)
        print(f"📋 Root database backed up as: {backup_name}")

        # Remove pending_payment table from root database
        try:
            root_conn = sqlite3.connect(root_db)
            root_cursor = root_conn.cursor()
            root_cursor.execute("DROP TABLE IF EXISTS pending_payment")
            root_conn.commit()
            root_conn.close()
            print("🗑️ Removed pending_payment table from root database")
        except Exception as e:
            print(f"⚠️ Could not clean root database: {e}")

        print("🎉 Migration completed successfully!")
        print(f"📊 All pending payment data is now in: {instance_db}")
        return True

    except Exception as e:
        print(f"❌ Error during migration: {e}")
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("🔄 PENDING PAYMENT DATABASE MIGRATION")
    print("=" * 60)

    success = migrate_pending_payments()

    if success:
        print("\n✅ Migration completed successfully!")
        print("💡 Next steps:")
        print("   1. Restart the backend server (backend.py)")
        print("   2. Test SMS payment processing")
        print("   3. Verify data integrity in instance/pos_test.db")
    else:
        print("\n❌ Migration failed!")
        print("💡 Check the error messages above and try again")

    print("=" * 60)