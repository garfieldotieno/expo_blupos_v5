import sys
import os
import traceback
from datetime import datetime

if getattr(sys, 'frozen', False):
    # Get the project root directory (one level up from dist)
    base_dir = os.path.dirname(os.path.dirname(sys.executable))
    instance_dir = os.path.join(base_dir, "instance")
    
    # Ensure instance directory exists in project root
    if not os.path.exists(instance_dir):
        os.makedirs(instance_dir, exist_ok=True)
    
    # Use the database from project root instance directory
    db_path = os.path.join(instance_dir, "pos_test.db")
    print(f"[DEBUG] Frozen .exe DB path: {db_path}")

    # Explicitly set working directory to project root
    os.chdir(base_dir)
    print(f"[DEBUG] Changed working directory to project root: {os.getcwd()}")
else:
    base_dir = os.getcwd()
    db_path = os.path.join("instance", "pos_test.db")

    # Explicitly set working directory to project root
    os.chdir(base_dir)
    print(f"[DEBUG] Changed working directory to: {os.getcwd()}")

log_file = os.path.join(base_dir, "backend_log.txt")

def safe_print(msg):
    try:
        print(msg)
    except:
        pass

def write_log(msg):
    try:
        with open(log_file, 'a', encoding='utf-8') as f:
            f.write(str(msg) + '\n')
    except:
        pass

def global_excepthook(exc_type, exc_value, exc_tb):
    error_msg = f"\n=== UNHANDLED EXCEPTION ===\n{exc_type.__name__}: {exc_value}\n\n{''.join(traceback.format_tb(exc_tb))}"
    safe_print(error_msg)
    write_log(error_msg)
    safe_print("\n" + "="*80)
    safe_print("APP CRASHED")
    safe_print("="*80)
    input("\nPress Enter to close the window...")
    sys.exit(1)

sys.excepthook = global_excepthook

try:
    # Initialize logging first
    try:
        with open(log_file, 'w', encoding='utf-8') as f:
            f.write(f"=== Backend started at {datetime.now()} ===\n")
    except Exception as log_init_err:
        print(f"Failed to initialize log file: {log_init_err}")
        sys.exit(1)

    # Set up safe file handling
    class SafeFile:
        def __init__(self, file_path, mode):
            self.file = None
            try:
                self.file = open(file_path, mode, encoding='utf-8')
            except Exception as e:
                print(f"Failed to open file {file_path}: {e}")
                sys.exit(1)

        def write(self, msg):
            if self.file:
                try:
                    self.file.write(str(msg) + '\n')
                except Exception as e:
                    print(f"Failed to write to file: {e}")

        def flush(self):
            if self.file:
                try:
                    self.file.flush()
                except Exception as e:
                    print(f"Failed to flush file: {e}")

        def __del__(self):
            if self.file:
                try:
                    self.file.close()
                except:
                    pass

    # Create safe file handlers
    stdout_file = SafeFile(log_file, 'a')
    stderr_file = SafeFile(log_file, 'a')

    # Redirect output safely
    sys.stdout = stdout_file
    sys.stderr = stderr_file

    safe_print("Log initialized - Bypass migration mode")
    safe_print(f"Frozen: {getattr(sys, 'frozen', False)}")
    safe_print(f"Base dir: {base_dir}")
    safe_print(f"DB path: {db_path}")

    # Import dependencies safely
    try:
        import reportlab, xhtml2pdf, sqlalchemy, flask
        safe_print("Heavy imports successful.")
    except Exception as import_err:
        safe_print(f"Import error: {import_err}")
        sys.exit(1)

    safe_print("\nImporting backend with migration bypass...")

    # === BYPASS DANGEROUS MIGRATION IN backend.py ===
    backend = None
    try:
        import backend
        safe_print("Backend imported successfully.")
        backend = backend
    except Exception as import_err:
        safe_print(f"Import error caught: {import_err}")
        # If the error is exactly the ALTER TABLE issue, we continue anyway
        if "no such table: license" in str(import_err):
            safe_print("Bypassed the known ALTER TABLE migration error.")
            # Create minimal backend structure to continue
            class MinimalBackend:
                def __init__(self):
                    self.app = None
                    self.db = None

            backend = MinimalBackend()
        else:
            raise

    # Force safe DB path after import
    uri = f"sqlite:///{db_path.replace(os.sep, '/')}"
    if hasattr(backend, 'app') and hasattr(backend.app, 'config'):
        backend.app.config['SQLALCHEMY_DATABASE_URI'] = uri
        safe_print(f"Applied safe DB URI: {uri}")
    else:
        # Create minimal Flask app if backend.app doesn't exist
        from flask import Flask
        from flask_sqlalchemy import SQLAlchemy

        app = Flask(__name__)
        app.config['SQLALCHEMY_DATABASE_URI'] = uri
        app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
        db = SQLAlchemy(app)

        backend.app = app
        backend.db = db
        safe_print("Created minimal Flask app and database instance.")

    # Ensure database tables exist
    try:
        with backend.app.app_context():
            backend.db.create_all()
            safe_print("Database tables created successfully.")
    except Exception as e:
        safe_print(f"Database creation warning: {e}")

# Check for license table and create if missing
    try:
        with backend.app.app_context():
            from sqlalchemy import inspect
            inspector = inspect(backend.db.engine)
            if 'license' not in inspector.get_table_names():
                # Create license table with complete schema matching backend.py
                from sqlalchemy import Column, String, Integer, Boolean, DateTime
                from sqlalchemy.ext.declarative import declarative_base
                from datetime import datetime

                Base = declarative_base()
                class License(Base):
                    __tablename__ = 'license'
                    id = Column(Integer, primary_key=True)
                    account_id = Column(String(20))
                    uid = Column(String(10), unique=True, nullable=False)
                    license_key = Column(String(20), unique=True, nullable=False)
                    license_type = Column(String(10), nullable=False)
                    license_status = Column(Boolean, nullable=False)
                    license_expiry = Column(DateTime, nullable=False)
                    created_at = Column(DateTime, default=datetime.now)
                    updated_at = Column(DateTime, default=datetime.now)

                License.__table__.create(backend.db.engine)
                safe_print("✅ Created complete license table with all required columns")

                # Add missing columns if they don't exist
                conn = backend.db.engine.connect()
                result = conn.execute(db.text("PRAGMA table_info(license)"))
                columns = result.fetchall()
                column_names = [col[1] for col in columns]

                # Add missing columns from the complete schema
                required_columns = {
                    'uid': 'VARCHAR(10)',
                    'license_type': 'VARCHAR(10)',
                    'license_status': 'BOOLEAN',
                    'license_expiry': 'DATETIME',
                    'created_at': 'DATETIME',
                    'updated_at': 'DATETIME',
                    'device_id': 'VARCHAR(20)'
                }
                
                for col_name, col_type in required_columns.items():
                    if col_name not in column_names:
                        conn.execute(db.text(f"ALTER TABLE license ADD COLUMN {col_name} {col_type}"))
                        conn.commit()
                        safe_print(f"➕ Added missing {col_name} column to license table")
    except Exception as e:
        safe_print(f"License table creation warning: {e}")

    safe_print("\nAll startup steps completed!")

    if __name__ == "__main__":
        safe_print("Starting Flask server on http://0.0.0.0:8080 ...")
        backend.app.run(host='0.0.0.0', port=8080, debug=False)

except Exception as e:
    error_msg = f"\n=== CAUGHT EXCEPTION ===\n{type(e).__name__}: {e}\n\n{traceback.format_exc()}"
    safe_print(error_msg)
    write_log(error_msg)
    safe_print("\n" + "="*80)
    safe_print("STARTUP FAILED - See backend_log.txt")
    safe_print("="*80)
    input("\nPress Enter to close the window...")
    sys.exit(1)

input("\nApplication ended normally. Press Enter to close...")