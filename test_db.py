#!/usr/bin/env python3

import os
import sqlite3
from flask import Flask
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///instance/test.db'
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
    'connect_args': {
        'check_same_thread': False,
        'timeout': 30.0,
        'isolation_level': None
    },
    'pool_pre_ping': True,
    'pool_recycle': 3600,
    'echo': False
}
db = SQLAlchemy(app)

class TestModel(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50))

if __name__ == '__main__':
    print("Testing SQLAlchemy database creation...")

    # Ensure instance directory exists
    os.makedirs('instance', exist_ok=True)

    try:
        with app.app_context():
            print("Creating tables...")
            db.create_all()
            print("✅ Tables created successfully")

            print("Testing query...")
            result = db.session.execute(db.text('SELECT 1')).scalar()
            print(f"✅ Query result: {result}")

            print("Adding test record...")
            test_record = TestModel(name="test")
            db.session.add(test_record)
            db.session.commit()
            print("✅ Record added successfully")

            print("Querying record...")
            records = TestModel.query.all()
            print(f"✅ Found {len(records)} records")

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

    print("Testing direct SQLite3...")
    try:
        conn = sqlite3.connect('instance/test.db')
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()
        print(f"✅ Direct SQLite tables: {tables}")
        conn.close()
    except Exception as e:
        print(f"❌ Direct SQLite error: {e}")
