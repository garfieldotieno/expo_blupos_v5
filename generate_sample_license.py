#!/usr/bin/env python3
"""
Sample data generator for license activation testing.
Creates licenses with specific expiry dates in days.
"""

import sys
import os
sys.path.append(os.path.dirname(__file__))

from backend import app, db, create_license, Account
from datetime import datetime, timedelta, timezone

def generate_sample_license(days_until_expiry):
    """Generate a sample license that expires in the specified number of days."""
    with app.app_context():
        # Ensure database is set up
        db.create_all()

        # Get or create account
        account = Account.query.first()
        if not account:
            account_id = f"sample_account_{int(datetime.now().timestamp())}"
            account = Account(account_id=account_id, account_type='web')
            db.session.add(account)
            db.session.commit()
        else:
            account_id = account.account_id

        # Create license expiring in specified days
        expiry_date = datetime.now(timezone.utc) + timedelta(days=days_until_expiry)
        license_data = {
            "license_key": f"SAMPLE{account_id}",
            "license_type": f"Sample_{days_until_expiry}days",
            "license_status": True,
            "license_expiry": expiry_date
        }

        result = create_license(license_data, account_id)
        if result:
            print(f"✅ Sample license created successfully!")
            print(f"   Account ID: {account_id}")
            print(f"   License Type: {license_data['license_type']}")
            print(f"   Expires in: {days_until_expiry} days")
            print(f"   Expiry Date: {expiry_date}")
            return True
        else:
            print("❌ Failed to create sample license")
            return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python generate_sample_license.py <days_until_expiry>")
        print("Example: python generate_sample_license.py 30  # Expires in 30 days")
        print("Example: python generate_sample_license.py -5  # Already expired 5 days ago")
        sys.exit(1)

    try:
        days = int(sys.argv[1])
        generate_sample_license(days)
    except ValueError:
        print("Error: days_until_expiry must be an integer")
        sys.exit(1)