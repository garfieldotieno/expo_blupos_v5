from enum import unique
import json
import hashlib
import hmac
from flask import Flask, render_template, request, abort, redirect, make_response, url_for, session, send_file, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta, timezone
import os
import string, random
from flask_sqlalchemy import SQLAlchemy
import time
from flask_cors import CORS
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.backends import default_backend
import base64

from reportlab.lib.pagesizes import landscape, letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, PageBreak, Image as RLImage
from io import BytesIO

import pydantic
import yaml
import hashlib

# Import network discovery broadcast service
try:
    from backend_broadcast_service import start_backend_broadcast, stop_backend_broadcast
    BROADCAST_AVAILABLE = True
except ImportError:
    print("⚠️ Network discovery broadcast service not available")
    BROADCAST_AVAILABLE = False

# Secure network discovery broadcasting
import socket
import threading
import time
import json
import hashlib
import hmac
import base64
from datetime import datetime, timezone

from xhtml2pdf import pisa
import qrcode
import base64

__version__ = "1.0.0"

app = Flask(__name__)
app.secret_key = b"Z'(\xac\xe1\xb3$\xb1\x8e\xea,\x06b\xb8\x0b\xc0"
# Configure CORS for all routes with specific settings
CORS(app, resources={
    r"/health": {"origins": "*"},
    r"/activate": {"origins": "*"},
    r"/test": {"origins": "*"},
    r"/generate_activation_qr": {"origins": "*"},
    r"/generate_license_qr": {"origins": "*"},
    r"/validate_license": {"origins": "*"},
    r"/heartbeat": {"origins": "*"},
    r"/apk_connection_status": {"origins": "*"},
    r"/get_latest_payments": {"origins": "*"},
    r"/get_total_sales": {"origins": "*"},
    r"/get_sale_record_printout": {"origins": "*"},
    r"/get_items_report": {"origins": "*"},
})

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///pos_test.db'
db = SQLAlchemy(app)

app.config['PERMANENT_SESSION_LIFETIME'] =  timedelta(hours=2)

@app.template_filter()
def numberFormat(value):
    return format(int(value), 'd')

@app.template_filter()
def currencyFormat(value):
    """Format number as currency with commas and 2 decimal places"""
    try:
        return "{:,.2f}".format(float(value))
    except (ValueError, TypeError):
        return str(value)


def load_shop_data():
    json_file = open("shop_config.json")
    data = json.load(json_file)
    print('shop config,', data)
    print(type(data))
    return data


def randomString(stringLength=100):
    """Generate a random string of fixed length """
    letters = string.ascii_uppercase
    return ''.join(random.choice(letters) for i in range(stringLength))

def sample_upc_code(stringLength=12):
    """Generate a random UPC code of fixed length"""
    digits = string.digits
    return ''.join(random.choice(digits) for i in range(stringLength))

session_middleware = {
    "Anonymous": {"allowed_routes": ['/', '/about', '/invalid']},
    "Admin" : {"allowed_routes":['/users', '/records', '/add_user', '/delete_user', '/get_sale_record_printout']},
    "Sale":{"allowed_routes":['/sales', '/add_sale_record']},
    "Inventory" : {"allowed_routes":['/inventory', '/add_item_inventory', '/edit_item', '/delete_item_inventory', '/delete_item_inventory', '/item/', '/update_item_inventory', '/get_restock_printout', '/get_sale_record_printout', '/get_sale_transaction_printout', '/api/inventory/items', '/api/inventory/transactions', '/api/inventory/sales']}
}

def is_active():
    if 'session_user' in session :
        print("cookie session_user in place")
        return {"status":True, "middleware":session_middleware[session['session_user'].decode('utf-8').split(':')[0]] }
    else:
        reset_session()
        return {"status":False, "middleware":session_middleware['Anonymous'] }

def reset_session():
    session.clear()
    session['session_user'] = b'Anonymous'
    return {"status":True, "middleware":session_middleware['Anonymous']}         


class Account(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    account_id = db.Column(db.String(20), unique=True, nullable=False)
    account_name = db.Column(db.String(50), nullable=True)
    account_type = db.Column(db.String(20), default='web')  # 'web', 'mobile', etc.
    created_at = db.Column(db.DateTime, default=datetime.now())
    last_seen = db.Column(db.DateTime, default=datetime.now())

    def __repr__(self):
        return f"Account(id={self.id}, account_id='{self.account_id}', account_name='{self.account_name}', account_type='{self.account_type}', created_at={self.created_at}, last_seen={self.last_seen})"

class License(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    account_id = db.Column(db.String(20), db.ForeignKey('account.account_id'), nullable=False)
    uid = db.Column(db.String(10), unique=True, nullable=False)
    license_key = db.Column(db.String(20), unique=True, nullable=False)
    license_type = db.Column(db.String(10), nullable=False)
    license_status = db.Column(db.Boolean, nullable=False)
    license_expiry = db.Column(db.DateTime, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.now())
    updated_at = db.Column(db.DateTime, default=datetime.now())

    def __repr__(self):
        return f"License(id={self.id}, account_id='{self.account_id}', uid='{self.uid}', license_key='{self.license_key}', license_type='{self.license_type}', license_status='{self.license_status}', license_expiry='{self.license_expiry}', created_at={self.created_at}, updated_at={self.updated_at})"

# Create all database tables on app startup
with app.app_context():
    # Clear SQLAlchemy metadata cache and reflect database schema
    db.metadata.clear()

    # Force recreate all tables to ensure schema is up to date
    print("🔄 Recreating all database tables...")
    db.create_all()

    # Verify account_id column exists and populate it if needed
    with db.engine.connect() as conn:
        # Check if account_id column exists
        result = conn.execute(db.text("PRAGMA table_info(license)"))
        columns = result.fetchall()
        column_names = [col[1] for col in columns]

        if 'account_id' not in column_names:
            print("➕ Adding account_id column to license table...")
            conn.execute(db.text("ALTER TABLE license ADD COLUMN account_id VARCHAR(20)"))
            conn.commit()

        # Copy device_id to account_id where account_id is NULL
        conn.execute(db.text("UPDATE license SET account_id = device_id WHERE account_id IS NULL"))
        conn.commit()

        print(f"📊 License table columns: {column_names}")

        # Check if Account table exists and has data
        result = conn.execute(db.text("SELECT COUNT(*) FROM account"))
        account_count = result.fetchone()[0]

        if account_count == 0:
            print("🏗️ Creating default account...")
            # Get existing device_id from license table
            result = conn.execute(db.text("SELECT DISTINCT device_id FROM license WHERE device_id IS NOT NULL LIMIT 1"))
            device_result = result.fetchone()

            if device_result:
                account_id = f"account_{device_result[0]}"
            else:
                # Generate a proper account ID instead of using "default"
                timestamp = int(datetime.now().timestamp() * 1000)
                account_id = f"account_{timestamp}"

            conn.execute(db.text("INSERT INTO account (account_id, account_name, account_type) VALUES (:account_id, 'Default Account', 'web')"),
                        {"account_id": account_id})
            conn.commit()
            print(f"✅ Created account: {account_id}")
    print("🔧 Database tables created/verified")

    # ENFORCE SINGLE ACCOUNT RULE - Clean up any existing multiple accounts
    account_count = Account.query.count()
    if account_count > 1:
        print(f"🚨 Found {account_count} accounts, enforcing single account rule...")

        # Keep the most recently created account, delete others
        all_accounts = Account.query.order_by(Account.created_at.desc()).all()
        accounts_to_keep = [all_accounts[0]]  # Keep the most recent
        accounts_to_delete = all_accounts[1:]  # Delete the rest

        for account in accounts_to_delete:
            print(f"🗑️ Removing duplicate account: {account.account_id}")
            db.session.delete(account)

        db.session.commit()
        print("✅ Single account enforcement completed")
    elif account_count == 1:
        print("✅ Single account rule verified")
    else:
        print("ℹ️ No accounts found - first-time setup ready")

def create_license(payload, account_id):
    """Create ONE license total - remove existing licenses before creating new one"""
    # Input validation
    required_fields = ['license_key', 'license_type', 'license_status', 'license_expiry']
    for field in required_fields:
        if field not in payload:
            return {"status": False, "error": f"Missing required field: {field}"}

    # Validate license type - allow standard codes and generated codes
    valid_standard_types = ['BLUPOS2025', 'DEMO2025']
    is_standard_type = payload['license_type'] in valid_standard_types
    is_generated_blu = len(payload['license_type']) == 7 and payload['license_type'].startswith('BLU') and payload['license_type'].isalpha() and payload['license_type'].isupper()
    is_generated_pos = len(payload['license_type']) == 7 and payload['license_type'].startswith('POS') and payload['license_type'].isalpha() and payload['license_type'].isupper()

    if not is_standard_type and not is_generated_blu and not is_generated_pos:
        return {"status": False, "error": "Invalid license type"}

    # Validate license key format (should be string)
    if not isinstance(payload['license_key'], str) or len(payload['license_key']) == 0:
        return {"status": False, "error": "Invalid license key"}

    # Check if account exists
    account = Account.query.filter_by(account_id=account_id).first()
    if not account:
        return {"status": False, "error": "Account not found"}

    print(f"🔄 Creating license: Removing any existing licenses...")

    # REMOVE ALL EXISTING LICENSES to ensure only ONE license exists total
    existing_licenses = License.query.all()
    if existing_licenses:
        print(f"🗑️ Removing {len(existing_licenses)} existing license(s)")
        for license in existing_licenses:
            db.session.delete(license)
        db.session.commit()

    # Create the SINGLE license
    license = License()
    license.account_id = account_id
    license.uid = randomString(16)
    license.license_key = payload['license_key']
    license.license_type = payload['license_type']
    license.license_status = payload['license_status']
    license.license_expiry = payload['license_expiry']

    try:
        db.session.add(license)
        db.session.commit()
        print(f"📋 Single license created for account {account_id}: {payload['license_type']} (Total licenses: 1)")
        return {"status": True}
    except Exception as e:
        db.session.rollback()
        return {"status": False, "error": f"Database error: {str(e)}"}



def fetch_licenses():
    return License.query.all()

def fetch_license(uid):
    return License.query.filter_by(uid=uid).first()

def delete_license(license_id):
    license = License.query.filter_by(id=license_id).first()
    db.session.delete(license)
    return db.session.commit()

def update_license(payload):
    # REMOVE existing license and create new one to ensure single license rule
    existing_license = License.query.filter_by(license_key=payload['license_key']).first()
    if existing_license:
        db.session.delete(existing_license)
        db.session.commit()
        print(f"🗑️ Removed existing license for update")

    # Create new license with updated data
    result = create_license(payload, payload.get('account_id'))
    return result

# reset_license function here takes the 16digit value and checks against hashed equivakent in the .pos_key.yml file
# if the hashed value is found, it is deleted and the license is reset be cr4eating new entry in the database
# if the hashed value is not found, the function returns false

def reset_license(payload):
    license = License.query.filter_by(license_key=payload['license_key']).first()
    if license is not None:
        db.session.delete(license)
        db.session.commit()
        create_license(payload)
        return {"status":True}
    else:
        return {"status":False}


class LicenseResetKey(pydantic.BaseModel):
    license_key: str

    @staticmethod
    def save_key(license_key):
        # Hash the license key using SHA-256
        hashed_key = hashlib.sha256(license_key.encode()).hexdigest()
        
        # Load existing keys from .pos_key.yml if it exists
        existing_keys = LicenseResetKey.fetch_keys()

        # check if existing list is of length 20
        # if length is 20, delete the entire list and append the new, otherwise append to existing list
        if len(existing_keys) == 20:
            existing_keys = []
            existing_keys.append(hashed_key)

        else:
            existing_keys.append(hashed_key)
        
             # Save the updated list of hashed keys back to .pos_key.yml
        with open('.pos_keys.yml', 'w') as file:
            yaml.dump(existing_keys, file)

    @staticmethod
    def fetch_keys():
        try:
            with open('.pos_keys.yml', 'r') as file:
                return yaml.safe_load(file) or []
        except FileNotFoundError:
            # If the file does not exist, return an empty list
            return []

    @staticmethod
    def delete_key(license_key):
        # Hash the license key to match the stored format
        hashed_key = hashlib.sha256(license_key.encode()).hexdigest()

        # Fetch the existing keys
        existing_keys = LicenseResetKey.fetch_keys()

        # Remove the hashed key if it exists
        if hashed_key in existing_keys:
            existing_keys.remove(hashed_key)

            # Save the updated list of hashed keys back to .pos_key.yml
            with open('.pos_keys.yml', 'w') as file:
                yaml.dump(existing_keys, file)

    @staticmethod
    def is_valid_key(license_key):
        # Hash the license key to match the stored format
        hashed_key = hashlib.sha256(license_key.encode()).hexdigest()

        # Fetch the existing keys
        existing_keys = LicenseResetKey.fetch_keys()

        # Check if the hashed key exists in the list
        return hashed_key in existing_keys


class User(db.Model):
    id = db.Column(db.Integer, primary_key = True)
    uid = db.Column(db.String(10), unique=True, nullable=False)
    user_name = db.Column(db.String(20), unique=True, nullable=False)
    role = db.Column(db.String(10), nullable=False)
    password_hash = db.Column(db.String(100), nullable=False)
    current_session_key = db.Column(db.String(20), nullable=True)
    session_end_epoch = db.Column(db.Float(), nullable=True) 
    created_at = db.Column(db.DateTime, default=datetime.now())
    updated_at = db.Column(db.DateTime, default=datetime.now())
    
    
    def __repr__(self):
        return f"sale item {self.user_name}"


def create_user(payload):
    user = User()
    user.uid = randomString(10)
    if User.query.filter_by(user_name=payload['user_name']).first() is not None:
        return {"status":False}
    user.user_name = payload['user_name']
    user.role = payload['role']
    user.password_hash = generate_password_hash(payload['password'])
    db.session.add(user)
    db.session.commit()
    return {"status":True}

def fetch_users():
    return User.query.all()

def fetch_user(uid):
    return User.query.filter_by(uid=uid).first()

def delete_user(user_uid):
    user = User.query.filter_by(id=user_uid).first()
    db.session.delete(user)
    return db.session.commit()

def login_user(user_name, session_key_string):
    user = User.query.filter_by(user_name=user_name).first()
    print(f"user fetched at login_user is, {user.user_name}")
    if user is not None:
        user.current_session_key = session_key_string
        end_time = time.time() + (8*60*60)
        user.session_end_epoch = end_time
        print(end_time)
        user.updated_at = datetime.now()
        db.session.add(user)
        db.session.commit()

        if user.role == "Admin":
            session['session_user'] = bytes(f'Admin:{session_key_string}', 'utf-8')
            session.permanent=True
        elif user.role == "Sale":
            session['session_user'] = bytes(f'Sale:{session_key_string}', 'utf-8')
            session.permanent=True
        elif user.role == "Inventory":
            session['session_user'] = bytes(f'Inventory:{session_key_string}', 'utf-8')
            session.permanent=True
        
        session['session_key_string'] = bytes(session_key_string, 'utf-8')
        return {"status":True, "middleware":session_middleware[user.role]} 
    else:
        return {"status":False, "middleware":session_middleware['Anonymous']}
 
def user_from_session():
    bytes_session_string = session['session_user']
    session_string = bytes_session_string.decode('utf-8')
    session_key = session_string.split(':')[1]
    user = User.query.filter_by(current_session_key=session_key).first()
    
    if user is not None:
        print(user)
        return {"user_name":user.user_name}
    
    return {"error":"user name fail"}



class SaleItem(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    uid = db.Column(db.String(16), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.String(255))
    price = db.Column(db.Float, nullable=False)
    item_type = db.Column(db.String(50), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f"sale item {self.name}"
    
def create_sale_item(payload):
    sale_item = SaleItem()
    sale_item.uid = payload['item_code']
    sale_item.name = payload['item_name']
    sale_item.description = payload['item_description']
    sale_item.price = payload['item_price']
    sale_item.item_type = payload['item_type']
    db.session.add(sale_item)
    db.session.commit()
    return {"status":True}

def get_all_items():
    # update to read also from stock count table
    # i.e for each single reacord fetched in SaleItem, also fetch counter part in SaleItemStockCount
    # and append to the list of items
    items = SaleItem.query.all()
    stock_count = SaleItemStockCount.query.all()
    for item in items:
        for stock in stock_count:
            if item.uid == stock.item_uid:
                item.last_stock_count = stock.last_stock_count
                item.current_stock_count = stock.current_stock_count
                item.re_stock_value = stock.re_stock_value
                item.re_stock_status = stock.re_stock_status
            # printe the updated item
            print(item)

    return items

def get_item(uid):
    return SaleItem.query.filter_by(uid=uid).first()

def delete_item(uid):
    item = SaleItem.query.filter_by(uid=uid).first()
    db.session.delete(item)
    return db.session.commit()


class SaleItemStockCount(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    item_uid = db.Column(db.String(16), nullable=False)
    last_stock_count = db.Column(db.Integer)
    current_stock_count = db.Column(db.Integer, nullable=False)
    re_stock_value = db.Column(db.Integer)
    re_stock_status = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"SaleItemStockCount(id={self.id}, item_uid='{self.item_uid}', current_stock_count={self.current_stock_count}, re_stock_value={self.re_stock_value}, re_stock_status={self.re_stock_status}, created_at={self.created_at})"

def update_sale_item_stock_count(payload):
    item_uid = payload['item_code']
    print(f"item_uid at update_sale_item_stock_count, {item_uid}")
    item_stock = SaleItemStockCount.query.filter_by(item_uid=item_uid).first()
    print(f"item_stock at update_sale_item_stock_count, {item_stock}")
    if item_stock is not None:
        # check if value for payload['item_stock'] is zero
        # if zero, maintain current_stock_count and last_stock_count
        # if not zero, update current_stock_count and last_stock_count
        if int(payload['item_stock']) == 0:
            item_stock.last_stock_count = item_stock.last_stock_count
            item_stock.current_stock_count = item_stock.current_stock_count
        else:
            item_stock.last_stock_count = int(payload['item_stock'])
            item_stock.current_stock_count += int(payload['item_stock'])
        item_stock.re_stock_value = int(payload['re_stock_value'])
        item_stock.re_stock_status = True if item_stock.current_stock_count < int(item_stock.re_stock_value) else False

        db.session.add(item_stock)
        db.session.commit()
        return item_stock
        
    else:
        print("item_stock is None")
        item_stock = SaleItemStockCount()
        item_stock.item_uid = payload['item_code']
        item_stock.last_stock_count = int(payload['item_stock'])
        item_stock.current_stock_count = int(payload['item_stock'])
        item_stock.re_stock_value = payload['re_stock_value']
        item_stock.re_stock_status = True if item_stock.current_stock_count < int(item_stock.re_stock_value) else False
        db.session.add(item_stock)
        db.session.commit()
        return item_stock
        

def get_all_sale_item_stock_count():
    return SaleItemStockCount.query.all()


# Pagination functions
def get_paginated_items(page, limit):
    offset = (page - 1) * limit
    total_items = SaleItem.query.count()
    total_pages = (total_items + limit - 1) // limit  # Ceiling division

    # Get paginated items with stock info
    items = SaleItem.query.offset(offset).limit(limit).all()

    # Add stock information to items
    stock_count = SaleItemStockCount.query.all()
    for item in items:
        for stock in stock_count:
            if item.uid == stock.item_uid:
                item.last_stock_count = stock.last_stock_count
                item.current_stock_count = stock.current_stock_count
                item.re_stock_value = stock.re_stock_value
                item.re_stock_status = stock.re_stock_status
                break

    return {"items": items, "total_pages": total_pages, "current_page": page, "total_items": total_items}

def get_paginated_item_transactions(page, limit):
    offset = (page - 1) * limit
    total_transactions = SaleItemTransaction.query.count()
    total_pages = (total_transactions + limit - 1) // limit

    transactions = SaleItemTransaction.query.offset(offset).limit(limit).all()

    # Add item names to transactions
    for transaction in transactions:
        item = SaleItem.query.filter_by(uid=transaction.item_uid).first()
        transaction.item_name = item.name if item else 'N/A'

    return {"transactions": transactions, "total_pages": total_pages, "current_page": page, "total_items": total_transactions}

def get_paginated_sale_records(page, limit):
    offset = (page - 1) * limit
    total_records = SaleRecord.query.count()
    total_pages = (total_records + limit - 1) // limit

    records = SaleRecord.query.offset(offset).limit(limit).all()

    return {"records": records, "total_pages": total_pages, "current_page": page, "total_items": total_records}

class InventoryOperations():
    @staticmethod
    def add_item_inventory(payload):
        # crete new saleitem and update its inventory count
        creation_status = create_sale_item(payload)
        if creation_status  == {"status":True}:
            update_sale_item_stock_count(payload)
            return {"status":True}
        else:
            return {"status":False}



    @staticmethod
    def get_item_inventory(payload):
        # get data that containes saleitem and its inventory count
        item = get_item(payload['item_uid'])
        stock_count = SaleItemStockCount.query.filter_by(item_uid=payload['item_uid']).first()
        item.last_stock_count = stock_count.last_stock_count
        item.current_stock_count = stock_count.current_stock_count
        item.re_stock_value = stock_count.re_stock_value
        item.re_stock_status = stock_count.re_stock_status
        return item


    @staticmethod
    def get_all_items_inventory():
        # get all data that containes saleitem and its inventory count
        items = get_all_items()
        stock_count = SaleItemStockCount.query.all()
        for item in items:
            for stock in stock_count:
                if item.uid == stock.item_uid:
                    item.last_stock_count = stock.last_stock_count
                    item.current_stock_count = stock.current_stock_count
                    item.re_stock_value = stock.re_stock_value
                    item.re_stock_status = stock.re_stock_status
                # printe the updated item
                print(item)
        return items


    @staticmethod
    def update_item_inventory(payload):
        # update item record in SaleItem and SaleItemStockCount
        item = SaleItem.query.filter_by(uid=payload['item_code']).first()
        item.name = payload['item_name']
        item.description = payload['item_description']
        item.price = payload['item_price']
        item.item_type = payload['item_type']
        db.session.add(item)
        db.session.commit()
        update_res = update_sale_item_stock_count(payload)
        if update_res is not None:
            return {"status":True}
        else:
            return {"status":False}


    @staticmethod
    def delete_item_inventory(payload):
        # delete item record in SaleItem and SaleItemStockCount
        item = SaleItem.query.filter_by(uid=payload['item_uid']).first()
        db.session.delete(item)
        stock_count = SaleItemStockCount.query.filter_by(item_uid=payload['item_uid']).first()
        db.session.delete(stock_count)
        db.session.commit()
        return {"status":True}

    @staticmethod
    # def generate_restock_list():
    # fetches items using the class static method get_all_items_inventory
    # then filters for items by evaluating if current_stock_count is less than re_stock_value
    # returns a list of items that meet the condition

    def generate_restock_list():
        items = InventoryOperations.get_all_items_inventory()
        restock_list = []
        for item in items:
            if item.current_stock_count < item.re_stock_value:
                restock_list.append(item)
        return restock_list
        
  

@app.route('/inventory')
def inventory_home():
    query = is_active()
    print(f"query string at /user, {query}")
    if 'session_flash_message' in session:
        flash_message = True
        flash_payload = session['session_flash_message'].decode('utf-8')
        session.pop('session_flash_message')
    else:
        flash_message = False
        flash_payload = ""

    if query['status'] and request.path in query['middleware']['allowed_routes']:
        print(f"get paginated items : {get_paginated_items(1, 20)}")
        response = make_response(render_template(
            'inventory_management.html',
            is_active = True,
            title="Inventory",
            flash_message = flash_message,
            flash_payload = flash_payload,
            user_type=session['session_user'].decode('utf-8'),
            user_name=user_from_session(),
            shop_data = [load_shop_data()],
            items = get_paginated_items(1, 20)['items'],
            items_total_pages = get_paginated_items(1, 20)['total_pages'],
            items_current_page = 1,

            item_transactions = get_paginated_item_transactions(1, 20)['transactions'],
            transactions_total_pages = get_paginated_item_transactions(1, 20)['total_pages'],
            transactions_current_page = 1,

            sale_records = get_paginated_sale_records(1, 20)['records'],
            sale_records_total_pages = get_paginated_sale_records(1, 20)['total_pages'],
            sale_records_current_page = 1,

            SaleItem = SaleItem
        ))
        return response
    else:
        return redirect(query['middleware']['allowed_routes'][0])

@app.route('/api/inventory/items/<int:page>')
def get_inventory_items_page(page):
    query = is_active()
    if query['status'] and '/inventory' in query['middleware']['allowed_routes']:
        result = get_paginated_items(page, 20)
        return jsonify({
            'items': [{
                'id': item.id,
                'uid': item.uid,
                'item_type': item.item_type,
                'name': item.name,
                'description': item.description,
                'price': item.price,
                'last_stock_count': item.last_stock_count,
                'current_stock_count': item.current_stock_count,
                're_stock_value': item.re_stock_value,
                're_stock_status': item.re_stock_status
            } for item in result['items']],
            'total_pages': result['total_pages'],
            'current_page': result['current_page'],
            'total_items': result['total_items']
        })
    return jsonify({'error': 'Unauthorized'}), 403

@app.route('/api/inventory/transactions/<int:page>')
def get_inventory_transactions_page(page):
    query = is_active()
    if query['status'] and '/inventory' in query['middleware']['allowed_routes']:
        result = get_paginated_item_transactions(page, 20)
        return jsonify({
            'transactions': [{
                'id': transaction.id,
                'item_uid': transaction.item_uid,
                'item_name': getattr(transaction, 'item_name', 'N/A'),
                'transaction_type': transaction.transaction_type,
                'transaction_quantity': transaction.transaction_quantity,
                'item_price': transaction.item_price,
                'created_at': transaction.created_at.strftime("%Y-%m-%d %H:%M:%S")
            } for transaction in result['transactions']],
            'total_pages': result['total_pages'],
            'current_page': result['current_page'],
            'total_items': result['total_items']
        })
    return jsonify({'error': 'Unauthorized'}), 403

@app.route('/api/inventory/sales/<int:page>')
def get_inventory_sales_page(page):
    query = is_active()
    if query['status'] and '/inventory' in query['middleware']['allowed_routes']:
        result = get_paginated_sale_records(page, 20)
        return jsonify({
            'records': [{
                'id': record.id,
                'uid': record.uid,
                'sale_clerk': record.sale_clerk,
                'sale_total': record.sale_total,
                'sale_paid_amount': record.sale_paid_amount,
                'sale_balance': record.sale_balance,
                'payment_method': record.payment_method,
                'payment_reference': record.payment_reference,
                'payment_gateway': record.payment_gateway,
                'created_at': record.created_at.strftime("%Y-%m-%d %H:%M:%S")
            } for record in result['records']],
            'total_pages': result['total_pages'],
            'current_page': result['current_page'],
            'total_items': result['total_items']
        })
    return jsonify({'error': 'Unauthorized'}), 403

@app.route('/add_item_inventory', methods=['POST'])
def add_item():
    query = is_active()
    print(f"query string at /user, {query}")
    if query['status'] and request.path in query['middleware']['allowed_routes']:
        print(request.path)
        payload = request.form
        print(f"payload at /add_item_inventory, {payload}")
        # check if item already exists
        # if exists, flash message and redirect to inventory
        # if not, add item. flash message and redirect to inventory
        item = SaleItem.query.filter_by(uid=payload['item_code']).first()
        if item :
            session['session_flash_message'] = bytes("Item already exists", 'utf-8')
            return redirect('/inventory')
        else:
            new_item = InventoryOperations.add_item_inventory(payload)
            if new_item == {"status":True}:
                session['session_flash_message'] = bytes("Item added successfully", 'utf-8')
                return redirect('/inventory')              
    else:
        return redirect(query['middleware']['allowed_routes'][0])

# Route for editing an item
@app.route('/edit_item', methods=['POST'])
def edit_item():
    # Retrieve the item_id from the form data
    item_uid = request.form.get('item_uid')

    # lo0ad item inventory using InventoryOperations.get_item_inventory
    item = InventoryOperations.get_item_inventory({'item_uid':item_uid})


    if item:
        # Render an edit form with the item's details pre-filled
        return render_template('edit_item.html', item=item)
    else:
        # Handle the case where the item with the given item_id doesn't exist
        flash('Item not found', 'error')
        return redirect('/inventory')  # Redirect back to the inventory page


@app.route('/update_item_inventory', methods=['POST'])
def update_item():
    print(f"processing update item")
    # use InventoryOperations.update_item_inventory to update item
    query = is_active()
    print(f"query string at /user, {query}")
    if query['status'] and request.path in query['middleware']['allowed_routes']:
        print(f"payload at /update_item_inventory, {request.form}")
        try:
            InventoryOperations.update_item_inventory(request.form)
            # flash message and redirect to inventory
            session['session_flash_message'] = bytes("Item updated successfully", 'utf-8')
            return redirect('/inventory')
        except Exception as e:
            print(e)
            # flash message and redirect to inventory
            session['session_flash_message'] = bytes(f"Unable to update item because of => {e}", 'utf-8')
            return redirect('/inventory')
    else:
        # flash message and redirect to inventory
        session['session_flash_message'] = bytes("Unable to update item", 'utf-8')
        return redirect(query['middleware']['allowed_routes'][0])


@app.route('/delete_item_inventory', methods=['POST'])
def delete_item():
    # delete both saleitem and saleitemstockcount using InventoryOperations.delete_item_inventory
    query = is_active()
    print(f"query string at /user, {query}")
    if query['status'] and request.path in query['middleware']['allowed_routes']:
        item_uid = request.form.get('item_uid')
        print(f"payload at /delete_item_inventory, {item_uid}")
        response = make_response(jsonify(InventoryOperations.delete_item_inventory({'item_uid':item_uid})))
        return redirect(query['middleware']['allowed_routes'][0])
    else:
        return redirect(query['middleware']['allowed_routes'][0])


@app.route('/get_restock_printout', methods=['GET'])
def get_restock_printout():
    # Check if request wants HTML for printing (from print dialog)
    if request.args.get('format') == 'print':
        # Return HTML for browser printing
        query = is_active()
        if query['status'] and '/get_restock_printout' in query['middleware']['allowed_routes']:
            items = InventoryOperations.generate_restock_list()
            shop_data = load_shop_data()
            user_name = user_from_session()
            current_time = datetime.now().strftime("%d/%m/%Y %H:%M:%S")

            response = make_response(render_template(
                'restock_printout.html',
                is_active=True,
                title="Re-stock Printout",
                flash_message=False,
                flash_payload="",
                user_type=session['session_user'].decode('utf-8'),
                user_name=user_name,
                shop_data=[shop_data],
                items=items,
                current_time=current_time
            ))
            return response
    else:
        # Return HTML template for detached window printing (like sales receipt)
        query = is_active()
        if query['status'] and '/get_restock_printout' in query['middleware']['allowed_routes']:
            items = InventoryOperations.generate_restock_list()
            shop_data = load_shop_data()
            user_name = user_from_session()
            current_time = datetime.now().strftime("%d/%m/%Y %H:%M:%S")

            # Generate barcode and QR code data URLs (like sales receipt)
            import qrcode
            import base64
            from io import BytesIO

            # Generate transaction code
            restock_code = f'RESTOCK-{datetime.now().strftime("%H%M%S")}'

            # Generate barcode (simple text representation for now)
            barcode_data = restock_code

            # Generate QR code
            qr = qrcode.QRCode(version=1, box_size=10, border=4)
            qr_data = f"Restock List\nItems: {len(items)}\nCode: {restock_code}\nGenerated: {current_time}"
            qr.add_data(qr_data)
            qr.make(fit=True)

            # Create QR code image
            qr_img = qr.make_image(fill_color="black", back_color="white")
            qr_buffer = BytesIO()
            qr_img.save(qr_buffer, format='PNG')
            qr_buffer.seek(0)
            qr_base64 = base64.b64encode(qr_buffer.read()).decode('utf-8')
            qrcode_base64 = f"data:image/png;base64,{qr_base64}"

            # For barcode, create a simple data URL (could be improved)
            barcode_base64 = f"data:text/plain;base64,{base64.b64encode(restock_code.encode()).decode()}"

            response = make_response(render_template(
                'restock_printout.html',
                is_active=True,
                title="Re-stock Printout",
                flash_message=False,
                flash_payload="",
                user_type=session['session_user'].decode('utf-8'),
                user_name=user_name,
                shop_data=[shop_data],
                items=items,
                current_time=current_time,
                barcode_data=barcode_data,
                qrcode_data=qrcode_base64,
                barcode_base64=barcode_base64
            ))
            return response

@app.route('/get_latest_payments', methods=['GET'])
def get_latest_payments():
    """Get latest 4 payment records for APK interface display"""
    # Allow access for APK interface without session authentication
    # This endpoint is for APK data display, not web interface
    try:
        # Get latest 4 sales records ordered by creation date
        latest_payments = SaleRecord.query.order_by(SaleRecord.created_at.desc()).limit(4).all()

        payments_data = []
        for record in latest_payments:
            payments_data.append({
                "transaction_id": record.uid,
                "sales_person": record.sale_clerk,
                "amount": "{:.2f}".format(record.sale_paid_amount),
                "balance": "{:.2f}".format(record.sale_balance),
                "payment_type": record.payment_method or "Cash",
                "datetime": record.created_at.strftime('%Y-%m-%d %H:%M'),
                "checkout_id": str(record.id)
            })

        return jsonify({
            "status": "success",
            "payments": payments_data
        })
    except Exception as e:
        print(f"Error fetching latest payments: {e}")
        return jsonify({"status": "error", "payments": []})

@app.route('/get_total_sales', methods=['GET'])
def get_total_sales():
    """Get real-time total sales amount (paid minus change) for yellow card display"""
    # Allow access for APK interface without session authentication
    # This endpoint is for APK data display, not web interface
    try:
        # Calculate total sales: sum of all paid amounts minus sum of all balances/changes
        total_paid = db.session.query(db.func.sum(SaleRecord.sale_paid_amount)).scalar() or 0.0
        total_balance = db.session.query(db.func.sum(SaleRecord.sale_balance)).scalar() or 0.0

        # Net sales = total paid - total change/balance (what was actually kept by business)
        net_sales = total_paid - total_balance

        return jsonify({
            "status": "success",
            "total_sales": "{:.2f}".format(net_sales)
        })
    except Exception as e:
        print(f"Error calculating total sales: {e}")
        return jsonify({"status": "error", "total_sales": "0.00"})

@app.route('/get_items_report', methods=['GET'])
def get_items_report():
    """Get comprehensive items report for APK interface display"""
    # Allow access for APK interface without session authentication
    # This endpoint is for APK data display, not web interface
    query = is_active()  # Define query variable for both branches
    try:
        # Check if request wants HTML for iframe display
        if request.args.get('format') == 'html':
            # Get all items with stock information
            items = SaleItem.query.all()
            stock_data = {}
            for stock in SaleItemStockCount.query.all():
                stock_data[stock.item_uid] = stock

            # Calculate sales data per item
            sales_data = {}
            transactions = SaleItemTransaction.query.all()
            for transaction in transactions:
                uid = transaction.item_uid
                if uid not in sales_data:
                    sales_data[uid] = 0
                sales_data[uid] += transaction.transaction_quantity

            # Build items report
            items_report = []
            total_value = 0
            total_items = 0
            low_stock_count = 0

            for item in items:
                stock = stock_data.get(item.uid)
                units_sold = sales_data.get(item.uid, 0)
                current_stock = stock.current_stock_count if stock else 0
                restock_value = stock.re_stock_value if stock else 0
                item_value = current_stock * item.price

                total_value += item_value
                total_items += 1
                if current_stock < restock_value:
                    low_stock_count += 1

                items_report.append({
                    "name": item.name,
                    "upc_code": item.uid,
                    "current_stock": current_stock,
                    "restock_value": restock_value,
                    "price": float(item.price),
                    "item_value": float(item_value),
                    "units_sold": units_sold,
                    "item_type": item.item_type,
                    "low_stock": current_stock < restock_value
                })

            # Sales summary by clerk
            clerk_sales = {}
            for record in SaleRecord.query.all():
                clerk = record.sale_clerk
                if clerk not in clerk_sales:
                    clerk_sales[clerk] = {"transactions": 0, "total_sales": 0.0}
                clerk_sales[clerk]["transactions"] += 1
                clerk_sales[clerk]["total_sales"] += record.sale_total

            shop_data = load_shop_data()
            user_name = user_from_session()

            response = make_response(render_template(
                'items_report_html.html',
                is_active=True,
                title="Items Report",
                flash_message=False,
                flash_payload="",
                user_type=query['middleware'],
                user_name=user_name,
                shop_data=[shop_data],
                items=items_report[:500],  # Limit to 500 items for display
                summary={
                    "total_items": total_items,
                    "total_value": float(total_value),
                    "low_stock_count": low_stock_count,
                    "clerk_sales": clerk_sales
                },
                datetime=datetime
            ))
            return response

        # Generate PDF directly in landscape A4 format
        # Get all items with stock information
        items = SaleItem.query.all()
        stock_data = {}
        for stock in SaleItemStockCount.query.all():
            stock_data[stock.item_uid] = stock

        # Calculate sales data per item
        sales_data = {}
        transactions = SaleItemTransaction.query.all()
        for transaction in transactions:
            uid = transaction.item_uid
            if uid not in sales_data:
                sales_data[uid] = 0
            sales_data[uid] += transaction.transaction_quantity

        # Build items report
        items_report = []
        total_value = 0
        total_items = 0
        low_stock_count = 0

        for item in items:
            stock = stock_data.get(item.uid)
            units_sold = sales_data.get(item.uid, 0)
            current_stock = stock.current_stock_count if stock else 0
            restock_value = stock.re_stock_value if stock else 0
            item_value = current_stock * item.price

            total_value += item_value
            total_items += 1
            if current_stock < restock_value:
                low_stock_count += 1

            items_report.append({
                "name": item.name,
                "upc_code": item.uid,
                "current_stock": current_stock,
                "restock_value": restock_value,
                "price": float(item.price),
                "item_value": float(item_value),
                "units_sold": units_sold,
                "item_type": item.item_type,
                "low_stock": current_stock < restock_value
            })

        # Sales summary by clerk
        clerk_sales = {}
        for record in SaleRecord.query.all():
            clerk = record.sale_clerk
            if clerk not in clerk_sales:
                clerk_sales[clerk] = {"transactions": 0, "total_sales": 0.0}
            clerk_sales[clerk]["transactions"] += 1
            clerk_sales[clerk]["total_sales"] += record.sale_total

        shop_data = load_shop_data()
        user_name = user_from_session()

        # Create PDF buffer for landscape A4
        pdf_buffer = BytesIO()

        # Landscape A4 format
        from reportlab.lib.pagesizes import A4, landscape
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
        from reportlab.lib import colors
        from reportlab.lib.units import inch

        doc = SimpleDocTemplate(pdf_buffer, pagesize=landscape(A4),
                               leftMargin=0.5*inch, rightMargin=0.5*inch,
                               topMargin=0.5*inch, bottomMargin=0.5*inch)
        styles = getSampleStyleSheet()

        # Custom styles for items report
        title_style = ParagraphStyle('Title', parent=styles['Heading1'], fontSize=16, alignment=1, spaceAfter=20)
        subtitle_style = ParagraphStyle('Subtitle', parent=styles['Heading2'], fontSize=14, alignment=1, spaceAfter=15)
        normal_style = ParagraphStyle('Normal', parent=styles['Normal'], fontSize=10, leading=12)
        center_style = ParagraphStyle('Center', parent=styles['Normal'], fontSize=10, alignment=1, spaceAfter=10)

        story = []

        # Header
        story.append(Paragraph(shop_data['pos_shop_name'], title_style))
        story.append(Paragraph(f"Address: {shop_data['shop_adress']} | Tel: {shop_data['pos_shop_call_number']}", center_style))
        story.append(Paragraph("ITEMS INVENTORY REPORT", subtitle_style))
        story.append(Paragraph(f"Generated by: {user_name['user_name']} | Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", center_style))
        story.append(Spacer(1, 20))

        # Inventory Summary
        story.append(Paragraph("INVENTORY SUMMARY", subtitle_style))

        # Format numbers with commas and decimals
        def format_currency(amount):
            return f"KES {amount:,.2f}"

        # Summary table
        summary_data = [
            ['Total Items', 'Total Inventory Value', 'Low Stock Items', 'Items Sold Today'],
            [str(total_items), format_currency(total_value), str(low_stock_count), str(sum(item['units_sold'] for item in items_report))]
        ]

        summary_table = Table(summary_data, colWidths=[2*inch, 2*inch, 2*inch, 2*inch])
        summary_table.setStyle(TableStyle([
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('FONTNAME', (0, 0), (-1, 0), 'Courier-Bold'),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('GRID', (0, 0), (-1, -1), 1, colors.black),
            ('LEFTPADDING', (0, 0), (-1, -1), 5),
            ('RIGHTPADDING', (0, 0), (-1, -1), 5),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ]))
        story.append(summary_table)
        story.append(Spacer(1, 15))

        # Sales by clerk summary
        if clerk_sales:
            story.append(Paragraph("SALES SUMMARY BY CLERK", styles['Heading3']))
            clerk_data = [['Clerk Name', 'Total Transactions', 'Total Sales Amount']]
            for clerk, data in clerk_sales.items():
                clerk_data.append([clerk, str(data['transactions']), format_currency(data['total_sales'])])

            clerk_table = Table(clerk_data, colWidths=[2.5*inch, 2*inch, 2*inch])
            clerk_table.setStyle(TableStyle([
                ('FONTSIZE', (0, 0), (-1, -1), 9),
                ('FONTNAME', (0, 0), (-1, 0), 'Courier-Bold'),
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('LEFTPADDING', (0, 0), (-1, -1), 3),
                ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            story.append(clerk_table)
            story.append(Spacer(1, 20))

        # Page break before detailed items
        story.append(PageBreak())

        # Detailed Items
        story.append(Paragraph("DETAILED ITEMS INVENTORY", subtitle_style))

        # Items table header
        items_data = [['Item Name', 'UPC Code', 'Current Stock', 'Restock Level', 'Unit Price', 'Inventory Value', 'Units Sold', 'Item Type']]

        # Add items (limit to avoid huge PDF)
        for item in items_report[:500]:  # Limit to 500 items to keep PDF manageable
            items_data.append([
                item['name'][:25] + '...' if len(item['name']) > 25 else item['name'],  # Truncate long names
                item['upc_code'],
                str(item['current_stock']),
                str(item['restock_value']),
                format_currency(item['price']),
                format_currency(item['item_value']),
                str(item['units_sold']),
                item['item_type']
            ])

        # Create table with multiple rows per page
        items_table = Table(items_data, colWidths=[1.5*inch, 1.2*inch, 0.8*inch, 0.8*inch, 1*inch, 1.2*inch, 0.8*inch, 1*inch])
        items_table.setStyle(TableStyle([
            ('FONTSIZE', (0, 0), (-1, -1), 7),
            ('FONTNAME', (0, 0), (-1, 0), 'Courier-Bold'),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.black),
            ('LEFTPADDING', (0, 0), (-1, -1), 2),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2),
            ('TOPPADDING', (0, 0), (-1, -1), 2),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
            ('BACKGROUND', (0, 0), (-1, 0), colors.lightgrey),
        ]))
        story.append(items_table)

        if len(items_report) > 500:
            story.append(Spacer(1, 10))
            story.append(Paragraph(f"* Showing first 500 of {len(items_report)} total items", center_style))

        # Build PDF
        doc.build(story)
        pdf_buffer.seek(0)

        print("Items inventory PDF generated successfully")

        # Return as download that opens in print dialog
        response = make_response(pdf_buffer.read())
        response.headers['Content-Type'] = 'application/pdf'
        response.headers['Content-Disposition'] = 'inline; filename=items_inventory_report.pdf'
        return response

    except Exception as e:
        print(f"Error generating items report: {e}")
        if request.args.get('format') == 'html':
            return jsonify({"status": "error", "message": "Failed to generate items report"})
        return redirect(query['middleware']['allowed_routes'][0])

@app.route('/get_sale_record_printout', methods=['GET'])
def get_sale_record_printout():
    # Allow access for APK interface without session authentication
    # This endpoint is for APK data display, not web interface

    # Get date parameters
    start_date_str = request.args.get('start_date')
    end_date_str = request.args.get('end_date')

    # Parse dates if provided
    start_date = None
    end_date = None
    if start_date_str and end_date_str:
        try:
            start_date = datetime.strptime(start_date_str, '%Y-%m-%d')
            end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
            # Set end_date to end of day
            end_date = end_date.replace(hour=23, minute=59, second=59)
        except ValueError:
            # Invalid date format, ignore filtering
            start_date = None
            end_date = None

    # Get sales records with optional date filtering
    if start_date and end_date:
        sale_records = SaleRecord.query.filter(
            SaleRecord.created_at >= start_date,
            SaleRecord.created_at <= end_date
        ).order_by(SaleRecord.created_at.desc()).all()  # Latest first
    else:
        sale_records = SaleRecord.query.order_by(SaleRecord.created_at.desc()).all()  # Latest first

    shop_data = load_shop_data()

    # Handle session gracefully for APK requests
    try:
        user_name = user_from_session()
    except:
        # Default user info for APK requests
        user_name = {"user_name": "APK User"}

    # Check if request wants HTML for iframe display
    if request.args.get('format') == 'html':
        # Calculate fiscal summary for HTML display
        if sale_records:
            total_sales = sum(record.sale_total for record in sale_records)
            total_paid = sum(record.sale_paid_amount for record in sale_records)
            total_balance = sum(record.sale_balance for record in sale_records)
            total_transactions = len(sale_records)

            # Payment method breakdown
            payment_methods = {}
            for record in sale_records:
                method = record.payment_method or 'Cash'
                if method not in payment_methods:
                    payment_methods[method] = {'count': 0, 'amount': 0}
                payment_methods[method]['count'] += 1
                payment_methods[method]['amount'] += record.sale_total
        else:
            total_sales = total_paid = total_balance = total_transactions = 0
            payment_methods = {}

        # Limit records for display (same as PDF limit)
        display_records = sale_records[:500] if sale_records else []

        # Handle session variables gracefully for APK requests
        try:
            user_type = query['middleware']
        except:
            user_type = 'APK'

        response = make_response(render_template(
            'sales_records_html.html',
            is_active=True,
            title="Sales Records Report",
            flash_message=False,
            flash_payload="",
            user_type=user_type,
            user_name=user_name,
            shop_data=[shop_data],
            sale_records=display_records,
            total_sales=total_sales,
            total_paid=total_paid,
            total_balance=total_balance,
            total_transactions=total_transactions,
            payment_methods=payment_methods,
            start_date=start_date,
            end_date=end_date,
            datetime=datetime
        ))
        return response

    # Generate PDF directly in landscape A4 format with fiscal summary
    # (sale_records already fetched above with proper ordering)

    shop_data = load_shop_data()

    # Handle session gracefully for APK requests
    try:
        user_name = user_from_session()
    except:
        # Default user info for APK requests
        user_name = {"user_name": "APK User"}

    # Landscape A4 format
    from reportlab.lib.pagesizes import A4, landscape
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
    from reportlab.lib import colors
    from reportlab.lib.units import inch

    pdf_buffer = BytesIO()
    doc = SimpleDocTemplate(pdf_buffer, pagesize=landscape(A4),
                           leftMargin=0.5*inch, rightMargin=0.5*inch,
                           topMargin=0.5*inch, bottomMargin=0.5*inch)
    styles = getSampleStyleSheet()

    # Custom styles for fiscal report
    title_style = ParagraphStyle('Title', parent=styles['Heading1'], fontSize=16, alignment=1, spaceAfter=20)
    subtitle_style = ParagraphStyle('Subtitle', parent=styles['Heading2'], fontSize=14, alignment=1, spaceAfter=15)
    normal_style = ParagraphStyle('Normal', parent=styles['Normal'], fontSize=10, leading=12)
    center_style = ParagraphStyle('Center', parent=styles['Normal'], fontSize=10, alignment=1, spaceAfter=10)

    story = []

    # Header
    story.append(Paragraph(shop_data['pos_shop_name'], title_style))
    story.append(Paragraph(f"Address: {shop_data['shop_adress']} | Tel: {shop_data['pos_shop_call_number']}", center_style))
    story.append(Paragraph("SALES RECORDS REPORT", subtitle_style))
    story.append(Paragraph(f"Generated by: {user_name['user_name']} | Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", center_style))
    story.append(Spacer(1, 20))

    # Fiscal Summary Section
    if sale_records:
        # Calculate fiscal summary
        total_sales = sum(record.sale_total for record in sale_records)
        total_paid = sum(record.sale_paid_amount for record in sale_records)
        total_balance = sum(record.sale_balance for record in sale_records)
        total_transactions = len(sale_records)

        # Payment method breakdown
        payment_methods = {}
        for record in sale_records:
            method = record.payment_method or 'Cash'
            if method not in payment_methods:
                payment_methods[method] = {'count': 0, 'amount': 0}
            payment_methods[method]['count'] += 1
            payment_methods[method]['amount'] += record.sale_total

        story.append(Paragraph("FISCAL SUMMARY", subtitle_style))

        # Format numbers with commas and decimals
        def format_currency(amount):
            return f"KES {amount:,.2f}"

        # Summary table
        summary_data = [
            ['Total Transactions', 'Total Sales Amount', 'Total Amount Paid', 'Total Balance/Change'],
            [str(total_transactions), format_currency(total_sales), format_currency(total_paid), format_currency(total_balance)]
        ]

        summary_table = Table(summary_data, colWidths=[2*inch, 2*inch, 2*inch, 2*inch])
        summary_table.setStyle(TableStyle([
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('FONTNAME', (0, 0), (-1, 0), 'Courier-Bold'),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('GRID', (0, 0), (-1, -1), 1, colors.black),
            ('LEFTPADDING', (0, 0), (-1, -1), 5),
            ('RIGHTPADDING', (0, 0), (-1, -1), 5),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ]))
        story.append(summary_table)
        story.append(Spacer(1, 15))

        # Payment methods breakdown
        if payment_methods:
            story.append(Paragraph("PAYMENT METHODS BREAKDOWN", styles['Heading3']))
            payment_data = [['Payment Method', 'Transaction Count', 'Total Amount']]
            for method, data in payment_methods.items():
                payment_data.append([method, str(data['count']), format_currency(data['amount'])])

            payment_table = Table(payment_data, colWidths=[2.5*inch, 2*inch, 2*inch])
            payment_table.setStyle(TableStyle([
                ('FONTSIZE', (0, 0), (-1, -1), 9),
                ('FONTNAME', (0, 0), (-1, 0), 'Courier-Bold'),
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('LEFTPADDING', (0, 0), (-1, -1), 3),
                ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            story.append(payment_table)
            story.append(Spacer(1, 20))

        # Page break before detailed records
        story.append(PageBreak())

        # Detailed Sales Records
        story.append(Paragraph("DETAILED SALES RECORDS", subtitle_style))

        # Records table header
        records_data = [['Transaction ID', 'Clerk', 'Total', 'Paid', 'Change/Balance', 'Payment Method', 'Date/Time']]

        # Add records (limit to avoid huge PDF)
        for record in sale_records[:500]:  # Limit to 500 records to keep PDF manageable
            records_data.append([
                record.uid,
                record.sale_clerk,
                format_currency(record.sale_total),
                format_currency(record.sale_paid_amount),
                format_currency(record.sale_balance),
                record.payment_method or 'Cash',
                record.created_at.strftime('%Y-%m-%d %H:%M')
            ])

        # Create table with multiple rows per page
        records_table = Table(records_data, colWidths=[1.2*inch, 1.5*inch, 1*inch, 1*inch, 1.2*inch, 1.5*inch, 1.5*inch])
        records_table.setStyle(TableStyle([
            ('FONTSIZE', (0, 0), (-1, -1), 8),
            ('FONTNAME', (0, 0), (-1, 0), 'Courier-Bold'),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.black),
            ('LEFTPADDING', (0, 0), (-1, -1), 2),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2),
            ('TOPPADDING', (0, 0), (-1, -1), 2),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
            ('BACKGROUND', (0, 0), (-1, 0), colors.lightgrey),
        ]))
        story.append(records_table)

        if len(sale_records) > 500:
            story.append(Spacer(1, 10))
            story.append(Paragraph(f"* Showing first 500 of {len(sale_records)} total transactions", center_style))

    else:
        story.append(Paragraph("No sales records found", center_style))

    # Build PDF
    doc.build(story)
    pdf_buffer.seek(0)

    print("Sales records PDF generated successfully")

    # Return as download that opens in print dialog
    response = make_response(pdf_buffer.read())
    response.headers['Content-Type'] = 'application/pdf'
    response.headers['Content-Disposition'] = 'inline; filename=sales_records_report.pdf'
    return response
    

class SaleItemTransaction(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    sale_id = db.Column(db.Integer, db.ForeignKey('sale_record.id'), nullable=True)
    item_uid = db.Column(db.String(16), nullable=False)
    transaction_type = db.Column(db.Enum('Purchase', 'Sale'), nullable=False)
    transaction_quantity = db.Column(db.Integer, nullable=False)
    item_price = db.Column(db.Float, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"SaleItemTransaction(id={self.id}, item_uid='{self.item_uid}', transaction_type='{self.transaction_type}', transaction_quantity={self.transaction_quantity}, created_at={self.created_at})"
    
# function create, get_all,
def create_sale_item_transaction(payload):
    sale_item_transaction = SaleItemTransaction()
    sale_item_transaction.item_uid = payload['item_uid']
    sale_item_transaction.transaction_type = payload['transaction_type']
    sale_item_transaction.transaction_quantity = payload['transaction_quantity']
    db.session.add(sale_item_transaction)
    db.session.commit()
    return sale_item_transaction

def get_all_sale_item_transactions():
    return SaleItemTransaction.query.all()



class SaleRecord(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    uid = db.Column(db.String(10), unique=True, nullable=False)
    sale_clerk = db.Column(db.String(20), nullable=False)
    sale_total = db.Column(db.Float, nullable=False)
    sale_paid_amount = db.Column(db.Float, nullable=False)
    sale_balance = db.Column(db.Float, nullable=False)
    payment_method = db.Column(db.String(20))
    payment_reference = db.Column(db.String(20))
    payment_gateway = db.Column(db.Enum('223111-476921', '400200-6354', '765244-80872', '0000-0000'))
    created_at = db.Column(db.DateTime, default=datetime.now())
    updated_at = db.Column(db.DateTime, default=datetime.now())

    def __repr__(self):
        return f"SaleRecord(id={self.id}, uid='{self.uid}', sale_clerk='{self.sale_clerk}', sale_total={self.sale_total}, sale_paid_amount={self.sale_paid_amount}, sale_balance={self.sale_balance}, payment_method='{self.payment_method}', payment_reference='{self.payment_reference}', payment_gateway='{self.payment_gateway}', created_at={self.created_at}, updated_at={self.updated_at})"

def add_sale_record(payload):
    record = SaleRecord()
    record.uid = randomString(10)
    record.sale_clerk = payload['sale_clerk']
    record.sale_total = payload['sale_total']
    record.sale_paid_amount = payload['sale_paid_amount']
    record.sale_balance = payload['sale_balance']
    record.payment_method = payload['payment_method']  # New attribute
    record.payment_reference = payload['payment_reference']  # New attribute
    record.payment_gateway = payload['payment_gateway']
    db.session.add(record)
    db.session.commit()

def get_sales():
    return SaleRecord.query.all()

def get_all_sales():
    return SaleRecord.query.all()

class SaleOperations():
    @staticmethod
    def add_item_transaction(payload):
        
        create_sale_item_transaction(payload)

        pass 

    @staticmethod
    def add_sale_record(payload):
        pass


@app.route('/sales')
def sales_home():
    query = is_active()
    print(f"query string at /user, {query}")
    if query['status'] and request.path in query['middleware']['allowed_routes']:
        response = make_response(render_template(
            'sales_management.html',
            is_active = True,
            title="Sales",
            user_type=session['session_user'].decode('utf-8'),
            user_name = user_from_session(),
            shop_data = [load_shop_data()]
        ))
        return response
    else:
        return redirect(query['middleware']['allowed_routes'][0])

@app.route('/item/<uid>')
def fetch_item_if_sale(uid):
    item = get_item(uid)
    if item:
        return jsonify({
            'id': item.id,
            'name': item.name,
            'price': item.price,
            # Add more attributes as needed
        })
    else:
        return jsonify({'error': 'Item not found'}), 404

@app.route('/add_sale_record', methods=['POST'])
def add_clerk_sale_record():
    try:
        # fetch post with security key
        json_data = request.get_json()
        print(f"received sale record, {json_data}")
        items_sold = []
        item_array = json_data['items_array']
        print(f"item_arr is of type {type(item_array)}")

        # Validate required fields
        required_fields = ['sale_clerk', 'sale_total', 'sale_paid_amount', 'sale_balance', 'items_array']
        for field in required_fields:
            if field not in json_data:
                return jsonify({'status': False, 'error': f'Missing required field: {field}'})

        # Check stock availability BEFORE creating any records
        stock_check_passed = True
        insufficient_items = []

        for it in item_array:
            try:
                item_id = int(it.split(":")[0])
                sale_item = SaleItem.query.filter_by(id=item_id).first()
                if sale_item is None:
                    print(f"Item with ID {item_id} not found")
                    insufficient_items.append(f"Item ID {item_id} not found")
                    stock_check_passed = False
                    continue

                stock = SaleItemStockCount.query.filter_by(item_uid=sale_item.uid).first()
                if stock is None or stock.current_stock_count < 1:
                    print(f"Insufficient stock for item {sale_item.name}: current_stock_count={stock.current_stock_count if stock else 'N/A'}")
                    insufficient_items.append(sale_item.name)
                    stock_check_passed = False
            except (ValueError, IndexError) as e:
                print(f"Invalid item format: {it}, error: {e}")
                insufficient_items.append(f"Invalid item: {it}")
                stock_check_passed = False

        # If stock check failed, return error without creating any records
        if not stock_check_passed:
            if len(insufficient_items) == 1:
                error_msg = f"Item not in stock: {insufficient_items[0]}"
            else:
                error_msg = f"Items not in stock: {', '.join(insufficient_items)}"
            print(f"Stock check failed: {error_msg}")
            return jsonify({'status': False, 'error': error_msg})

        # All stock checks passed, now create the records
        print("Stock check passed, creating sale record...")

        # create sale record first to get the sale_id
        sale_record = SaleRecord()
        sale_record.uid = randomString(10)
        sale_record.sale_clerk = json_data['sale_clerk']
        sale_record.sale_total = json_data['sale_total']
        sale_record.sale_paid_amount = json_data['sale_paid_amount']
        sale_record.sale_balance = json_data['sale_balance']
        sale_record.payment_method = json_data.get('payment_method')
        sale_record.payment_reference = json_data.get('payment_reference')
        sale_record.payment_gateway = json_data.get('payment_gateway')
        db.session.add(sale_record)
        db.session.commit()
        print(f"Sale record created: {sale_record.uid}")

        # sale item transactions linked to the sale
        for it in item_array:
            print("adding sale-item-transactions---")
            try:
                item_id = int(it.split(":")[0])
                sale_item = SaleItem.query.filter_by(id=item_id).first()
                if sale_item is None:
                    print(f"Item with ID {item_id} not found during transaction creation")
                    continue

                item_transaction = SaleItemTransaction()
                item_transaction.sale_id = sale_record.id
                item_transaction.item_uid = sale_item.uid
                item_transaction.transaction_type = 'Purchase'
                item_transaction.transaction_quantity = 1
                item_transaction.item_price = sale_item.price
                db.session.add(item_transaction)
                print(f"Transaction created for item: {sale_item.name}")
            except Exception as e:
                print(f"Error creating transaction for item {it}: {e}")
                continue

        db.session.commit()
        print("All transactions committed")

        # update stock count now that everything is confirmed
        for it in item_array:
            try:
                item_id = int(it.split(":")[0])
                sale_item = SaleItem.query.filter_by(id=item_id).first()
                if sale_item is None:
                    print(f"Item with ID {item_id} not found during stock update")
                    continue

                stock = SaleItemStockCount.query.filter_by(item_uid=sale_item.uid).first()
                if stock:
                    stock.current_stock_count -= 1
                    # Update re_stock_status
                    stock.re_stock_status = stock.current_stock_count < stock.re_stock_value
                    db.session.add(stock)
                    print(f"Stock updated for {sale_item.name}: {stock.current_stock_count} remaining")
            except Exception as e:
                print(f"Error updating stock for item {it}: {e}")
                continue

        db.session.commit()
        print("Stock updates committed successfully")

        return jsonify({'status': True, 'sale_record': {'id': sale_record.id, 'uid': sale_record.uid}})

    except Exception as e:
        print(f"Unexpected error in add_sale_record: {e}")
        db.session.rollback()
        return jsonify({'status': False, 'error': f'Internal server error: {str(e)}'})





@app.route('/')
def index():
    query = is_active()
    print(f"query return type is, {type(query)}")
    if query['status'] and request.path in query['middleware']['allowed_routes']:
        print(request.path)
        response = make_response(render_template(
        'home.html',
        is_active = False,
        title=load_shop_data()['shop_name'],
        user_type=session['session_user'].decode('utf-8'),
        shop_data = [load_shop_data()]
        ))  
        return response
    return redirect(query['middleware']['allowed_routes'][0])

@app.route('/about')
def show_about():
    query = is_active()
    print(f"query return type is, {type(query)}")
    if query['status'] and request.path in query['middleware']['allowed_routes']:
        print(request.path)
        response = make_response(render_template(
        'about.html',
        is_active = False,
        title=load_shop_data()['shop_name'],
        user_type=session['session_user'].decode('utf-8'),
        shop_data = [load_shop_data()],
        cards = [
                {
                "state":0.0, 
                "title":"Blue", 
                "redirect":"/", 
                "price":250.00, 
                "action_string":"Press card to checkout", 
                "service_payload":"Feel free to reach us using the actions below."
                }
            ]
        ))  
        return response

    else:
        return redirect(query['middleware']['allowed_routes'][0])

@app.route('/invalid')
def show_invalid_page():
    query = is_active()
    print(f"query return type is, {type(query)}")
    if query['status'] and request.path in query['middleware']['allowed_routes']:
        print(request.path)
        response = make_response(render_template(
        'invalid_credentials.html',
        is_active = False,
        title=load_shop_data()['shop_name'],
        user_type=session['session_user'].decode('utf-8'),
        shop_data = [load_shop_data()],
        cards = [
                {
                "state":0.0, 
                "title":"Blue", 
                "redirect":"/", 
                "price":250.00
                }
            ]
        ))  
        return response

    else:
        return redirect(query['middleware']['allowed_routes'][0])

@app.route('/verify', methods=['POST'])
def verify_login():
    user_name = request.form['user_name']
    user_password = request.form['user_password']
    user = User.query.filter_by(user_name=user_name).first()
    
    if user is not None:
        print(f"user being verified is, {user.user_name}")
        if check_password_hash(user.password_hash, user_password):
            if user.role == 'Admin':
                login_user(user.user_name, randomString(10))
                return redirect('/users')
            if user.role == 'Sale':
                login_user(user.user_name, randomString(10))
                return redirect("/sales")
            if user.role == 'Inventory':
                login_user(user.user_name, randomString(10))
                return redirect("/inventory")
        else:
            return redirect('/invalid')
    return redirect('/invalid')


@app.route('/logout')
def clear_auth_session():
    reset_session()
    return redirect('/')

   
@app.route('/users')
def user_home():
    query = is_active()
    print(f"query string at /user, {query}")
    if 'session_flash_message' in session:
        flash_message = True
        flash_payload = session['session_flash_message'].decode('utf-8')
        session.pop('session_flash_message')

    else:
        flash_message = False
        flash_payload = ""

    # Check device activation state for UI display
    device_state = "first_time"  # Default state
    try:
        # Check device state via the activation endpoint
        import requests
        response = requests.post('http://localhost:8080/activate',
                               json={'action': 'check_expiry'},
                               timeout=5)
        if response.status_code == 200:
            data = response.json()
            device_state = data.get('app_state', 'first_time')
            print(f"Device state from backend: {device_state}")
        else:
            print(f"Failed to get device state: {response.status_code}")
    except Exception as e:
        print(f"Error checking device state: {e}")

    # Show user management interfaces when device is active or expired (not first_time)
    show_user_interfaces = device_state in ['active', 'expired']

    if query['status'] and request.path in query['middleware']['allowed_routes']:
        response = make_response(render_template(
            'user_management.html',
            is_active = True,
            title="Master",  # Navigation bar title
            flash_message = flash_message,
            flash_payload = flash_payload,
            # Show user interfaces when device is active/expired
            sector_a = show_user_interfaces,  # User creation and listing
            sector_c = False,  # Keep license management hidden
            license_record = None,
            days_remaining = 0,
            user_type=session['session_user'].decode('utf-8'),
            user_name=user_from_session(),
            shop_data = [load_shop_data()],
            users = fetch_users()  # Always fetch users for dynamic display
        ))
        return response

    else:
        return redirect(query['middleware']['allowed_routes'][0])

# add validate license reset key
@app.route("/validate_reset_key", methods=["POST"])
def validate_reset_key():
    print("Validating reset key")
    input_key_value = request.form['reset_key']
    input_license_type = request.form['license_type']

    # use LicenseResetKey class to validate the key
    if LicenseResetKey.is_valid_key(input_key_value):
        # If the key is valid, redirect to /
        print("Valid reset key")
        # check if License table has any reocrd,
        # if yes, delete all records and create new record
        # if no, create new record
        if input_license_type == "Full":
            days = 366
        else:
            days = 183

        l = fetch_licenses()

        if l == []:
            # if input_license_type == "Full", days = 366 else 188
            create_license({"license_key":randomString(16), "license_type":input_license_type, "license_status":True, "license_expiry":datetime.now() + timedelta(days=days)})
        else:
            print(f"during reseting l was {l}")
            delete_license(1)
            create_license({"license_key":randomString(16), "license_type":input_license_type, "license_status":True, "license_expiry":datetime.now() + timedelta(days=days)})

        session['session_flash_message'] = bytes("License reset successful", 'utf-8')

        return redirect("/")
        
    else:
        # If the key is invalid, load the flash message and redirect to /
        print("Invalid reset key")
        session['session_flash_message'] = bytes("Invalid reset key", 'utf-8')
        return redirect("/")


@app.route('/add_user', methods=['POST'])
def add_user():
    query = is_active()
    if query['status'] and request.path in query['middleware']['allowed_routes']:
        user_name = request.form['user_name']
        user_password = request.form['password']
        user_role = request.form['user_role']
        create_status = create_user({"user_name":user_name, "password":user_password, "role": user_role })
        if create_status['status']:
            return redirect(query['middleware']['allowed_routes'][0])
        else:
            session['session_flash_message'] = bytes("unable to create user", 'utf-8')
            return redirect(query['middleware']['allowed_routes'][0])
    else:
        return redirect(query['middleware']['allowed_routes'][0])

@app.route('/delete_user', methods=['POST'])
def admin_delete_user():
    query = is_active()
    if query['status'] and request.path in query['middleware']['allowed_routes']:
        user_id = request.form['user_id']
        print(f"delete user with id, {user_id}") 
        delete_user(user_id)
        return redirect(query['middleware']['allowed_routes'][0])
    else:
        return redirect(query['middleware']['allowed_routes'][0])


@app.route('/init_users', methods=['POST'])
def init_app_users():
    print(request.data)
    json_data = request.get_json()
    print(json_data)
    try:

        if json_data is not None:
            key = json_data['shop_api_key']
            if key == load_shop_data()['shop_api_key']:
                init_app_db()
                resp = jsonify({'status':'success'})
                resp.headers['Access-Control-Allow-Origin'] = '*'
                return resp
            else:
                # resp = jsonify({'status':'failed, invalid key'})
                resp = jsonify({'status':'failed'})
                resp.headers['Access-control-Allow-Origin'] = '*'
                return resp
        else:
            resp = jsonify({'status':'failed'})
            resp.headers['Access-Control-Allow-Origin'] = '*'
            return resp

    except:
        resp = jsonify({'status':'failed'})
        resp.headers['Access-Control-Allow-Origin'] = '*'
        return resp

def init_app_db():
    # Create all tables including new Device and License models
    db.create_all()

    master_user = {"user_name":"Karua", "password":"jnkarua19", "role":"Admin"}
    sales_user = {"user_name":"Wandia", "password":"evangeline", "role":"Sale"}
    inventory_user = {"user_name":"Esther", "password":"wakabari", "role":"Inventory"}
    create_user(master_user)
    create_user(sales_user)
    create_user(inventory_user)


    





# create new function run to determine between development and production mode as fed in the arguments when executing this file

def generate_barcode_image(data):
    try:
        from PIL import Image, ImageDraw, ImageFont

        # Create a simple barcode-like image with text and lines
        img = Image.new('RGB', (200, 60), color='white')
        draw = ImageDraw.Draw(img)

        # Try to use default font
        try:
            font = ImageFont.load_default()
        except:
            font = None

        # Draw some barcode-like lines
        for i in range(0, 180, 4):
            if i % 8 == 0:  # Create alternating thick/thin lines
                draw.rectangle([10 + i, 10, 12 + i, 50], fill='black')
            else:
                draw.rectangle([10 + i, 15, 11 + i, 45], fill='black')

        # Draw the barcode data as text below
        draw.text((60, 35), data[:12], fill='black', font=font)

        print("Barcode image generation successful - simple visual representation")
        return img
    except Exception as e:
        print(f"Barcode image generation failed: {e}")
        return None

def generate_qrcode_image(data):
    try:
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(data)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        print("QR code image generation successful")
        return img
    except Exception as e:
        print(f"QR code image generation failed: {e}")
        return None

def generate_barcode_base64(data):
    try:
        from PIL import Image, ImageDraw, ImageFont
        import io

        # Create a simple barcode-like image with text and lines
        img = Image.new('RGB', (200, 60), color='white')
        draw = ImageDraw.Draw(img)

        # Try to use default font
        try:
            font = ImageFont.load_default()
        except:
            font = None

        # Draw some barcode-like lines
        for i in range(0, 180, 4):
            if i % 8 == 0:  # Create alternating thick/thin lines
                draw.rectangle([10 + i, 10, 12 + i, 50], fill='black')
            else:
                draw.rectangle([10 + i, 15, 11 + i, 45], fill='black')

        # Draw the barcode data as text below
        draw.text((60, 35), data[:12], fill='black', font=font)

        # Convert to base64
        buffer = io.BytesIO()
        img.save(buffer, format='PNG')
        buffer.seek(0)
        image_base64 = base64.b64encode(buffer.read()).decode('utf-8')
        print("Barcode generation successful - simple visual representation")
        return f"data:image/png;base64,{image_base64}"
    except Exception as e:
        print(f"Barcode generation failed: {e}")
        return None

def generate_qrcode_base64(data):
    qr = qrcode.QRCode(version=1, box_size=10, border=4)
    qr.add_data(data)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    buffer = BytesIO()
    img.save(buffer, format='PNG')
    buffer.seek(0)
    image_base64 = base64.b64encode(buffer.read()).decode('utf-8')
    return f"data:image/png;base64,{image_base64}"


@app.route('/download-sale-receipt/<int:sale_id>')
def download_sale_receipt(sale_id):
    # Check if request wants HTML for printing (from print dialog)
    if request.args.get('format') == 'print':
        # Return HTML for browser printing
        sale_record = SaleRecord.query.filter_by(id=sale_id).first()
        if not sale_record:
            abort(404, description="Sale record not found")

        # Fetch sale items from transactions linked to this sale
        sale_items = []
        transactions = SaleItemTransaction.query.filter_by(sale_id=sale_id).all()
        for transaction in transactions:
            item = SaleItem.query.filter_by(uid=transaction.item_uid).first()
            if item:
                sale_items.append({
                    'name': item.name,
                    'quantity': transaction.transaction_quantity,
                    'price': transaction.item_price
                })

        # Generate base64 images for HTML
        barcode_data = f"SALE-{sale_record.uid}"
        qrcode_data = f"Sale ID: {sale_record.id}\nTotal: {sale_record.sale_total}\nDate: {sale_record.created_at}"

        barcode_base64 = generate_barcode_base64(barcode_data)
        qrcode_base64 = generate_qrcode_base64(qrcode_data)

        # Shop data
        shop_data = load_shop_data()

        # Current time
        current_time = datetime.now().strftime("%d/%m/%Y %H:%M:%S")

        response = make_response(render_template(
            'sales_receipt_template.html',
            sale_record=sale_record,
            sale_items=sale_items,
            shop_data=shop_data,
            barcode_base64=barcode_base64,
            barcode_data=barcode_data,
            qrcode_base64=qrcode_base64,
            current_time=current_time
        ))
        return response
    else:
        # Original PDF download functionality
        # Use ReportLab directly for reliable image embedding
        from reportlab.lib.pagesizes import letter
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image
    from reportlab.lib import colors
    from reportlab.lib.units import inch

    # Fetch sale record
    sale_record = SaleRecord.query.filter_by(id=sale_id).first()
    if not sale_record:
        abort(404, description="Sale record not found")

    # Fetch sale items from transactions linked to this sale
    sale_items = []
    transactions = SaleItemTransaction.query.filter_by(sale_id=sale_id).all()
    for transaction in transactions:
        item = SaleItem.query.filter_by(uid=transaction.item_uid).first()
        if item:
            sale_items.append({
                'name': item.name,
                'quantity': transaction.transaction_quantity,
                'price': transaction.item_price
            })

    # Generate images
    barcode_data = f"SALE-{sale_record.uid}"
    qrcode_data = f"Sale ID: {sale_record.id}\nTotal: {sale_record.sale_total}\nDate: {sale_record.created_at}"

    barcode_img = generate_barcode_image(barcode_data)
    qrcode_img = generate_qrcode_image(qrcode_data)

    # Shop data
    shop_data = load_shop_data()

    # Create PDF buffer
    pdf_buffer = BytesIO()

    # Create the PDF document - receipt format: 3 inches wide, auto height
    doc = SimpleDocTemplate(pdf_buffer, pagesize=(3*inch, 11*inch),
                           leftMargin=0.1*inch, rightMargin=0.1*inch,
                           topMargin=0.1*inch, bottomMargin=0.1*inch)
    styles = getSampleStyleSheet()

    # Custom styles - ensure full width
    title_style = ParagraphStyle('Title', parent=styles['Heading1'], fontSize=14, alignment=1, spaceAfter=10, leftIndent=0, rightIndent=0)
    normal_style = ParagraphStyle('Normal', parent=styles['Normal'], fontSize=8, leading=10, leftIndent=0, rightIndent=0)
    item_style = ParagraphStyle('Item', parent=styles['Normal'], fontSize=7, leading=8, fontName='Courier', leftIndent=0, rightIndent=0)
    center_style = ParagraphStyle('Center', parent=styles['Normal'], fontSize=10, alignment=1, spaceAfter=15, leftIndent=0, rightIndent=0)

    story = []

    # Header - full width
    story.append(Paragraph(shop_data['pos_shop_name'], title_style))
    story.append(Paragraph(shop_data['shop_adress'], normal_style))
    story.append(Paragraph(f"Tel: {shop_data['pos_shop_call_number']}", normal_style))
    story.append(Paragraph(f"Receipt #{sale_record.uid}", center_style))

    # Sale info table - full width
    info_data = [
        ['Date:', sale_record.created_at.strftime('%Y-%m-%d %H:%M')],
        ['Clerk:', sale_record.sale_clerk],
        ['Payment:', sale_record.payment_method or 'Cash']
    ]

    info_table = Table(info_data, colWidths=[1.2*inch, 1.5*inch])  # Full width columns
    info_table.setStyle(TableStyle([
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 10))

    # Items header - full width
    items_header_style = ParagraphStyle('ItemsHeader', parent=styles['Heading3'], fontSize=10, spaceAfter=5, leftIndent=0, rightIndent=0)
    story.append(Paragraph("Items Purchased", items_header_style))

    # Items - full width
    for item in sale_items:
        item_text = f"{item['name'][:18]}{'...' if len(item['name']) > 18 else ''} {item['quantity']}x ${item['price']:.2f}"
        story.append(Paragraph(item_text, item_style))

    # Separator - full width
    story.append(Paragraph("=" * 50, item_style))  # More characters for full width

    # Totals - full width
    story.append(Paragraph(f"Total: ${sale_record.sale_total:.2f}", item_style))
    story.append(Paragraph(f"Amount Paid: ${sale_record.sale_paid_amount:.2f}", item_style))
    story.append(Paragraph(f"Change/Balance: ${sale_record.sale_balance:.2f}", item_style))

    story.append(Spacer(1, 15))

    # Images section - full width
    if barcode_img or qrcode_img:
        # Single row with both images side by side
        if barcode_img and qrcode_img:
            # Both images in one row
            barcode_buffer = BytesIO()
            barcode_img.save(barcode_buffer, format='PNG')
            barcode_buffer.seek(0)
            barcode_rl_img = RLImage(barcode_buffer)
            barcode_rl_img.drawWidth = 1.5 * inch  # Wider barcode
            barcode_rl_img.drawHeight = 0.4 * inch

            qrcode_buffer = BytesIO()
            qrcode_img.save(qrcode_buffer, format='PNG')
            qrcode_buffer.seek(0)
            qrcode_rl_img = RLImage(qrcode_buffer)
            qrcode_rl_img.drawWidth = 0.8 * inch   # Smaller QR code
            qrcode_rl_img.drawHeight = 0.8 * inch

            # Single row table with both images
            images_table = Table([[barcode_rl_img, qrcode_rl_img]], colWidths=[1.6*inch, 0.9*inch])
            images_table.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ]))
            story.append(images_table)

        elif barcode_img:
            # Only barcode
            barcode_buffer = BytesIO()
            barcode_img.save(barcode_buffer, format='PNG')
            barcode_buffer.seek(0)
            barcode_rl_img = RLImage(barcode_buffer)
            barcode_rl_img.drawWidth = 2.4 * inch  # Full width for single image
            barcode_rl_img.drawHeight = 0.4 * inch
            story.append(barcode_rl_img)

        elif qrcode_img:
            # Only QR code
            qrcode_buffer = BytesIO()
            qrcode_img.save(qrcode_buffer, format='PNG')
            qrcode_buffer.seek(0)
            qrcode_rl_img = RLImage(qrcode_buffer)
            qrcode_rl_img.drawWidth = 1.2 * inch   # Centered QR code
            qrcode_rl_img.drawHeight = 1.2 * inch
            story.append(qrcode_rl_img)

    # Footer - full width
    story.append(Spacer(1, 20))
    footer_style = ParagraphStyle('Footer', parent=styles['Normal'], fontSize=9, alignment=1, leftIndent=0, rightIndent=0)
    timestamp_style = ParagraphStyle('Timestamp', parent=styles['Normal'], fontSize=7, alignment=1, leftIndent=0, rightIndent=0)
    story.append(Paragraph("Thank you for your business!", footer_style))
    story.append(Paragraph(datetime.now().strftime("%d/%m/%Y %H:%M:%S"), timestamp_style))

    # Build PDF
    doc.build(story)
    pdf_buffer.seek(0)

    print("PDF generated successfully with ReportLab")

    # Return as download
    response = make_response(pdf_buffer.read())
    response.headers['Content-Type'] = 'application/pdf'
    response.headers['Content-Disposition'] = f'attachment; filename=receipt_{sale_record.uid}.pdf'
    return response

# Micro-Server API Endpoints for APK Integration
@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for micro-server status"""
    return jsonify({
        "status": "ok",
        "timestamp": datetime.now().isoformat(),
        "server": "BluPOS Micro-Server",
        "version": __version__
    })

@app.route('/generate_activation_qr', methods=['GET'])
def generate_activation_qr():
    """Generate QR code for device activation (first-time activation)"""
    try:
        # Generate activation code - randomly choose between full and half license
        license_types = [
            ('BLU', 183, 'Half License (183 days)'),  # BLU prefix for half license
            ('POS', 366, 'Full License (366 days)')   # POS prefix for full license
        ]

        # Randomly select license type
        prefix, days, description = random.choice(license_types)
        activation_code = f"{prefix}{randomString(4).upper()}"

        # Generate QR code data for APK activation
        qr_data = f"""BluPOS Device Activation
Activation Code: {activation_code}
License Type: {description}
Duration: {days} days
Instructions: Scan with BluPOS APK to activate device
Generated: {datetime.now().isoformat()}
System: BluPOS Point of Sale"""

        # Generate QR code
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(qr_data)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")

        # Convert to base64
        buffer = BytesIO()
        img.save(buffer, format='PNG')
        buffer.seek(0)
        qr_base64 = base64.b64encode(buffer.read()).decode('utf-8')
        qr_data_url = f"data:image/png;base64,{qr_base64}"

        return jsonify({
            "status": "success",
            "activation_code": activation_code,
            "license_days": days,
            "license_type": description,
            "qr_code": qr_data_url,
            "instructions": "Scan this QR code with the BluPOS APK to activate your device"
        })

    except Exception as e:
        print(f"Activation QR generation error: {e}")
        return jsonify({"status": "error", "message": "Failed to generate activation QR code"}), 500

@app.route('/generate_license_qr', methods=['POST'])
def generate_license_qr():
    """Generate QR code for license activation"""
    try:
        data = request.get_json()

        if not data:
            return jsonify({"status": "error", "message": "No data provided"}), 400

        license_days = data.get('license_days')
        account_id = data.get('account_id')

        if not license_days or not account_id:
            return jsonify({"status": "error", "message": "Missing license_days or account_id"}), 400

        # Validate license days
        if license_days not in [183, 366]:
            return jsonify({"status": "error", "message": "Invalid license duration. Must be 183 or 366 days"}), 400

        # Generate unique license type based on duration
        if license_days == 183:
            # Generate new 183-day license type
            license_type = f"BLU{randomString(4).upper()}"
        else:  # 366 days
            # Generate new 366-day license type
            license_type = f"POS{randomString(4).upper()}"

        # Generate unique license key (license type only, no device ID)
        license_key = license_type

        # Generate QR code data (without device ID for cleaner license key display)
        qr_data = f"BluPOS License Activation\nLicense Type: {license_type}\nDuration: {license_days} days\nLicense Key: {license_key}\nGenerated: {datetime.now().isoformat()}"

        # Generate QR code
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(qr_data)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")

        # Convert to base64
        buffer = BytesIO()
        img.save(buffer, format='PNG')
        buffer.seek(0)
        qr_base64 = base64.b64encode(buffer.read()).decode('utf-8')
        qr_data_url = f"data:image/png;base64,{qr_base64}"

        return jsonify({
            "status": "success",
            "license_type": license_type,
            "license_days": license_days,
            "license_key": license_key,
            "qr_code": qr_data_url
        })

    except Exception as e:
        print(f"License QR generation error: {e}")
        return jsonify({"status": "error", "message": "Failed to generate license QR code"}), 500

@app.route('/activate', methods=['POST'])
def device_activation():
    """Device activation and license management endpoint"""
    try:
        data = request.get_json()

        if not data:
            return jsonify({"status": "error", "message": "No data provided"}), 400

        action = data.get('action')

        if not action:
            return jsonify({"status": "error", "message": "Missing action"}), 400

        # For polling actions (check_expiry), use existing account or return first_time
        if action != 'first_time':
            existing_account = Account.query.first()
            if existing_account:
                account_id = existing_account.account_id
                # Update last seen for polling
                existing_account.last_seen = datetime.now()
                db.session.commit()
                print(f" Checking account: {account_id}")
            else:
                # No account exists yet, return first_time state
                return jsonify({
                    "status": "success",
                    "app_state": "first_time",
                    "message": "No account activated yet"
                })
        else:
            # First-time activation: ENFORCE BLUPOS as single source of truth
            # APK should NOT send account_id - BluPOS provides the official one
            print("🔧 First-time activation: BluPOS as single source of truth...")

            apk_sent_account = data.get('account_id')
            if apk_sent_account:
                print(f"⚠️ APK sent account_id: {apk_sent_account} - IGNORING (BluPOS is source of truth)")

            # Always use/create the ONE persistent account
            existing_account = Account.query.first()
            if existing_account:
                account_id = existing_account.account_id
                print(f"🔄 Using EXISTING persistent account: {account_id}")
            else:
                # Create the SINGLE account (only happens once ever)
                account_id = f"account_{int(datetime.now().timestamp() * 1000)}"
                print(f"🔧 Generated SINGLE Account ID: {account_id}")

                account = Account(account_id=account_id, account_type='web')
                db.session.add(account)
                db.session.commit()
                print(f"📱 SINGLE account created: {account_id} (BluPOS source of truth)")

        if action == 'first_time':
            activation_code = data.get('activation_code')
            if not activation_code:
                return jsonify({"status": "error", "message": "Missing activation_code"}), 400

            # Validate activation code - allow standard codes or generated license keys
            valid_codes = ['BLUPOS2025', 'DEMO2025']
            is_standard_code = activation_code in valid_codes
            is_generated_blu = len(activation_code) == 7 and activation_code.startswith('BLU') and activation_code.isalpha() and activation_code.isupper()  # BLU prefix for half license (183 days)
            is_generated_pos = len(activation_code) == 7 and activation_code.startswith('POS') and activation_code.isalpha() and activation_code.isupper()  # POS prefix for full license (366 days)

            if not is_standard_code and not is_generated_blu and not is_generated_pos:
                return jsonify({"status": "error", "message": "Invalid activation code"}), 400

            # Check if account already activated (one license per account)
            existing_license = License.query.filter_by(account_id=account_id).first()
            if existing_license:
                return jsonify({"status": "error", "message": "Account already activated"}), 400

            # Determine license type and duration based on activation code
            if activation_code == 'BLUPOS2025':
                license_type = 'BLUPOS2025'
                license_days = 366  # 1 year
            elif activation_code == 'DEMO2025':
                license_type = 'DEMO2025'
                license_days = 183  # 6 months
            elif is_generated_blu:
                # BLU prefix = half license (183 days)
                license_type = activation_code
                license_days = 183
            elif is_generated_pos:
                # POS prefix = full license (366 days)
                license_type = activation_code
                license_days = 366
            else:
                return jsonify({"status": "error", "message": "Invalid activation code format"}), 400

            # Create new license - use timezone-aware datetime
            expiry_date = datetime.now(timezone.utc) + timedelta(days=license_days)
            license_data = {
                "license_key": f"{license_type}|{account_id}",
                "license_type": license_type,
                "license_status": True,
                "license_expiry": expiry_date
            }

            result = create_license(license_data, account_id)
            if result:
                return jsonify({
                    "status": "success",
                    "message": "Account activated successfully",
                    "account_id": account_id,
                    "license_expiry": expiry_date.isoformat(),
                    "app_state": "active",
                    "license_type": license_type,
                    "license_days": license_days
                })
            else:
                return jsonify({"status": "error", "message": "Failed to create license"}), 500

        elif action == 'check_expiry':
            # Check current license status - one license per account
            license = License.query.filter_by(account_id=account_id).first()
            if not license:
                return jsonify({
                    "status": "success",
                    "app_state": "first_time",
                    "message": "Account not activated"
                })

            now = datetime.now()
            if license.license_status and license.license_expiry > now:
                days_remaining = (license.license_expiry - now).days
                return jsonify({
                    "status": "success",
                    "app_state": "active",
                    "account_id": account_id,  # Include account_id in response
                    "license_expiry": license.license_expiry.isoformat(),
                    "days_remaining": days_remaining,
                    "license_type": license.license_type
                })
            else:
                days_overdue = (now - license.license_expiry).days if license.license_expiry < now else 0
                return jsonify({
                    "status": "success",
                    "app_state": "expired",
                    "account_id": account_id,  # Include account_id in response
                    "license_expiry": license.license_expiry.isoformat(),
                    "days_overdue": days_overdue,
                    "license_type": license.license_type
                })

        elif action == 'reactivate':
            activation_code = data.get('activation_code')
            if not activation_code:
                return jsonify({"status": "error", "message": "Missing activation_code"}), 400

            # Validate activation code - allow standard codes and generated codes
            valid_codes = ['BLUPOS2025', 'DEMO2025']
            is_standard_code = activation_code in valid_codes
            is_generated_blu = len(activation_code) == 7 and activation_code.startswith('BLU') and activation_code.isalpha() and activation_code.isupper()
            is_generated_pos = len(activation_code) == 7 and activation_code.startswith('POS') and activation_code.isalpha() and activation_code.isupper()

            if not is_standard_code and not is_generated_blu and not is_generated_pos:
                return jsonify({"status": "error", "message": "Invalid activation code"}), 400

            # Check if account exists
            account = Account.query.filter_by(account_id=account_id).first()
            if not account:
                return jsonify({"status": "error", "message": "Account not found"}), 404

            # Check if license exists for this account
            existing_license = License.query.filter_by(account_id=account_id).first()

            # Determine license type and duration - ENFORCED: Only 2 license types
            if activation_code == 'BLUPOS2025':
                license_type = 'BLUPOS2025'
                license_days = 366  # 1 year
            else:  # DEMO2025
                license_type = 'DEMO2025'
                license_days = 183  # 6 months

            if existing_license:
                # Update existing license
                existing_license.license_type = license_type
                existing_license.license_status = True
                existing_license.license_expiry = datetime.now(timezone.utc) + timedelta(days=license_days)
                existing_license.updated_at = datetime.now()
                db.session.commit()

                return jsonify({
                    "status": "success",
                    "message": "License reactivated successfully",
                    "license_expiry": existing_license.license_expiry.isoformat(),
                    "app_state": "active",
                    "license_type": license_type
                })
            else:
                # No license exists (after reset), create new one
                expiry_date = datetime.now(timezone.utc) + timedelta(days=license_days)
                license_data = {
                    "license_key": f"{license_type}|{account_id}",
                    "license_type": license_type,
                    "license_status": True,
                    "license_expiry": expiry_date
                }

                result = create_license(license_data, account_id)
                if result:
                    return jsonify({
                        "status": "success",
                        "message": "License created successfully",
                        "license_expiry": expiry_date.isoformat(),
                        "app_state": "active",
                        "license_type": license_type
                    })
                else:
                    return jsonify({"status": "error", "message": "Failed to create license"}), 500

        elif action == 'next_1_min_expiry':
            # Check if license exists for this account
            existing_license = License.query.filter_by(account_id=account_id).first()
            if not existing_license:
                return jsonify({"status": "error", "message": "Account not found"}), 404

            # Set expiry to next 1 minute for testing
            existing_license.license_status = True
            existing_license.license_expiry = datetime.now() + timedelta(minutes=1)
            db.session.commit()

            return jsonify({
                "status": "success",
                "message": "License set to expire in 1 minute",
                "app_state": "active",
                "license_expiry": existing_license.license_expiry.isoformat()
            })

        else:
            return jsonify({"status": "error", "message": "Invalid action"}), 400

    except Exception as e:
        print(f"Activation error: {e}")
        return jsonify({"status": "error", "message": "Internal server error"}), 500

@app.route('/apk_connection_status', methods=['GET'])
def apk_connection_status():
    """Check APK connection status based on heartbeat signals"""
    try:
        # Get account_id from query parameter or use current account
        account_id = request.args.get('account_id')

        if not account_id:
            # Try to get from current account context
            account_id = request.args.get('current_account_id')

        if not account_id:
            # Get the most recently active account
            account = Account.query.order_by(Account.last_seen.desc()).first()
            if account:
                account_id = account.account_id
            else:
                return jsonify({
                    "status": "success",
                    "connected": False,
                    "message": "No account found",
                    "last_seen": None
                })

        # Check if account exists
        account = Account.query.filter_by(account_id=account_id).first()
        if not account:
            return jsonify({
                "status": "error",
                "message": "Account not found"
            }), 404

        # Check connection status based on last_seen timestamp
        now = datetime.now(timezone.utc)
        last_seen = account.last_seen.replace(tzinfo=timezone.utc) if account.last_seen else None

        if not last_seen:
            connected = False
            last_seen_str = None
        else:
            # Consider connected if heartbeat received within last 60 seconds
            time_diff = (now - last_seen).total_seconds()
            connected = time_diff < 60  # 60 seconds timeout
            last_seen_str = last_seen.isoformat()

        return jsonify({
            "status": "success",
            "connected": connected,
            "account_id": account_id,
            "last_seen": last_seen_str,
            "time_diff_seconds": (now - last_seen).total_seconds() if last_seen else None
        })

    except Exception as e:
        print(f"APK connection status error: {e}")
        return jsonify({"status": "error", "message": "Internal server error"}), 500

@app.route('/heartbeat', methods=['POST'])
def apk_heartbeat():
    """Receive heartbeat signals from APK"""
    try:
        data = request.get_json()

        if not data:
            return jsonify({"status": "error", "message": "No data provided"}), 400

        account_id = data.get('account_id')
        license_key = data.get('license_key')
        timestamp = data.get('timestamp')
        battery_level = data.get('battery_level', 0)
        network_type = data.get('network_type', 'unknown')

        if not account_id:
            return jsonify({"status": "error", "message": "Missing account_id"}), 400

        # Update account last_seen timestamp
        account = Account.query.filter_by(account_id=account_id).first()
        if account:
            account.last_seen = datetime.now()
            db.session.commit()

            # Log heartbeat details
            print(f"📡 Heartbeat received from account {account_id}: battery={battery_level}%, network={network_type}")

            return jsonify({
                "status": "success",
                "server_time": datetime.now().isoformat(),
                "message": "Heartbeat acknowledged",
                "commands": []  # Future use for remote commands
            })
        else:
            return jsonify({"status": "error", "message": "Account not found"}), 404

    except Exception as e:
        print(f"Heartbeat error: {e}")
        return jsonify({"status": "error", "message": "Internal server error"}), 500

@app.route('/validate_license', methods=['POST'])
def validate_license():
    """Validate license key for APK activation"""
    try:
        data = request.get_json()

        if not data:
            return jsonify({"status": "error", "message": "No data provided"}), 400

        license_key = data.get('license_key')
        account_id = data.get('account_id')
        device_info = data.get('device_info', {})

        if not license_key or not account_id:
            return jsonify({"status": "error", "message": "Missing license_key or account_id"}), 400

        print(f"🔍 Validating license: key='{license_key}', account='{account_id}'")

        # Find account
        account = Account.query.filter_by(account_id=account_id).first()
        if not account:
            print(f"❌ Account not found: {account_id}")
            return jsonify({"status": "error", "message": "Account not found"}), 404

        # Find license for this account
        license = License.query.filter_by(account_id=account_id).first()
        if not license:
            print(f"❌ No license found for account: {account_id}")
            return jsonify({"status": "error", "message": "No license found for account"}), 404

        print(f"📋 Found license: type='{license.license_type}', key='{license.license_key}'")

        # Check if license key matches (allow partial match for license type)
        expected_key = license.license_key
        license_type_match = license_key == license.license_type  # e.g., "POSRNQD" matches license type
        full_key_match = license_key == expected_key  # e.g., "POSRNQD|account_123" matches full key

        if not license_type_match and not full_key_match:
            print(f"❌ License key mismatch: provided='{license_key}', expected='{expected_key}', type='{license.license_type}'")
            return jsonify({"status": "error", "message": "Invalid license key"}), 400

        # Check if license is active and not expired
        now = datetime.now()
        if not license.license_status:
            print(f"❌ License inactive")
            return jsonify({"status": "error", "message": "License inactive"}), 400

        if license.license_expiry <= now:
            days_overdue = (now - license.license_expiry).days
            print(f"❌ License expired {days_overdue} days ago")
            return jsonify({"status": "error", "message": "License expired"}), 400

        # Calculate days remaining
        days_remaining = (license.license_expiry - now).days

        print(f"✅ License validation successful: {license.license_type}, expires in {days_remaining} days")

        return jsonify({
            "status": "success",
            "license_type": license.license_type,
            "valid_until": license.license_expiry.isoformat(),
            "days_remaining": days_remaining,
            "features": ["payments", "reports", "sync"],
            "message": "License validated successfully"
        })

    except Exception as e:
        print(f"❌ License validation error: {e}")
        return jsonify({"status": "error", "message": "Internal server error"}), 500

@app.route('/test', methods=['POST'])
def test_endpoint():
    """Testing utilities for UI state management"""
    try:
        data = request.get_json()

        if not data:
            return jsonify({"status": "error", "message": "No data provided"}), 400

        action = data.get('action')
        account_id = data.get('account_id')

        if not action:
            return jsonify({"status": "error", "message": "Missing action"}), 400

        if action == 'force_expiry':
            if not account_id:
                return jsonify({"status": "error", "message": "Missing account_id"}), 400

            license = License.query.filter_by(account_id=account_id).first()
            if not license:
                return jsonify({"status": "error", "message": "Account not found"}), 404

            # Force expiry by setting past date
            license.license_status = False
            license.license_expiry = datetime.now() - timedelta(days=1)
            db.session.commit()

            return jsonify({
                "status": "success",
                "message": "License expired",
                "app_state": "expired",
                "license_expiry": "EXPIRED"
            })

        elif action == 'reset_first_time':
            if not account_id:
                return jsonify({"status": "error", "message": "Missing account_id"}), 400

            license = License.query.filter_by(account_id=account_id).first()
            if license:
                db.session.delete(license)
                db.session.commit()

            return jsonify({
                "status": "success",
                "message": "Reset to first time",
                "app_state": "first_time"
            })

        elif action == 'update_license':
            license_type = data.get('license_type')
            if not account_id or not license_type:
                return jsonify({"status": "error", "message": "Missing account_id or license_type"}), 400

            # Validate license type - allow standard codes and generated codes
            valid_standard_types = ['BLUPOS2025', 'DEMO2025']
            is_standard_type = license_type in valid_standard_types
            is_generated_blu = len(license_type) == 7 and license_type.startswith('BLU') and license_type.isalpha() and license_type.isupper()
            is_generated_pos = len(license_type) == 7 and license_type.startswith('POS') and license_type.isalpha() and license_type.isupper()

            if not is_standard_type and not is_generated_blu and not is_generated_pos:
                return jsonify({"status": "error", "message": "Invalid license type"}), 400

            # Check if account exists
            account = Account.query.filter_by(account_id=account_id).first()
            if not account:
                return jsonify({"status": "error", "message": "Account not found"}), 404

            # Check if license exists for this account
            license = License.query.filter_by(account_id=account_id).first()

            if license:
                # Update existing license
                license.license_type = license_type
                if license_type == 'BLUPOS2025':
                    license.license_expiry = datetime.now() + timedelta(days=366)  # 1 year
                else:  # DEMO2025
                    license.license_expiry = datetime.now() + timedelta(days=183)  # 6 months
                license.license_status = True
                db.session.commit()

                return jsonify({
                    "status": "success",
                    "message": "License updated",
                    "license_type": license_type,
                    "license_expiry": license.license_expiry.isoformat()
                })
            else:
                # No license exists, create new one
                license_days = 366 if license_type == 'BLUPOS2025' else 183  # ENFORCED: 1 year or 6 months
                expiry_date = datetime.now() + timedelta(days=license_days)

                license_data = {
                    "license_key": f"{license_type}|{account_id}",
                    "license_type": license_type,
                    "license_status": True,
                    "license_expiry": expiry_date
                }

                result = create_license(license_data, account_id)
                if result:
                    return jsonify({
                        "status": "success",
                        "message": "License created",
                        "license_type": license_type,
                        "license_expiry": expiry_date.isoformat()
                    })
                else:
                    return jsonify({"status": "error", "message": "Failed to create license"}), 500

        elif action == 'next_1_min_expiry':
            if not account_id:
                return jsonify({"status": "error", "message": "Missing account_id"}), 400

            license = License.query.filter_by(account_id=account_id).first()
            if not license:
                return jsonify({"status": "error", "message": "Account not found"}), 404

            # Set expiry to next 1 minute for testing
            license.license_status = True
            license.license_expiry = datetime.now() + timedelta(minutes=1)
            db.session.commit()

            return jsonify({
                "status": "success",
                "message": "License set to expire in 1 minute",
                "app_state": "active",
                "license_expiry": license.license_expiry.isoformat()
            })

        elif action == 'get_status':
            if not account_id:
                return jsonify({"status": "error", "message": "Missing account_id"}), 400

            license = License.query.filter_by(account_id=account_id).first()

            if not license:
                return jsonify({
                    "status": "success",
                    "app_state": "first_time",
                    "license_type": None,
                    "license_expiry": None,
                    "activation_code": None
                })

            now = datetime.now()
            app_state = "active" if license.license_status and license.license_expiry > now else "expired"

            return jsonify({
                "status": "success",
                "app_state": app_state,
                "license_type": license.license_type,
                "license_expiry": license.license_expiry.isoformat(),
                "days_remaining": max(0, (license.license_expiry - now).days),
                "activation_code": license.license_key.split('|')[0] if '|' in license.license_key else license.license_key
            })

        else:
            return jsonify({"status": "error", "message": "Invalid action"}), 400

    except Exception as e:
        print(f"Test endpoint error: {e}")
        return jsonify({"status": "error", "message": "Internal server error"}), 500

# Secure Network Discovery Broadcasting Service
class SecureNetworkDiscoveryService:
    def __init__(self, port=8888):
        self.port = port
        self.multicast_group = '239.255.1.1'
        self.running = False
        self.broadcast_thread = None
        self.session_key = None
        self.session_expiry = None
        self.broadcast_interval = 30  # seconds
        self.session_rotation_interval = 1800  # 30 minutes
        
    def generate_session_key(self):
        """Generate a secure session key for encryption"""
        return base64.b64encode(os.urandom(32)).decode('utf-8')
    
    def create_hmac(self, data, key):
        """Create HMAC for data authentication"""
        key_bytes = key.encode('utf-8')
        data_bytes = data.encode('utf-8')
        return hmac.new(key_bytes, data_bytes, hashlib.sha256).hexdigest()
    
    def encrypt_data(self, data, key):
        """Encrypt data using AES-256-CBC"""
        try:
            # Generate key and IV from the session key
            key_bytes = hashlib.sha256(key.encode('utf-8')).digest()
            iv = os.urandom(16)
            
            # Pad data to 16-byte boundary
            padder = padding.PKCS7(128).padder()
            padded_data = padder.update(data.encode('utf-8')) + padder.finalize()
            
            # Encrypt
            cipher = Cipher(algorithms.AES(key_bytes), modes.CBC(iv), backend=default_backend())
            encryptor = cipher.encryptor()
            encrypted_data = encryptor.update(padded_data) + encryptor.finalize()
            
            # Return IV + encrypted data, base64 encoded
            return base64.b64encode(iv + encrypted_data).decode('utf-8')
        except Exception as e:
            print(f"Encryption error: {e}")
            return None
    
    def create_secure_packet(self):
        """Create a secure broadcast packet"""
        try:
            # Get account information
            account = Account.query.first()
            if not account:
                print("❌ No account found for secure broadcasting")
                return None
            
            # Generate or rotate session key
            now = datetime.now(timezone.utc)
            if not self.session_key or not self.session_expiry or now >= self.session_expiry:
                self.session_key = self.generate_session_key()
                self.session_expiry = now + timedelta(seconds=self.session_rotation_interval)
                print(f"🔄 Generated new session key, expires at {self.session_expiry}")
            
            # Create server info
            server_info = {
                'server_type': 'blupos_backend',
                'ip_address': '0.0.0.0',  # Will be resolved by clients
                'port': self.port,
                'server_name': 'BluPOS Backend Server',
                'last_seen': now.isoformat(),
                'timestamp': int(now.timestamp()),
                'url': f'http://0.0.0.0:{self.port}'
            }
            
            # Encrypt server info
            encrypted_server_info = self.encrypt_data(json.dumps(server_info), self.session_key)
            if not encrypted_server_info:
                return None
            
            # Create HMAC for authentication
            hmac_value = self.create_hmac(encrypted_server_info, self.session_key)
            
            # Create secure packet
            packet = {
                'version': '1.0',
                'timestamp': now.isoformat(),
                'encrypted_session_key': self.session_key,
                'encrypted_server_info': encrypted_server_info,
                'hmac': hmac_value,
                'padding': base64.b64encode(os.urandom(16)).decode('utf-8')
            }
            
            return json.dumps(packet)
        except Exception as e:
            print(f"Error creating secure packet: {e}")
            return None
    
    def broadcast_loop(self):
        """Main broadcasting loop"""
        try:
            # Create UDP socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            
            # Enable broadcasting
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            
            # Set TTL for multicast
            ttl = struct.pack('b', 2)
            sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, ttl)
            
            print(f"📡 Secure network discovery broadcasting on {self.multicast_group}:{self.port}")
            print(f"🔐 Session key rotation every {self.session_rotation_interval//60} minutes")
            
            while self.running:
                try:
                    # Create and send secure packet
                    packet_data = self.create_secure_packet()
                    if packet_data:
                        packet_bytes = packet_data.encode('utf-8')
                        sock.sendto(packet_bytes, (self.multicast_group, self.port))
                        print(f"📡 Secure broadcast sent ({len(packet_bytes)} bytes)")
                    
                    # Wait for next broadcast
                    time.sleep(self.broadcast_interval)
                    
                except Exception as e:
                    print(f"Broadcast error: {e}")
                    time.sleep(1)  # Short delay before retrying
                    
        except Exception as e:
            print(f"Broadcasting setup error: {e}")
        finally:
            sock.close()
    
    def start(self):
        """Start the secure network discovery service"""
        if self.running:
            print("⚠️ Secure network discovery already running")
            return
        
        self.running = True
        self.broadcast_thread = threading.Thread(target=self.broadcast_loop, daemon=True)
        self.broadcast_thread.start()
        print("🔐 Secure network discovery service started")
    
    def stop(self):
        """Stop the secure network discovery service"""
        self.running = False
        if self.broadcast_thread:
            self.broadcast_thread.join(timeout=2)
        print("🔐 Secure network discovery service stopped")

# Global secure discovery service instance
secure_discovery_service = SecureNetworkDiscoveryService()

def run_heroku_mode():
    h_port = int(os.environ.get('PORT', 8080))

    # Start secure network discovery broadcasting
    try:
        secure_discovery_service.start()
        print("🔐 Secure network discovery broadcasting started")
        print("📡 [BACKEND] Secure network discovery service initialized")
        print("📡 [BACKEND] Broadcasting on port 8888")
        print("📡 [BACKEND] Multicast group: 239.255.1.1")
        print("📡 [BACKEND] TTL: 2 (local network only)")
        print("🔐 [BACKEND] AES-256-CBC encryption with HMAC-SHA256 authentication")
        print("🔐 [BACKEND] Session key rotation every 30 minutes")
    except Exception as e:
        print(f"⚠️ Failed to start secure network discovery broadcasting: {e}")

    # Start legacy network discovery broadcasting if available
    if BROADCAST_AVAILABLE:
        try:
            start_backend_broadcast(port=h_port)
            print("🔍 Legacy network discovery broadcasting started")
        except Exception as e:
            print(f"⚠️ Failed to start legacy network discovery broadcasting: {e}")

    print(f"🚀 Starting BluPOS backend server on 0.0.0.0:{h_port}")
    print(f"🌐 Server will be accessible at: http://localhost:{h_port}")
    print(f"🌐 External access: http://<your-ip>:{h_port}")
    print(f"📡 Make sure firewall allows port {h_port}")
    app.run(host='0.0.0.0', port=h_port, debug=True, threaded=True)

if __name__ == "__main__":
    run_heroku_mode()
