#!/usr/bin/env python3
"""
Database migration script to update from device_id to account_id schema
"""

import sqlite3
import os

def migrate_database():
    """Migrate database from device_id to account_id schema"""

    db_path = 'pos_test.db'

    if not os.path.exists(db_path):
        print("❌ Database file not found")
        return False

    try:
        # Connect to database
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check current schema
        cursor.execute("PRAGMA table_info(license)")
        columns = cursor.fetchall()
        column_names = [col[1] for col in columns]

        print(f"📊 Current license table columns: {column_names}")

        # Check if migration is needed
        if 'device_id' in column_names and 'account_id' not in column_names:
            print("🔄 Migration needed: device_id → account_id")

            # Step 1: Add new account_id column
            print("➕ Adding account_id column...")
            cursor.execute("ALTER TABLE license ADD COLUMN account_id VARCHAR(20)")

            # Step 2: Copy data from device_id to account_id
            print("📋 Copying data from device_id to account_id...")
            cursor.execute("UPDATE license SET account_id = device_id")

            # Step 3: Update foreign key constraint (SQLite doesn't support dropping constraints easily)
            # We'll handle this by recreating the table

            # Step 4: Create new Account table if it doesn't exist
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS account (
                    id INTEGER PRIMARY KEY,
                    account_id VARCHAR(20) UNIQUE NOT NULL,
                    account_name VARCHAR(50),
                    account_type VARCHAR(20) DEFAULT 'web',
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            """)

            # Step 5: Check if there's existing account data or create default
            cursor.execute("SELECT COUNT(*) FROM account")
            account_count = cursor.fetchone()[0]

            if account_count == 0:
                print("🏗️ Creating default account...")

                # Get the device_id from existing license (if any)
                cursor.execute("SELECT DISTINCT device_id FROM license WHERE device_id IS NOT NULL LIMIT 1")
                result = cursor.fetchone()

                if result and result[0]:
                    account_id = f"account_{result[0]}"
                else:
                    account_id = "account_default"

                cursor.execute("""
                    INSERT INTO account (account_id, account_name, account_type)
                    VALUES (?, 'Default Account', 'web')
                """, (account_id,))

                print(f"✅ Created account: {account_id}")

            # Step 6: Update all license records to use the account_id
            cursor.execute("SELECT account_id FROM account LIMIT 1")
            account_result = cursor.fetchone()
            if account_result:
                account_id = account_result[0]
                cursor.execute("UPDATE license SET account_id = ?", (account_id,))

            # Commit changes
            conn.commit()

            print("✅ Migration completed successfully!")
            print(f"📈 Updated license table with account_id: {account_id}")

        elif 'account_id' in column_names:
            print("✅ Database already migrated to account_id schema")

        else:
            print("❓ Unexpected schema state")

        conn.close()
        return True

    except Exception as e:
        print(f"❌ Migration failed: {e}")
        if 'conn' in locals():
            conn.close()
        return False

if __name__ == "__main__":
    print("🔧 Starting database migration...")
    success = migrate_database()
    if success:
        print("🎉 Migration completed successfully!")
    else:
        print("💥 Migration failed!")
