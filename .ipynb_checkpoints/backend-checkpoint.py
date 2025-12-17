from enum import unique
import json
from flask import Flask, render_template, request, abort, redirect, make_response, url_for, session, send_file, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta
import os
import string, random
from flask_sqlalchemy import SQLAlchemy
import time
from flask_cors import CORS

from reportlab.lib.pagesizes import landscape, letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, PageBreak
from io import BytesIO

import pydantic
import yaml
import hashlib

app = Flask(__name__)
app.secret_key = b"Z'(\xac\xe1\xb3$\xb1\x8e\xea,\x06b\xb8\x0b\xc0"
CORS(app)

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///pos_test.db'
db = SQLAlchemy(app)

app.config['PERMANENT_SESSION_LIFETIME'] =  timedelta(hours=2)

@app.template_filter()
def numberFormat(value):
    return format(int(value), 'd')


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
    "Admin" : {"allowed_routes":['/users', '/records', '/add_user', '/delete_user']},
    "Sale":{"allowed_routes":['/sales', '/add_sale_record']},
    "Inventory" : {"allowed_routes":['/inventory', '/add_item_inventory', '/edit_item', '/delete_item_inventory', '/delete_item_inventory', '/item/', '/update_item_inventory', '/get_restock_printout', '/get_sale_record_printout', '/get_sale_transaction_printout']}
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


class License(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    uid = db.Column(db.String(10), unique=True, nullable=False)
    license_key = db.Column(db.String(20), unique=True, nullable=False)
    license_type = db.Column(db.String(10), nullable=False)
    license_status = db.Column(db.Boolean, nullable=False)
    license_expiry = db.Column(db.DateTime, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.now())
    updated_at = db.Column(db.DateTime, default=datetime.now())

    def __repr__(self):
        return f"License(id={self.id}, uid='{self.uid}', license_key='{self.license_key}', license_type='{self.license_type}', license_status='{self.license_status}', license_expiry='{self.license_expiry}', created_at={self.created_at}, updated_at={self.updated_at})"

def create_license(payload):
    # update so that there can only be one record
    license = License()
    license.uid = randomString(16)
    license.license_key = payload['license_key']
    license.license_type = payload['license_type']
    license.license_status = payload['license_status']
    license.license_expiry = payload['license_expiry']

    # check length of records, if empty add, if one, delete and create new
    if License.query.all() == []:
        db.session.add(license)
        db.session.commit()
        return {"status":True}
    else:
        delete_license(1)
        db.session.add(license)
        db.session.commit()
        return {"status":True}



def fetch_licenses():
    return License.query.all()

def fetch_license(uid):
    return License.query.filter_by(uid=uid).first()

def delete_license(license_id):
    license = License.query.filter_by(id=license_id).first()
    db.session.delete(license)
    return db.session.commit()

def update_license(payload):
    license = License.query.filter_by(license_key=payload['license_key']).first()
    for key in payload:
        if key != 'license_key':
            setattr(license, key, payload[key])
    license.updated_at = datetime.now()
    db.session.add(license)
    db.session.commit()
    return license

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
        print(f"get all items : {get_all_items()}")
        response = make_response(render_template(
            'inventory_management.html',
            is_active = True,
            title="Inventory",
            flash_message = flash_message,
            flash_payload = flash_payload,
            user_type=session['session_user'].decode('utf-8'),
            user_name=user_from_session(),
            shop_data = [load_shop_data()],
            items = InventoryOperations.get_all_items_inventory(),

            item_transactions = SaleItemTransaction.query.all(),

            sale_records = SaleRecord.query.all(),

            SaleItem = SaleItem
        ))
        return response
    else:
        return redirect(query['middleware']['allowed_routes'][0])

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
    # fetches items using the class static method generate_restock_list
    # then filters for items by evaluating if current_stock_count is less than re_stock_value
    # returns a list of items that meet the condition
    query = is_active()
    print(f"query string at /user, {query}")
    if query['status'] and request.path in query['middleware']['allowed_routes']:
        print(f"get all items : {get_all_items()}")
        response = make_response(render_template(
            'restock_printout.html',
            is_active = True,
            title="Inventory",
            flash_message = False,
            flash_payload = "",
            user_type=session['session_user'].decode('utf-8'),
            user_name=user_from_session(),
            shop_data = [load_shop_data()],
            items = InventoryOperations.generate_restock_list(),
            current_time = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
        ))
        return response
    else:
        return redirect(query['middleware']['allowed_routes'][0])

@app.route('/get_sale_record_printout', methods=['GET'])
def get_sale_record_printout():
    # fetches items using the class static method generate_restock_list
    # then filters for items by evaluating if current_stock_count is less than re_stock_value
    # returns a list of items that meet the condition
    query = is_active()
    print(f"query string at /user, {query}")
    if query['status'] and request.path in query['middleware']['allowed_routes']:
        print(f"get all items : {get_all_items()}")
        response = make_response(render_template(
            'sales_records_printout.html',
            is_active = True,
            title="Inventory",
            flash_message = False,
            flash_payload = "",
            user_type=session['session_user'].decode('utf-8'),
            user_name=user_from_session(),
            shop_data = [load_shop_data()],
            sale_records = SaleRecord.query.all(),
            current_time = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
        ))
        return response
    else:
        return redirect(query['middleware']['allowed_routes'][0])
    

class SaleItemTransaction(db.Model):
    id = db.Column(db.Integer, primary_key=True)
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
    # fetch post with security key
    json_data = request.get_json()
    print(f"recieved sale record, {json_data}")
    items_sold = []
    item_array = json_data['items_array']
    print(f"item_arr is ot type {type(item_array)}")
    
    # sale item transactions
    for it in item_array:
        print("adding sale-item-transactions---")

        item_transaction = SaleItemTransaction()
        sale_item = SaleItem.query.filter_by(id=int(it.split(":")[0])).first()
        print(f"found sale item {sale_item}")

        item_transaction.item_uid = sale_item.uid
        item_transaction.transaction_type = 'Purchase'
        item_transaction.transaction_quantity = 1
        item_transaction.item_price = sale_item.price
        db.session.add(item_transaction)
        db.session.commit()
    
    # update stock count
    for it in item_array:
        print("updating item stock count---")
        sale_item = SaleItem.query.filter_by(id=int(it.split(":")[0])).first()
        print(f"found sale during stock update item {sale_item}")

        stock = SaleItemStockCount.query.filter_by(item_uid=sale_item.uid).first()
        print(f"found stock {stock}")

        stock.current_stock_count -= 1

        db.session.add(stock)
        db.session.commit()

    # create sale record
    try:
        add_sale_record(json_data)
    except Exception as e:
        print(f"unable to add sale record because : {e}")


    return {'status':True}





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
    
    licenses = fetch_licenses()
    print(f"type of fetched records is {type(licenses)} and value is {licenses}")

          

    if query['status'] and request.path in query['middleware']['allowed_routes']:
        # check if record is active
        if licenses == []:
            print("no license fetched")
            response = make_response(render_template(
                    'user_management.html',
                    is_active = True,
                    title="Users",
                    flash_message = flash_message,
                    flash_payload = flash_payload,
                    sector_a = False,
                    sector_c = True,
                    license_record = None,
                    days_remaining = 0,
                    user_type=session['session_user'].decode('utf-8'),
                    user_name=user_from_session(),
                    shop_data = [load_shop_data()],
                    users = fetch_users()
                ))

            return response

        else:
            license = licenses[0]
            if license.license_status:
                response = make_response(render_template(
                    'user_management.html',
                    is_active = True,
                    title="Users",
                    flash_message = flash_message,
                    flash_payload = flash_payload,
                    sector_a = True,
                    sector_c = True,
                    license_record = license,
                    days_remaining = (license.license_expiry - datetime.now()).days,
                    user_type=session['session_user'].decode('utf-8'),
                    user_name=user_from_session(),
                    shop_data = [load_shop_data()],
                    users = fetch_users()
                ))
                return response
            else:
                response = make_response(render_template(
                    'user_management.html',
                    is_active = True,
                    title="Users",
                    flash_message = flash_message,
                    flash_payload = flash_payload,
                    sector_a = False,
                    sector_c = True,
                    license_record = license,
                    days_remaining = (license.license_expiry - datetime.now()).days,
                    user_type=session['session_user'].decode('utf-8'),
                    user_name=user_from_session(),
                    shop_data = [load_shop_data()],
                    users = fetch_users()
                ))

                return response
                print(f"license fetched is, {license}")

  
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
    db.create_all()
    master_user = {"user_name":"Karua", "password":"jnkarua19", "role":"Admin"}
    sales_user = {"user_name":"Wandia", "password":"evangeline", "role":"Sale"}
    inventory_user = {"user_name":"Esther", "password":"wakabari", "role":"Inventory"}
    create_user(master_user)
    create_user(sales_user)
    create_user(inventory_user)
    





# create new function run to determine between development and production mode as fed in the arguments when executing this file

def run_heroku_mode():
    h_port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=h_port, debug=True)
    
if __name__ == "__main__":  
    run_heroku_mode()