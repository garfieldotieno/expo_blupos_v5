import sqlite3

def check_license_table():
    conn = sqlite3.connect('instance/pos_test.db')
    cursor = conn.cursor()
    
    try:
        # First check if license table exists
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='license'")
        table_exists = cursor.fetchone()
        
        if not table_exists:
            print("❌ License table does not exist")
            return []
        
        # Get table info
        cursor.execute('PRAGMA table_info(license)')
        columns = cursor.fetchall()
        
        if not columns:
            print("⚠️ License table exists but has no columns")
            return []
        
        print("License table columns:")
        for col in columns:
            print(f"{col[1]} ({col[2]})")
        
        # Check if account_id column exists
        column_names = [col[1] for col in columns]
        if 'account_id' in column_names:
            print("✅ account_id column exists")
        else:
            print("❌ account_id column missing")
        
        return column_names
    except Exception as e:
        print(f"Error checking license table: {e}")
        return []
    finally:
        conn.close()

if __name__ == "__main__":
    check_license_table()
