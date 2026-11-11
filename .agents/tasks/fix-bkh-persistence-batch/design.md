# Technical Design: Fix BKH Business Manager Data Persistence and Batch Lifecycle

## Overview

This design implements immediate Firestore persistence for all admin-configured data (customers, products, settings, batches) and rewrites the batch lifecycle logic to enforce period-based timing rules and two-batch settlement delays. The current implementation loses all data on logout because it stores everything in memory. The batch logic incorrectly settles batches immediately upon completion instead of waiting for the next batch to complete. This design fixes both issues with minimal changes to the existing UI layer.

## Technology Stack

- **Language**: Dart (Flutter)
- **Storage**: Cloud Firestore (already configured in `firebase_options.dart`)
- **State Management**: Direct mutation of `demoOms` singleton (existing pattern)
- **Background Processing**: `Timer.periodic` (already in use)
- **Collections**: `customers`, `products`, `settings`, `batches`, `resellers` (already defined in `firestore_service.dart`)

## Architecture Decisions

### Decision 1: Immediate Write-Through Pattern

**Approach**: Write to Firestore immediately when admin modifies data, update in-memory state after successful write.

**Alternatives Considered**:
- **Batched writes**: Queue changes and write periodically. Rejected because data loss risk if app closes before flush.
- **Write-behind cache**: Update memory first, write to Firestore async. Rejected because logout could happen before write completes.

**Chosen**: Write-through ensures data is persisted before the operation completes. Trade-off is slightly higher latency on admin operations, but admin actions are infrequent and correctness is more important than speed.

### Decision 2: Period-Based Batch Completion

**Approach**: Store batch `createdAt` timestamp in Firestore. Background timer calculates elapsed time and checks both conditions (period elapsed + payments complete) before allowing batch completion.

**Logic**:
```
batchComplete = (now - batch.createdAt >= batchPeriod) AND (allPaymentsComplete)
```

If `allPaymentsComplete` is true but period not elapsed: keep batch active, prevent settlement.
If period elapsed but `allPaymentsComplete` is false: keep batch active, continue transfers.

**Chosen**: This enforces the user's requirement that batch period is a minimum duration, preventing premature completion.

### Decision 3: Two-Batch Settlement Pattern

**Current (WRONG)**: When batch completes, settle it immediately and create next batch.

**New (CORRECT)**: Maintain a list of batch states: active, completed, settled. When a batch completes, mark it "completed" and create the next batch. When the next batch completes, settle the previous "completed" batch (mark it "settled", deliver orders, credit wallets), then mark current as "completed" and create the next.

**Implementation**: Use `settledBatchIds` set (already exists) plus new "completed but not settled" tracking. When batch N completes:
1. Find batch N-1 with status "completed"
2. Settle batch N-1 (orders → delivered, wallets credited, status → settled)
3. Mark batch N as "completed"
4. Create batch N+1

**Edge Case**: First batch (B-001) has no previous batch. Solution: Settle B-001 directly when B-002 completes.

### Decision 4: Transfer Period with Timestamp Reset

**Approach**: Each order has a `createdAt` timestamp (already exists). When order transfers to a new reseller, update `createdAt` to current time. Background timer calculates `(now - order.createdAt) >= transferPeriod` for each pending unpaid order.

**Chosen**: Updating timestamp on transfer is simpler than tracking per-reseller assignment timestamps. Each reseller gets a fresh full period.

## File Modifications

### File 1: `lib/firestore_service.dart`

**Add**: Settings persistence methods (currently missing).

**New Methods**:
```dart
static Future<void> saveSettings(DemoSettings settings)
static Future<DemoSettings?> loadSettings()
```

**saveSettings**: Write to `settings/config` document with fields `profitRate`, `initialBatchTarget`, `growthRate`, `cycleHours`, `transferHours`, `systemEnabled`.

**loadSettings**: Read `settings/config` document, return `DemoSettings` object or null if not found.

**Add**: Batch persistence methods.

**New Methods**:
```dart
static Future<void> saveBatch(DemoBatch batch, String status)
static Future<void> updateBatchStatus(String batchId, String status)
static Future<List<Map<String, dynamic>>> loadBatches()
```

**saveBatch**: Write to `batches/{batchId}` document with fields `id`, `target`, `division` (array), `createdAt` (timestamp), `status` (active/completed/settled).

**updateBatchStatus**: Update only the `status` field of existing batch document.

**loadBatches**: Read all batch documents, return list of maps containing batch data.

**Modify**: `loadSystemData` to call `loadSettings()` and populate `demoOms.settings`, and call `loadBatches()` to restore batch state.

**Error Handling**: All Firestore operations wrapped in try-catch. On write failure, throw `StateError` with message. On read failure (e.g., network unavailable), return empty list/null and allow app to start with empty data. Log errors to console.

### File 2: `lib/oms_demo.dart`

**Complete Rewrite**: `settleCurrentBatch()` method.

**Current Logic** (WRONG):
```dart
// Settles current batch immediately when complete
settleCurrentBatch() {
  if (batchPaidTotal != currentBatchTarget) throw error;
  // Settle current batch
  // Create next batch
}
```

**New Logic** (CORRECT):
```dart
settleCurrentBatch() {
  // 1. Verify current batch is fully paid
  if (batchOrderTotal != currentBatchTarget || batchPaidTotal != currentBatchTarget) {
    throw StateError('Full settlement unavailable until all payments complete');
  }
  
  // 2. Find previous batch to settle
  String? batchToSettle;
  int currentIndex = batches.indexWhere((b) => b.id == currentBatchId);
  
  if (currentIndex == 0) {
    // First batch: settle current batch directly
    batchToSettle = currentBatchId;
  } else {
    // Find previous unsettled batch
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (!settledBatchIds.contains(batches[i].id)) {
        batchToSettle = batches[i].id;
        break;
      }
    }
  }
  
  if (batchToSettle == null) throw StateError('No batch to settle');
  if (settledBatchIds.contains(batchToSettle)) throw StateError('Already settled');
  
  // 3. Settle the identified batch
  final settledOrders = orders.where((o) => 
    o.batchId == batchToSettle && 
    o.status == DemoOrderStatus.processing &&
    o.paymentStatus == DemoPaymentStatus.simulated
  ).toList();
  
  settledBatchIds.add(batchToSettle);
  
  for (final order in settledOrders) {
    order.status = DemoOrderStatus.delivered;
    order.reseller.capital += order.wholesalePrice;
    order.reseller.profit += order.profit;
    // Credit wallet entry
    // Update Firestore reseller wallet
  }
  
  // Update batch status in Firestore
  await FirestoreService.updateBatchStatus(batchToSettle, 'settled');
  
  // 4. Create next batch
  createNextBatch();
}
```

**New Method**: `checkBatchCompletion()`

```dart
void checkBatchCompletion() {
  if (!settings.systemEnabled) return;
  
  final currentBatch = batches.firstWhere((b) => b.id == currentBatchId);
  final now = DateTime.now();
  final batchPeriod = Duration(hours: settings.cycleHours);
  
  final periodElapsed = now.difference(currentBatch.createdAt) >= batchPeriod;
  final paymentsComplete = (batchOrderTotal == currentBatchTarget) && 
                           (batchPaidTotal == currentBatchTarget);
  
  if (periodElapsed && paymentsComplete) {
    // Both conditions met: complete batch
    try {
      settleCurrentBatch();
      auditLog.insert(0, 'Auto-settlement: batch ${currentBatch.id} completed after ${settings.cycleHours}h period.');
    } catch (e) {
      auditLog.insert(0, 'Auto-settlement failed: ${e.toString()}');
    }
  }
}
```

**Modify**: `checkAndAutoSettleBatch()` to call `checkBatchCompletion()`.

**Modify**: `checkAndTransferExpiredOrders()` to update order `createdAt` on transfer.

```dart
void _transferOrderDirect(DemoOrder order) {
  // ... existing logic ...
  order.createdAt = DateTime.now(); // RESET TIMESTAMP
  order.reseller = active[nextIndex];
  // ... rest of logic ...
}
```

**Modify**: `createNextBatch()` to save batch to Firestore.

```dart
void createNextBatch({bool initial = false}) {
  // ... existing logic to create batch ...
  batches.add(newBatch);
  
  // Save to Firestore
  await FirestoreService.saveBatch(newBatch, 'active');
  
  // ... create orders ...
}
```

**Modify**: `DemoOrder` class to make `createdAt` mutable.

```dart
class DemoOrder {
  // Change from final to var
  DateTime createdAt;
  
  DemoOrder({
    // ...
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
```

**Error Handling**: All Firestore operations in batch methods wrapped in try-catch. On write failure, throw `StateError` to prevent state inconsistency. Background automation errors are logged to `auditLog` but do not crash app.

### File 3: `lib/main.dart`

**Modify**: Customer add/delete operations to call Firestore immediately.

**Location**: `AdminCustomers` widget (around line 4500-5500 based on file structure).

**Add After Customer Added**:
```dart
try {
  await FirestoreService.saveCustomer(customer);
  setState(() {
    demoOms.customers.add(customer);
  });
  _message('Customer added successfully');
} catch (e) {
  _message('Failed to save customer: $e');
}
```

**Add After Customer Deleted**:
```dart
try {
  await FirestoreService.deleteCustomer(customer.mobile);
  setState(() {
    demoOms.customers.remove(customer);
  });
  _message('Customer deleted successfully');
} catch (e) {
  _message('Failed to delete customer: $e');
}
```

**Modify**: Product add/delete operations similarly.

**Location**: `AdminProducts` widget.

**Add After Product Added**:
```dart
try {
  await FirestoreService.saveProduct(product);
  setState(() {
    demoOms.products.add(product);
  });
  _message('Product added successfully');
} catch (e) {
  _message('Failed to save product: $e');
}
```

**Modify**: Settings update to save immediately.

**Location**: `AdminSettings` widget.

**Add After Settings Changed**:
```dart
try {
  demoOms.settings.profitRate = selectedRate;
  await FirestoreService.saveSettings(demoOms.settings);
  _message('Settings saved successfully');
} catch (e) {
  _message('Failed to save settings: $e');
}
```

**Modify**: `main()` to load settings after loading system data.

```dart
Future<void> main() async {
  // ... Firebase initialization ...
  
  try {
    await FirestoreService.loadSystemData();
    
    // Load settings
    final settings = await FirestoreService.loadSettings();
    if (settings != null) {
      demoOms.settings.systemEnabled = settings.systemEnabled;
      demoOms.settings.profitRate = settings.profitRate;
      demoOms.settings.initialBatchTarget = settings.initialBatchTarget;
      demoOms.settings.growthRate = settings.growthRate;
      demoOms.settings.cycleHours = settings.cycleHours;
      demoOms.settings.transferHours = settings.transferHours;
    }
    
    // Load resellers
    final storedResellers = await FirestoreService.loadResellers();
    // ... existing reseller loading ...
    
  } catch (e) {
    print('Firestore loading error: $e');
  }
  
  demoOms.startAutomation();
  runApp(const BechaKenaHubApp());
}
```

**Error Handling**: Data loading errors in `main()` are logged but do not prevent app start. App starts with empty data if Firestore unavailable. Write errors show user-facing error messages via `ScaffoldMessenger`.

## Data Model

### Firestore Collections

**customers** (collection)
- Document ID: `mobile` (unique)
- Fields: `name` (string), `mobile` (string), `address` (string), `timestamp` (timestamp)

**products** (collection)
- Document ID: `title` (unique)
- Fields: `title` (string), `category` (string), `description` (string), `wholesalePrice` (int), `timestamp` (timestamp)

**settings** (collection)
- Document ID: `config` (singleton)
- Fields: `profitRate` (int), `initialBatchTarget` (int), `growthRate` (int), `cycleHours` (int), `transferHours` (int), `systemEnabled` (bool)

**batches** (collection)
- Document ID: `id` (e.g., "B-001")
- Fields: `id` (string), `target` (int), `division` (array of ints), `createdAt` (timestamp), `status` (string: "active"/"completed"/"settled"), `previousTarget` (int, nullable), `growthRate` (int, nullable)

**resellers** (collection) - already exists
- Document ID: `email`
- Fields: `name`, `mobile`, `password`, `active`, `capital`, `profit`, `timestamp`

### In-Memory to Firestore Mapping

| In-Memory Object | Firestore Collection | Sync Trigger |
|-----------------|---------------------|--------------|
| `demoOms.customers` | `customers` | Add/delete customer |
| `demoOms.products` | `products` | Add/delete product |
| `demoOms.settings` | `settings/config` | Change any setting |
| `demoOms.batches` | `batches` | Create batch, update status |
| `demoOms.resellers` | `resellers` | Registration, wallet update |

## Validation Rules

### Batch Completion Validation

**Input**: Current batch state
**Rules**:
1. Batch period elapsed: `DateTime.now().difference(batch.createdAt) >= Duration(hours: settings.cycleHours)`
2. All payments complete: `batchOrderTotal == currentBatchTarget AND batchPaidTotal == currentBatchTarget`
**Output**: `true` if both conditions met, `false` otherwise
**On Failure**: Keep batch active, continue transfers if payments incomplete

### Transfer Expiration Validation

**Input**: Order with `createdAt` timestamp
**Rules**:
1. Order status: `pending`
2. Payment status: `unpaid`
3. Batch ID: `currentBatchId`
4. Time elapsed: `DateTime.now().difference(order.createdAt) >= Duration(hours: settings.transferHours)`
**Output**: `true` if order should transfer
**On Success**: Call `_transferOrderDirect(order)` to move to next reseller

### Settings Validation

**Input**: Admin-provided settings values
**Rules**:
- `profitRate`: Must be 20, 30, or 40
- `initialBatchTarget`: Must be multiple of 50, minimum 50
- `growthRate`: Must be 0-100
- `cycleHours`: Must be > 0
- `transferHours`: Must be > 0
**On Failure**: Throw `StateError` with specific message, do not save to Firestore

## Edge Cases

### Edge Case 1: First Batch Settlement

**Scenario**: Batch B-001 completes, no previous batch exists.
**Solution**: When `currentIndex == 0`, set `batchToSettle = currentBatchId` (settle current batch directly). When B-002 completes, B-001 will already be settled.

### Edge Case 2: App Restart During Batch

**Scenario**: Batch B-003 is active (B-001 settled, B-002 completed but not settled). App restarts.
**Solution**: `loadBatches()` reads all batch documents with status. Reconstruct `settledBatchIds` set from batches with status "settled". Current batch is the one with status "active". Completed-but-not-settled batches have status "completed".

### Edge Case 3: Multiple Orders Expire Simultaneously

**Scenario**: 10 orders all exceed transfer period at the same time.
**Solution**: `checkAndTransferExpiredOrders()` iterates through all pending unpaid orders, transfers each one. Round-robin reseller selection continues normally.

### Edge Case 4: All Payments Complete Before Period

**Scenario**: Batch period is 4 hours. All payments done in 2 hours.
**Solution**: `checkBatchCompletion()` returns `false` because `periodElapsed` is `false`. Batch remains active. At 4 hours, `checkBatchCompletion()` returns `true`, settlement proceeds.

### Edge Case 5: Period Elapses, Payments Incomplete

**Scenario**: Batch period is 4 hours. After 4 hours, only 400৳ of 500৳ paid.
**Solution**: `checkBatchCompletion()` returns `false` because `paymentsComplete` is `false`. Batch remains active. Transfers continue. When final payment completes (e.g., at 5 hours), `checkBatchCompletion()` returns `true`, settlement proceeds.

### Edge Case 6: Firestore Write Fails

**Scenario**: Admin adds customer, Firestore write fails (network error).
**Solution**: Catch exception, show error message to admin, do NOT add customer to in-memory list. Data remains consistent (not in Firestore, not in memory). Admin can retry.

### Edge Case 7: Firestore Read Fails on Startup

**Scenario**: App starts, Firestore read fails (offline).
**Solution**: Catch exception in `main()`, log error, allow app to start with empty data. Admin can add data when online, it will persist. On next restart, data loads normally.

### Edge Case 8: Duplicate Settlement Prevention

**Scenario**: Background timer triggers settlement at same moment admin manually triggers settlement.
**Solution**: Check `settledBatchIds.contains(batchToSettle)` before settling. If already present, throw `StateError`. First caller wins, second caller gets error (logged to audit log, does not crash app).

## Testing Strategy

### Unit Tests

**Testable**: `divideTarget()`, `calculateNextBatchTarget()` (pure functions).
**Method**: Verify expected division arrays for known targets, verify growth calculations.

### Integration Tests

**Test 1: Data Persistence Flow**
1. Mock Firestore with in-memory fake
2. Add customer via admin UI
3. Verify Firestore write called
4. Clear in-memory state
5. Call `loadSystemData()`
6. Verify customer reappears

**Test 2: Batch Period Enforcement**
1. Mock `DateTime.now()` to control time
2. Create batch with 4-hour period
3. Complete all payments
4. Advance time to 2 hours
5. Call `checkBatchCompletion()`
6. Verify no settlement occurs
7. Advance time to 4 hours
8. Call `checkBatchCompletion()`
9. Verify settlement occurs

**Test 3: Two-Batch Settlement**
1. Complete batch B-001
2. Verify B-002 created, B-001 not settled
3. Complete batch B-002
4. Verify B-001 settled, B-003 created
5. Complete batch B-003
6. Verify B-002 settled, B-004 created

**Test 4: Transfer Period**
1. Mock `DateTime.now()`
2. Assign order to reseller
3. Advance time by 59 minutes
4. Call `checkAndTransferExpiredOrders()`
5. Verify no transfer
6. Advance time by 2 more minutes (61 total)
7. Call `checkAndTransferExpiredOrders()`
8. Verify order transferred

### Manual Tests

**Test 5: End-to-End Persistence**
1. Real device with real Firestore
2. Admin adds 20 customers, 20 products
3. Admin sets batch period 4h, transfer period 1h
4. Admin logs out
5. Close app completely
6. Reopen app
7. Admin logs in
8. Verify all data present

**Test 6: Background Automation**
1. Real device
2. Set transfer period to 1 minute (for faster testing)
3. Assign order, don't confirm
4. Wait 1 minute
5. Verify order auto-transferred

## Invariants

**Invariant 1: Firestore and Memory Consistency**
- **Owner**: Write methods in `firestore_service.dart` and admin UI handlers in `main.dart`
- **Enforcement**: Write to Firestore first. Only update in-memory state after successful write. On write failure, throw error and do not update memory.

**Invariant 2: Batch Settlement Order**
- **Owner**: `settleCurrentBatch()` in `oms_demo.dart`
- **Enforcement**: Before settling, verify batch is not in `settledBatchIds`. After settling, add to `settledBatchIds`. Use mutex or single-threaded execution (Dart isolate guarantees this).

**Invariant 3: Transfer Period Timer**
- **Owner**: `checkAndTransferExpiredOrders()` in `oms_demo.dart`
- **Enforcement**: On transfer, update `order.createdAt` to current time. Each reseller gets full fresh period. Calculate elapsed time from current `createdAt`.

**Invariant 4: Batch Completion Timing**
- **Owner**: `checkBatchCompletion()` in `oms_demo.dart`
- **Enforcement**: Settlement can only occur when `(periodElapsed AND paymentsComplete)`. Never allow settlement if either condition is false.

## Logging

All critical operations log to `demoOms.auditLog`:
- Data persistence success/failure
- Batch completion checks (period status, payment status)
- Auto-transfers (which orders, which resellers)
- Auto-settlement (which batch settled, which batch created)
- Errors from background automation

Log format: `"[timestamp] [action] [details]"` inserted at index 0 (newest first).

## Deployment Notes

1. **Firestore Indexes**: No composite indexes required (all queries are simple document lookups or collection scans).
2. **Security Rules**: Ensure Firestore rules allow read/write for authenticated admin. Resellers should have read-only access to their own data.
3. **Data Migration**: No migration script needed (fresh start). Admin re-enters data, it persists going forward.
4. **Testing Environment**: Use Firestore Emulator for integration tests to avoid affecting production data.
5. **Performance**: All Firestore operations are single-document reads/writes (fast). No complex queries or large batch writes.
6. **Rollback Plan**: If persistence fails, revert to in-memory only by removing Firestore calls. Data loss issue returns but app remains functional.
