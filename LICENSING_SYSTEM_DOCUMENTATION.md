# Expo BLUPOS v5 - Licensing System Documentation

## Overview

The licensing system in Expo BLUPOS v5 provides software activation and access control for the Point of Sale application. It uses a combination of database-stored license records and hashed reset keys for security.

## System Architecture

### Database Models

#### License Model
```python
class License(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    uid = db.Column(db.String(10), unique=True, nullable=False)
    license_key = db.Column(db.String(20), unique=True, nullable=False)
    license_type = db.Column(db.String(10), nullable=False)
    license_status = db.Column(db.Boolean, nullable=False)
    license_expiry = db.Column(db.DateTime, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.now())
    updated_at = db.Column(db.DateTime, default=datetime.now())
```

#### LicenseResetKey Model (YAML-based)
```yaml
# .pos_keys.yml - Stores SHA-256 hashed reset keys
- fd53398c1730395cbf3e91bc3d6532335eb7b1772c7267ad4fbbccd87a3b869e
- 124ea4fcaf435cae978d16be9d8cc569a62a7427d6c03d00f2be58e275daa203
# ... up to 20 keys maximum
```

## Licensing Flow

### 1. Application Startup
```
Application starts → Check database for license records
```

### 2. Route Access Control
```
User accesses admin route → is_active() checks session
→ If admin role, check license status
→ License expired/invalid → Redirect to license reset page
→ License valid → Allow access
```

### 3. License Reset Process
```
User enters 16-digit reset key → Select license type (Full/Half)
→ System hashes input key with SHA-256
→ Compare against stored hashes in .pos_keys.yml
→ If match found → Create new license record
→ Delete any existing licenses (maintain single license)
→ Set expiry: Full=366 days, Half=183 days
```

### 4. License Validation
```
On each admin route access:
→ Fetch license from database
→ Check license_status boolean
→ Calculate days_remaining = (expiry - now).days
→ If status=True AND days_remaining >= 0 → Allow access
→ Else → Show license reset form
```

## Current Implementation Analysis

### Backend Functions

#### create_license(payload)
- **Purpose**: Creates new license record
- **Logic**: Maintains only ONE license (deletes existing before creating new)
- **Input**: license_key, license_type, license_status, license_expiry
- **Issue**: No validation of input parameters

#### update_license(payload)
- **Purpose**: Updates existing license
- **Logic**: Finds by license_key, updates all fields except license_key
- **Issue**: No error handling if license not found

#### reset_license(payload)
- **Purpose**: Resets license (unused in current flow)
- **Logic**: Deletes existing license, creates new one
- **Issue**: Same as create_license - no input validation

#### LicenseResetKey Static Methods
- **save_key()**: Hashes key with SHA-256, stores in YAML (max 20 keys)
- **delete_key()**: Removes hashed key from YAML
- **is_valid_key()**: Hashes input, checks against stored hashes
- **fetch_keys()**: Loads YAML file, returns list

### Frontend Implementation

#### user_management.html
Three license states displayed:
1. **No License**: Shows license reset form
2. **Expired License**: Shows license reset form
3. **Valid License**: Shows license details
   - If >10 days remaining: Normal display
   - If <10 days remaining: Warning display + reset option

#### JavaScript Functions
- **checkLicenseKeyLength()**: Enables submit button when 16 digits entered
- **License Type Selection**: Dropdown with "Half" option only

## Identified Bugs and Issues

### 🐛 Critical Bugs

#### 1. License Type Selection Bug
**Location**: `templates/user_management.html`
**Issue**: License type dropdown only shows "Half" option
**Impact**: Users cannot select "Full" license type
**Fix**: Add "Full" option to dropdown

#### 2. License Creation Logic Issue
**Location**: `backend.py:create_license()`
**Issue**: Always maintains only 1 license, deletes existing ones
**Impact**: Cannot have multiple licenses (though this might be intended)
**Fix**: Add configuration option for multi-license support

#### 3. Days Remaining Calculation Bug
**Location**: `backend.py:user_management route`
**Issue**: Simple date subtraction doesn't handle timezones properly
**Impact**: Potential incorrect expiry calculations
**Fix**: Use timezone-aware datetime calculations

#### 4. License Status Inconsistency
**Location**: `backend.py:user_management route`
**Issue**: Checks both `license_status` boolean AND expiry date
**Impact**: License could be "active" but expired, or "inactive" but not expired
**Fix**: Consolidate logic - expiry date should determine status

#### 5. Missing License Type "Full" in UI
**Location**: `templates/user_management.html`
**Issue**: Backend supports "Full" type but UI only shows "Half"
**Fix**: Add "Full" option to license type dropdown

### ⚠️ Security Issues

#### 1. Reset Key Storage Security
**Issue**: Hashed keys stored in YAML file on filesystem
**Risk**: File system access could compromise keys
**Improvement**: Move to database storage with encryption

#### 2. No Rate Limiting
**Issue**: No limits on license reset attempts
**Risk**: Brute force attacks on reset keys
**Fix**: Implement attempt rate limiting

#### 3. License Key Length Validation
**Issue**: Only frontend validation (16 digits)
**Risk**: Backend accepts any length
**Fix**: Add backend validation

### 🔧 Functional Issues

#### 1. Error Handling
**Issue**: Minimal error handling in license operations
**Impact**: Silent failures, poor user experience
**Fix**: Add comprehensive error handling and user feedback

#### 2. License Reset Key Limit
**Issue**: Hard-coded limit of 20 keys
**Impact**: Cannot add more reset keys when limit reached
**Fix**: Make limit configurable

#### 3. No License Audit Trail
**Issue**: No logging of license creation/reset events
**Impact**: Cannot track license usage history
**Fix**: Add audit logging

#### 4. License Expiry Warning Logic
**Issue**: Only shows warning when <10 days remaining
**Impact**: Users get surprised by sudden expiry
**Fix**: Configurable warning periods (30, 7, 1 day warnings)

## Proposed Improvements

### 1. Enhanced License Management
```python
class LicenseManager:
    @staticmethod
    def validate_license():
        """Consolidated license validation logic"""
        license = License.query.first()
        if not license:
            return {"valid": False, "reason": "no_license"}

        now = datetime.now(timezone.utc)
        expiry = license.license_expiry

        if not license.license_status:
            return {"valid": False, "reason": "inactive"}

        if expiry <= now:
            return {"valid": False, "reason": "expired"}

        days_remaining = (expiry - now).days
        return {
            "valid": True,
            "days_remaining": days_remaining,
            "warning": days_remaining <= 30
        }
```

### 2. Improved Reset Key Security
```python
class SecureLicenseResetKey(LicenseResetKey):
    MAX_ATTEMPTS = 5
    LOCKOUT_TIME = 300  # 5 minutes

    @staticmethod
    def validate_with_rate_limit(key):
        # Check rate limiting logic
        # Implement attempt tracking and lockout
        pass
```

### 3. Better UI/UX
- Add license expiry countdown timer
- Email notifications for expiring licenses
- License usage statistics dashboard
- Bulk license management for multiple installations

### 4. Database Improvements
- Add license history table for audit trail
- Implement proper foreign key relationships
- Add database-level constraints and triggers

### 5. API Enhancements
- RESTful API for license management
- License synchronization across multiple instances
- Automated license renewal system

## Testing Coverage

### Current Tests
- ✅ License creation (maintains single license)
- ✅ License update functionality
- ✅ Reset key generation and validation
- ✅ Invalid key rejection

### Missing Tests
- ❌ License expiry logic
- ❌ Rate limiting for reset attempts
- ❌ UI state transitions
- ❌ Database integrity checks
- ❌ Security validation (SQL injection, etc.)

## Migration Path

### Phase 1: Bug Fixes (Immediate)
1. Fix license type dropdown to include "Full" option
2. Improve days remaining calculation with timezone handling
3. Add input validation for license operations
4. Consolidate license status checking logic

### Phase 2: Security Enhancements (Week 1-2)
1. Move reset keys to encrypted database storage
2. Implement rate limiting for reset attempts
3. Add comprehensive audit logging
4. Improve error handling and user feedback

### Phase 3: Feature Enhancements (Week 3-4)
1. Add license expiry warnings (30, 7, 1 day notifications)
2. Implement license usage analytics
3. Add bulk license management
4. Create license renewal automation

### Phase 4: Advanced Features (Month 2+)
1. Multi-instance license synchronization
2. Cloud-based license server
3. Advanced reporting and analytics
4. Mobile license management app

## Monitoring and Maintenance

### Key Metrics to Monitor
- License creation success rate
- Reset key validation attempts/failures
- License expiry rates
- User access patterns

### Regular Maintenance Tasks
- Clean up expired licenses
- Rotate reset keys periodically
- Review access logs for suspicious activity
- Update license expiry warnings

## Conclusion

The current licensing system provides basic functionality but has several bugs and security issues that need immediate attention. The proposed improvements will enhance security, reliability, and user experience while maintaining backward compatibility.

Priority should be given to fixing the critical bugs, especially the license type selection issue and expiry calculation problems, before implementing advanced features.
