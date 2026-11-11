# Requirements: Fix BKH Business Manager Data Persistence and Batch Lifecycle

## Summary

The BKH Business Manager app has two critical failures:
1. **Data Loss on Logout**: Admin adds customers, products, and settings, then logs out. Upon re-login, all data is gone.
2. **Incorrect Batch Lifecycle**: Batches settle immediately upon completion instead of following the required two-batch delay pattern. Batch period and transfer period timing rules are not enforced.

This fix will implement persistent Firestore storage for all admin-configured data and completely rewrite the batch lifecycle logic to enforce period-based timing and proper settlement sequencing.

## Functional Requirements

### FR1: Data Persistence for Customers
- **FR1.1**: When Admin adds a customer, immediately save to Firestore `customers` collection with fields: `name`, `mobile`, `address`, `timestamp`
- **FR1.2**: When Admin deletes a customer, immediately remove from Firestore
- **FR1.3**: On app start (before `runApp`), load all customers from Firestore into `demoOms.customers`
- **FR1.4**: On admin login, reload customers from Firestore to sync any changes

### FR2: Data Persistence for Products
- **FR2.1**: When Admin adds a product, immediately save to Firestore `products` collection with fields: `title`, `category`, `description`, `wholesalePrice`, `timestamp`
- **FR2.2**: When Admin deletes a product, immediately remove from Firestore
- **FR2.3**: On app start, load all products from Firestore into `demoOms.products`
- **FR2.4**: On admin login, reload products from Firestore

### FR3: Data Persistence for System Settings
- **FR3.1**: When Admin changes profit rate, batch period (cycle hours), transfer period (transfer hours), growth rate, or initial batch target, immediately save to Firestore `settings` document
- **FR3.2**: Settings document contains: `profitRate`, `initialBatchTarget`, `growthRate`, `cycleHours`, `transferHours`, `systemEnabled`
- **FR3.3**: On app start, load settings from Firestore into `demoOms.settings`
- **FR3.4**: If no settings document exists (first run), use defaults and create the document

### FR4: Data Persistence for Batches
- **FR4.1**: When a batch is created, save to Firestore `batches` collection with fields: `id`, `target`, `division`, `createdAt` (timestamp), `status` (active/completed/settled)
- **FR4.2**: When a batch status changes (active → completed → settled), update Firestore
- **FR4.3**: On app start, load active and completed batches from Firestore
- **FR4.4**: Restore batch state including which batches are settled

### FR5: Batch Period Enforcement
- **FR5.1**: Each batch has a batch period timer starting from its `createdAt` timestamp
- **FR5.2**: A batch can complete ONLY when BOTH conditions are met:
  - Batch period has elapsed (e.g., 4 hours since `createdAt`)
  - All reseller payments for that batch are completed
- **FR5.3**: If all payments complete BEFORE the batch period elapses, the batch remains active until the period completes
- **FR5.4**: If the batch period elapses but payments are incomplete, the batch remains active and transfer continues until all payments complete
- **FR5.5**: The background automation timer checks every minute whether both conditions are met

### FR6: Transfer Period Enforcement
- **FR6.1**: Each order has a `createdAt` timestamp
- **FR6.2**: When an order is assigned to a reseller, a transfer period timer starts (e.g., 1 hour)
- **FR6.3**: If the reseller does not confirm payment within the transfer period, the order automatically transfers to the next active reseller
- **FR6.4**: When an order transfers, its `createdAt` timestamp updates to the current time, starting a fresh transfer period for the new reseller
- **FR6.5**: Transfer continues until payment is confirmed
- **FR6.6**: Background automation checks every minute for expired transfer periods

### FR7: Batch Settlement Sequence (Two-Batch Delay)
- **FR7.1**: When 1st batch completes, 2nd batch is created. 1st batch is NOT settled yet.
- **FR7.2**: When 2nd batch completes, 1st batch is settled (orders delivered, wallets credited) AND 3rd batch is created
- **FR7.3**: When 3rd batch completes, 2nd batch is settled AND 4th batch is created
- **FR7.4**: Pattern: Current batch completes → Previous batch settles + Next batch creates
- **FR7.5**: Settlement includes: mark batch as settled, change order status from processing to delivered, credit reseller wallets (capital + profit)
- **FR7.6**: A batch can only be settled once (duplicate prevention)

### FR8: Reseller Data Persistence
- **FR8.1**: When a reseller registers, save to Firestore `resellers` collection
- **FR8.2**: When reseller wallet changes (capital, profit), update Firestore immediately
- **FR8.3**: When reseller is deactivated/deleted, update Firestore status
- **FR8.4**: On app start, load resellers from Firestore into `demoOms.resellers` AND `_registeredResellers` map

### FR9: Background Automation
- **FR9.1**: Start background timer in `main()` after Firebase initialization
- **FR9.2**: Every 1 minute, if system enabled:
  - Check for orders exceeding transfer period → auto-transfer
  - Check for batches where period elapsed AND payments complete → auto-settle previous batch + create next batch
- **FR9.3**: Log all automated actions to audit log

## Acceptance Criteria

**AC1: Data Persistence**
1. Admin logs in, adds 20 customers and 20 products
2. Admin sets profit rate to 40%, batch period to 4 hours, transfer period to 1 hour
3. Admin logs out
4. Admin logs back in
5. **PASS**: All 20 customers visible, all 20 products visible, settings show 40% profit, 4h batch period, 1h transfer period

**AC2: Batch Period Enforcement (Early Payment Completion)**
1. Admin sets batch period to 4 hours
2. Admin starts batch with target 500৳
3. All resellers complete payments within 2 hours
4. **PASS**: Batch remains in "active" status, not completed
5. After 4 hours total elapsed time
6. **PASS**: Batch now shows "completed" status, next batch created, previous batch (if exists) settled

**AC3: Batch Period Enforcement (Late Payment Completion)**
1. Admin sets batch period to 4 hours
2. Admin starts batch with target 500৳
3. 4 hours elapse but only 400৳ paid
4. **PASS**: Batch remains active, orders continue transferring
5. At 5 hours, final payment completes (500৳ total)
6. **PASS**: Batch immediately completes, next batch creates, previous batch settles

**AC4: Two-Batch Settlement Delay**
1. 1st batch completes
2. **PASS**: 2nd batch created, 1st batch status is "completed" NOT "settled"
3. 2nd batch completes
4. **PASS**: 1st batch status changes to "settled", orders delivered, wallets credited, 3rd batch created
5. 3rd batch completes
6. **PASS**: 2nd batch settled, 4th batch created

**AC5: Transfer Period Auto-Transfer**
1. Admin sets transfer period to 1 hour
2. Reseller A receives order at 10:00 AM
3. Reseller A does not confirm by 11:00 AM
4. **PASS**: At 11:01 AM (next automation check), order auto-transferred to Reseller B
5. Reseller B does not confirm by 12:01 PM
6. **PASS**: Order auto-transferred to Reseller C

**AC6: Reseller Deletion**
1. Admin adds reseller with email test@example.com
2. Admin deletes reseller
3. **PASS**: Reseller removed from list
4. Admin logs out and back in
5. **PASS**: Reseller still removed (deletion persisted)

**AC7: Batch Lifecycle Integration**
1. Admin sets batch period 4h, transfer period 1h, starts system
2. Orders assigned to resellers
3. After 1 hour, unpaid orders transfer
4. After 4 hours, all payments complete
5. **PASS**: Batch completes, previous batch settles, next batch creates
6. Reload app
7. **PASS**: Batch states restored correctly from Firestore

## Out of Scope

- Real-time synchronization across multiple admin devices (single admin instance assumed)
- Migration of existing in-memory data to Firestore (fresh start acceptable)
- Order history persistence beyond current/recent batches
- Withdrawal request persistence
- Notification persistence
- Audit log persistence (remains in-memory)
- Firebase Authentication changes (existing admin auth mechanism remains)
- UI changes (fixes are backend logic only)
- Timezone handling (device local time assumed)
- Network error retry logic (basic Firestore error handling only)

## Assumptions

1. **Single Admin**: Only one admin user manages the system at a time
2. **Fresh Start**: Existing data can be cleared; this is not a migration, it's a fix for future persistence
3. **Firestore Availability**: Firebase is properly initialized before attempting data operations
4. **Clock Accuracy**: Device clock is reasonably accurate for period calculations
5. **Background Execution**: Flutter app background timer works reliably on target platform
6. **Batch Document ID**: Batch ID (e.g., "B-001") is unique and suitable as Firestore document ID
