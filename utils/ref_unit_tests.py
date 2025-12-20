class TestItemsOfSale(unittest.TestCase):

    def test_20_random_items_of_sale(self):
        num_items = 20

        for _ in range(num_items):
            payload = {
                'code': sample_upc_code(12),  # Assuming code is 20 characters long
                'item_type': random.choice(['Electronics', 'Clothing', 'Groceries']),
                'name': random.choice(['Item1', 'Item2', 'Item3']),
                'description': random.choice(['Description1', 'Description2', 'Description3']),
                'price': round(random.uniform(10, 1000), 2),
                # 'current_stock_count': random.randint(0, 100),  # If needed
            }

            add_sale_item(payload)

        items_count = SaleItem.query.count()
        self.assertEqual(items_count, num_items)



class TestSaleRecord(unittest.TestCase):

    def test_20_random_sale_records(self):
        num_records = 20

        for _ in range(num_records):
            payment_method = random.choice(['CASH', 'MPESA'])
            if payment_method == 'CASH':
                payment_reference = 'NILL'
                payment_gateway = '0000-0000'  
            
            # Set payment_gateway for CASH
            else:  # payment_method == 'MPESA'
                payment_reference = randomString(10)
                payment_gateway = random.choice(['223111-476921', '400200-6354', '765244-80872'])

            sale_total = round(random.uniform(100, 2000), 2)
            sale_paid_amount = max(sale_total, round(random.uniform(sale_total, sale_total + 1000), 2))
            sale_balance = min(sale_total, sale_paid_amount)

            payload = {
                'sale_clerk': random.choice(['JaneDoe', 'SallyDoe', 'MaureenDoe']),
                'sale_total': sale_total,
                'sale_paid_amount': sale_paid_amount,
                'sale_balance': sale_balance,
                'payment_method': payment_method,
                'payment_reference': payment_reference,
                'payment_gateway': payment_gateway,
            }

            add_sale_record(payload)

        records_count = SaleRecord.query.count()
        self.assertEqual(records_count, num_records)


class TestInventory(unittest.TestCase):
    
    # this class will test
    # test_a_create_10_items.10 unique [item_type, description, name, price, current_stock_count]
    def test_a_create_10_items(self):
        unique_item_type = ['Type1', 'Type2', 'Type3', 'Type4', 'Type5', 'Type6', 'Type7', 'Type8', 'Type9', 'Type10']
        unique_descriptions = ['Description1', 'Description2', 'Description3', 'Description4', 'Description5', 'Description6', 'Description7', 'Description8', 'Description9', 'Description10']
        unique_names = ['Name1', 'Name2', 'Name3', 'Name4', 'Name5', 'Name6', 'Name7', 'Name8', 'Name9', 'Name10']
        unique_prices = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
        unique_stock_counts = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]

        for i in range(10):
            payload = {}
            payload['item_code'] = sample_upc_code(12)
            payload['item_type'] = unique_item_type[i]
            payload['item_description'] = unique_descriptions[i]
            payload['item_name'] = unique_names[i]
            payload['item_price'] = unique_prices[i]
            payload['item_stock'] = unique_stock_counts[i]
            add_sale_item(payload)

        items = SaleItem.query.all()
        self.assertIsNotNone(items)
        self.assertEqual(len(items), 10)


class TestSaleRecord(unittest.TestCase):
    # this class will test
    # test_a_simulate_6_unique_items_transaction wher each item will be bought in 2s or 3s
    # this function will leverage update_stock_count and add_sale_record
    def test_a_simulate_6_unique_items_cash_sale_transaction(self):
        # e.g
        # payload{'operation':'add', 'items_pack':[{'item_upc_code':'upc_value', 'item_count':16}, {'item_upc_code':'upc_value2', 'item_count':8}]}
        payload = {}
        payload['operation'] = 'subtract'
        # use comprenhension to generate the items_pack
        payload['items_pack'] = [{'item_upc_code':upc_codes[i], 'item_count':random.randint(0, 5)} for i in range(6)]
        # use comprenhension to generate the sale_record for cash
        payload['sale_record'] = {'sale_clerk':random.choice(['JaneDoe', 'SallyDoe', 'MaureenDoe']), 'sale_total':random.randint(100, 2000), 'sale_paid_amount':random.randint(100, 2000), 'sale_balance':random.randint(100, 2000), 'payment_method':'CASH', 'payment_reference':'NILL', 'payment_gateway':'0000-0000'}

    
    
    pass

