import requests
import argparse
import unittest
import random
from backend import randomString, InventoryOperations
from backend import create_license, update_license, delete_license, License, LicenseResetKey
from backend import datetime, timedelta, sample_upc_code

# Your function
def init_users(key):
    url_string = 'http://localhost:80/init_users'
    data = {'shop_api_key': key}
    headers = {'Content-Type': 'application/json'}

    response = requests.post(url_string, json=data, headers=headers)

    if response.status_code == 200:
        response_data = response.json()
        return response_data
    else:
        return None

class TestInitUsers(unittest.TestCase):

    def test_init_users_successful(self):
        api_key = '155111268'
        result = init_users(api_key)
        self.assertIsNotNone(result)
        # Add more assertions based on the expected result

    def test_init_users_failed(self):
        api_key = 'invalid_key'
        result = init_users(api_key)
        if result['status'] != 'success': 
            self.assertEqual(result['status'], 'failed')
        else:
            self.assertEqual(result['status'], 'success')

class TestLicenseResetKey(unittest.TestCase):
    # class attribute
    fresh_generated_keys = []

    def test_a_generate_20_unique_license_reset_keys(self):
        num_licenses = 20

        for _ in range(num_licenses):
            key = randomString(16)
            print(key)
            LicenseResetKey.save_key(key)
        
        fresh_keys = LicenseResetKey.fetch_keys()
        
        # Assign the class attribute to a local variable
        self.fresh_generated_keys = fresh_keys
        self.assertEqual(len(fresh_keys), num_licenses)
    
    # pick 4 random keys from the list of fresh_generated_keys and validate them
    def test_b_validate_reset_keys(self):
        if len(self.fresh_generated_keys) >= 4:
            list_of_keys = random.sample(self.fresh_generated_keys, 4)
            for key in list_of_keys:
                self.assertTrue(LicenseResetKey.is_valid_key(key))
                print(f"Key: {key} is valid")
        else:
            self.skipTest("Not enough keys to sample 4")

    # generate 2 random keys and validate them
    def test_c_validate_invalid_reset_keys(self):
        invalid_keys = [randomString(16), randomString(16)]
        for key in invalid_keys:
            self.assertFalse(LicenseResetKey.is_valid_key(key))

         

class TestLicense(unittest.TestCase):
    # def test_a_add_license that creates two records
    def test_a_add_license(self):
        for _ in range(2):
            payload = {}
            payload['license_key'] = randomString(16)
            payload['license_expiry'] = datetime.now() + timedelta(days=183)
            payload['license_status'] = True
            payload['license_type'] = 'Full'
            create_license(payload)

        licenses = License.query.all()
        self.assertIsNotNone(licenses)
        self.assertEqual(len(licenses), 1)

    # def test_b_update_license
    def test_b_update_license(self):
        license = License.query.first()
        payload = {}
        payload['license_key'] = license.license_key
        payload['license_expiry'] = datetime.now() + timedelta(days=9)
        payload['license_status'] = True
        payload['license_type'] = 'Full'
        updated_license = update_license(payload)
        self.assertEqual(updated_license.license_type, payload['license_type'])
        self.assertEqual(updated_license.license_status, payload['license_status'])
        self.assertEqual(updated_license.license_expiry, payload['license_expiry'])

class TestInventoryOperation(unittest.TestCase):

    def test_a_create_20_unique_item_inventory(self):
        num_items = 20
        for _ in range(num_items):
            payload = {}
            payload['item_name'] = random.choice(['item1', 'item2', 'item3', 'item4', 'item5'])
            payload['item_type'] = random.choice(['type1', 'type2', 'type3', 'type4', 'type5'])
            payload['item_code'] = sample_upc_code()
            payload['item_description'] = random.choice(['description1', 'description2', 'description3', 'description4', 'description5'])
            payload['item_price'] = random.choice([100,200,300,400])
            payload['item_stock'] = random.randint(1, 100)


            payload['re_stock_value'] = random.choice([10,20,30,40])
            
            InventoryOperations.add_item_inventory(payload)

        item_inventory = InventoryOperations.get_all_items_inventory()
        self.assertIsNotNone(item_inventory)
        self.assertEqual(len(item_inventory), num_items)


        

        
        
           






# update to account for the new table
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run specific unit test cases')
    parser.add_argument('--test', choices=['TestSaleRecord', 'TestInitUsers', 'TestItemsOfSale', 'TestLicense', 'TestLicenseResetKey', 'TestInventoryOperation'], help='Name of the test case to run')
    args = parser.parse_args()

    if args.test:
        suite = unittest.TestLoader().loadTestsFromTestCase(globals()[args.test])
        unittest.TextTestRunner().run(suite)
    else:
        unittest.main()