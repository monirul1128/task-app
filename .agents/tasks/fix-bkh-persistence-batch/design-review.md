# Design Review: Fix BKH Business Manager Data Persistence and Batch Lifecycle

**Review Date**: 2024
**Reviewer**: Design Review Subagent
**Design Version**: Initial submission

---

## Executive Summary

**Verdict**: CHANGES_REQUESTED

**HIGH findings**: 3
**MEDIUM findings**: 5
**NIT findings**: 2

The design addresses the core requirements but contains critical unverified assumptions about existing code structures and missing error handling details that would block implementation.

---

## Findings

### HIGH-1: DemoOrder.createdAt is final, cannot be reassigned on transfer

**Location**: File 2 (`lib/oms_demo.dart`), `_transferOrderDirect()` modification

**Problem**: The design states "Modify: `checkAndTransferExpiredOrders()` to update order `createdAt` on transfer" and shows code `order.createdAt = DateTime.now();`. However, verification of the actual source shows `final DateTime createdAt;` in the `DemoOrder` class definition (line 78 of oms_demo.dart). Final fields cannot be reassigned in Dart.

**Fix**: Change the design to remove `final` from `createdAt` in the `DemoOrder` class:
```dart
class DemoOrder {
  DateTime createdAt; // Changed from final to var/non-final
  
  DemoOrder({
    // ...
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();
}
```

Then update `_transferOrderDirect()` to reset the timestamp:
```dart
void _transferOrderDirect(DemoOrder order) {
  // ... existing logic ...
  order.createdAt = DateTime.now(); // RESET TIMESTAMP
  order.reseller = active[nextIndex];
  // ... rest of logic ...
}
```

---

### HIGH-2: Settings persistence methods are missing, but design claims they're "currently missing"

**Location**: File 1 (`lib/firestore_service.dart`), Settings persistence methods

**Problem**: The design states "**Add**: Settings persistence methods (currently missing)" and lists new methods `saveSettings()` and `loadSettings()`. Verification confirms these methods do not exist in `firestore_service.dart`. However, the design does not specify the return type for `loadSettings()` or what happens when settings don't exist during initial load versus when network fails.

**Fix**: Clarify the `loadSettings()` signature and behavior:
```dart
static Future<Map<String, dynamic>?> loadSettings() async {
  try {
    final doc = await _firestore.collection(_settingsCollection).doc('config').get();
    if (!doc.exists) return null; // First run - no settings saved yet
    return doc.data(); // Returns map with profitRate, cycleHours, etc.
  } catch (e) {
    print('Failed to load settings: $e');
    return null; // Network error - caller uses defaults
  }
}

static Future<void> saveSettings(Map<String, dynamic> settings) async {
  await _firestore.collection(_settingsCollection).doc('config').set(settings);
}
```

And in `main()`:
```dart
final settingsMap = await FirestoreService.loadSettings();
if (settingsMap != null) {
  demoOms.settings.profitRate = settingsMap['profitRate'] as int;
  demoOms.settings.cycleHours = settingsMap['cycleHours'] as int;
  demoOms.settings.transferHours = settingsMap['transferHours'] as int;
  demoOms.settings.initialBatchTarget = settingsMap['initialBatchTarget'] as int;
  demoOms.settings.growthRate = settingsMap['growthRate'] as int;
  demoOms.settings.systemEnabled = settingsMap['systemEnabled'] as bool;
}
```

---

### HIGH-3: Batch settlement logic has race condition with duplicate prevention

**Location**: File 2 (`lib/oms_demo.dart`), `settleCurrentBatch()` rewrite

**Problem**: The design's new `settleCurrentBatch()` checks `settledBatchIds.contains(batchToSettle)` to prevent duplicate settlement. However, Edge Case 8 acknowledges "Background timer triggers settlement at same moment admin manually triggers settlement" but the proposed check happens AFTER the batch is identified. In Dart's single-threaded model, this should be safe, but the design does not explicitly state where the check occurs in the execution flow to prevent TOCTOU (time-of-check-time-of-use) issues if the method is called twice rapidly.

**Fix**: Move the duplicate check to the very beginning of `settleCurrentBatch()` before any other operations:
```dart
bool settleCurrentBatch() {
  // 0. DUPLICATE CHECK FIRST
  if (settledBatchIds.contains(currentBatchId)) {
    throw StateError('Batch $currentBatchId has already been settled.');
  }
  
  if (!settings.systemEnabled) {
    throw StateError('Turn the system on before settling...');
  }
  
  // Check if current batch is fully paid
  if (batchOrderTotal != currentBatchTarget || batchPaidTotal != currentBatchTarget) {
    throw StateError('Full settlement is unavailable...');
  }
  
  // Find previous batch to settle...
  // Rest of logic
}
```

But wait - the design shows checking `settledBatchIds.contains(batchToSettle)` where `batchToSettle` is the PREVIOUS batch, not current. Clarify: should we check if the PREVIOUS batch is already settled, or prevent settling the CURRENT batch multiple times? The logic flow needs to be unambiguous.

**Correct Fix**:
```dart
bool settleCurrentBatch() {
  if (!settings.systemEnabled) {
    throw StateError('Turn the system on before settling...');
  }
  
  // Check if current batch is fully paid
  if (batchOrderTotal != currentBatchTarget || batchPaidTotal != currentBatchTarget) {
    throw StateError('Full settlement is unavailable...');
  }
  
  // Find batch to settle (previous batch, or current if first)
  final currentBatchIndex = batches.indexWhere((b) => b.id == currentBatchId);
  String batchToSettle;
  
  if (currentBatchIndex == 0) {
    batchToSettle = currentBatchId;
  } else {
    // Find previous unsettled batch
    String? previousBatchId;
    for (int i = currentBatchIndex - 1; i >= 0; i--) {
      if (!settledBatchIds.contains(batches[i].id)) {
        previousBatchId = batches[i].id;
        break;
      }
    }
    if (previousBatchId == null) {
      throw StateError('No previous batch found to settle.');
    }
    batchToSettle = previousBatchId;
  }
  
  // DUPLICATE PREVENTION: Check immediately before settling
  if (settledBatchIds.contains(batchToSettle)) {
    throw StateError('Batch $batchToSettle has already been settled.');
  }
  
  // Settle the batch
  final settledOrders = orders.where(...).toList();
  settledBatchIds.add(batchToSettle);
  
  // ... rest of settlement logic
}
```

---

### MEDIUM-1: Batch period enforcement logic missing in background automation

**Location**: File 2 (`lib/oms_demo.dart`), `checkBatchCompletion()` method

**Problem**: The design introduces a new `checkBatchCompletion()` method that checks both `periodElapsed` and `paymentsComplete` conditions. However, the design shows this method should be called from `checkAndAutoSettleBatch()` but the existing `checkAndAutoSettleBatch()` already has its own period checking logic. The design doesn't explicitly state whether to REPLACE the existing logic or CALL the new method.

**Fix**: Clarify that `checkAndAutoSettleBatch()` should be completely replaced:
```dart
void checkAndAutoSettleBatch() {
  if (!settings.systemEnabled) return;
  
  // Use the new method
  checkBatchCompletion();
}

void checkBatchCompletion() {
  // ... as specified in design
}
```

Or combine them:
```dart
void checkAndAutoSettleBatch() {
  if (!settings.systemEnabled) return;
  
  final currentBatch = batches.firstWhere((b) => b.id == currentBatchId);
  final now = DateTime.now();
  final batchPeriod = Duration(hours: settings.cycleHours);
  
  final periodElapsed = now.difference(currentBatch.createdAt) >= batchPeriod;
  final paymentsComplete = (batchOrderTotal == currentBatchTarget) && 
                           (batchPaidTotal == currentBatchTarget);
  
  if (periodElapsed && paymentsComplete) {
    try {
      settleCurrentBatch();
      auditLog.insert(0, 'Auto-settlement: batch ${currentBatch.id} completed after ${settings.cycleHours}h period.');
    } catch (e) {
      auditLog.insert(0, 'Auto-settlement failed: ${e.toString()}');
    }
  }
}
```

---

### MEDIUM-2: Firestore write-through pattern conflicts with async operations in UI

**Location**: File 3 (`lib/main.dart`), Customer/Product add operations

**Problem**: The design shows adding `await FirestoreService.saveCustomer(customer)` before updating in-memory state. However, the code examples use `setState(() { demoOms.customers.add(customer); })` INSIDE the try block AFTER the await. This is incorrect: `setState` should be called in a synchronous context, and the state update should happen AFTER the await completes. The design is ambiguous about whether the in-memory update happens before or after the Firestore write completes.

**Fix**: Clarify the write-through pattern with correct async/await usage:
```dart
// Add customer button handler
Future<void> _addCustomer() async {
  try {
    // 1. Write to Firestore first
    await FirestoreService.saveCustomer(customer);
    
    // 2. Update in-memory state after successful write
    setState(() {
      demoOms.customers.add(customer);
    });
    
    _message('Customer added successfully');
  } catch (e) {
    _message('Failed to save customer: $e');
    // In-memory state NOT updated on error
  }
}
```

---

### MEDIUM-3: Batch Firestore persistence methods lack specification for `division` field

**Location**: File 1 (`lib/firestore_service.dart`), `saveBatch()` method

**Problem**: The design states `saveBatch` should save a `division` field as "array". However, the `DemoBatch` class has `final List<int> division`. The design doesn't specify whether this should be saved as a Firestore Array field `[50, 100, 150]` or as a comma-separated string `"50,100,150"` or some other format. This affects deserialization in `loadBatches()`.

**Fix**: Specify the exact Firestore structure:
```dart
static Future<void> saveBatch(DemoBatch batch, String status) async {
  await _firestore.collection(_batchesCollection).doc(batch.id).set({
    'id': batch.id,
    'target': batch.target,
    'division': batch.division, // Firestore natively supports List<int>
    'createdAt': Timestamp.fromDate(batch.createdAt),
    'status': status,
    'previousTarget': batch.previousTarget,
    'growthRate': batch.growthRate,
  });
}

static Future<List<Map<String, dynamic>>> loadBatches() async {
  final snapshot = await _firestore.collection(_batchesCollection).get();
  return snapshot.docs.map((doc) {
    final data = doc.data();
    return {
      'id': data['id'] as String,
      'target': data['target'] as int,
      'division': List<int>.from(data['division'] as List), // Cast from dynamic List
      'createdAt': (data['createdAt'] as Timestamp).toDate(),
      'status': data['status'] as String,
      'previousTarget': data['previousTarget'] as int?,
      'growthRate': data['growthRate'] as int?,
    };
  }).toList();
}
```

---

### MEDIUM-4: Missing specification for how to restore batches from Firestore on app restart

**Location**: File 2 (`lib/oms_demo.dart`), Edge Case 2 solution

**Problem**: The design states in Edge Case 2 that `loadBatches()` should reconstruct batch state, but there's no corresponding modification in File 2 showing WHERE this reconstruction happens. The design modifies `main()` to load settings but doesn't show loading batches. The existing `oms_demo.dart` doesn't have a method to restore batches from external data.

**Fix**: Add a new method to `DemoOmsStore` and call it from `main()`:
```dart
// In oms_demo.dart
void restoreBatchesFromFirestore(List<Map<String, dynamic>> batchData) {
  batches.clear();
  settledBatchIds.clear();
  
  for (final data in batchData) {
    final batch = DemoBatch(
      id: data['id'],
      target: data['target'],
      division: data['division'],
      createdAt: data['createdAt'],
      previousTarget: data['previousTarget'],
      growthRate: data['growthRate'],
    );
    batches.add(batch);
    
    if (data['status'] == 'settled') {
      settledBatchIds.add(batch.id);
    } else if (data['status'] == 'active') {
      currentBatchId = batch.id;
      currentBatchTarget = batch.target;
    }
  }
}

// In main.dart
Future<void> main() async {
  // ... Firebase initialization ...
  
  try {
    await FirestoreService.loadSystemData();
    
    // Load settings
    final settingsMap = await FirestoreService.loadSettings();
    if (settingsMap != null) {
      // ... apply settings ...
    }
    
    // Load batches
    final batchData = await FirestoreService.loadBatches();
    if (batchData.isNotEmpty) {
      demoOms.restoreBatchesFromFirestore(batchData);
    }
    
  } catch (e) {
    print('Firestore loading error: $e');
  }
  
  demoOms.startAutomation();
  runApp(const BechaKenaHubApp());
}
```

---

### MEDIUM-5: Wallet update persistence is mentioned but not implemented in settlement flow

**Location**: File 2 (`lib/oms_demo.dart`), `settleCurrentBatch()` rewrite

**Problem**: The design's rewritten `settleCurrentBatch()` shows updating reseller wallets in-memory:
```dart
order.reseller.capital += order.wholesalePrice;
order.reseller.profit += order.profit;
```
And includes the comment `// Update Firestore reseller wallet`. However, there's no actual call to `FirestoreService.updateResellerWallet()` in the code. The design states in FR8.2 "When reseller wallet changes (capital, profit), update Firestore immediately" but doesn't implement this in the settlement logic.

**Fix**: Add the Firestore wallet update call in the settlement loop:
```dart
for (final order in settledOrders) {
  order.status = DemoOrderStatus.delivered;
  order.reseller.capital += order.wholesalePrice;
  order.reseller.profit += order.profit;
  
  // Update Firestore immediately
  await FirestoreService.updateResellerWallet(
    email: order.reseller.email,
    capital: order.reseller.capital,
    profit: order.reseller.profit,
  );
  
  walletEntries.add(
    DemoWalletEntry(
      reference: 'TX-${(_nextTransactionNumber++).toString().padLeft(5, '0')}',
      orderId: order.id,
      capital: order.wholesalePrice,
      profit: order.profit,
      reseller: order.reseller,
    ),
  );
}
```

---

### NIT-1: Settings validation rules not enforced in saveSettings

**Location**: File 1 (`lib/firestore_service.dart`), `saveSettings()` method

**Problem**: The design specifies validation rules in the "Settings Validation" section but doesn't show WHERE this validation occurs. The `saveSettings()` method blindly writes to Firestore without validation. The UI might validate, but there's no enforcement at the service layer.

**Fix**: Add validation to `saveSettings()` or clarify that validation happens in the UI layer before calling `saveSettings()`:
```dart
static Future<void> saveSettings(Map<String, dynamic> settings) async {
  // Validate before saving
  final profitRate = settings['profitRate'] as int?;
  if (profitRate != null && ![20, 30, 40].contains(profitRate)) {
    throw ArgumentError('Profit rate must be 20, 30, or 40');
  }
  
  final cycleHours = settings['cycleHours'] as int?;
  if (cycleHours != null && cycleHours <= 0) {
    throw ArgumentError('Cycle hours must be greater than 0');
  }
  
  // ... validate other fields ...
  
  await _firestore.collection(_settingsCollection).doc('config').set(settings);
}
```

Or document: "Validation occurs in the Admin UI before calling `saveSettings()`. The service layer assumes pre-validated data."

---

### NIT-2: Audit log mentions lack timestamp format specification

**Location**: File 2 (`lib/oms_demo.dart`), Logging section

**Problem**: The design states log format is `"[timestamp] [action] [details]"` but the provided code examples show logs like `'Auto-settlement triggered after ${settings.cycleHours}h cycle period.'` without any timestamp prefix. This is inconsistent.

**Fix**: Either update the log format specification to match the implementation (no timestamp prefix), or show how to add timestamps:
```dart
auditLog.insert(
  0,
  '[${DateTime.now().toIso8601String()}] Auto-settlement triggered after ${settings.cycleHours}h cycle period.',
);
```

Or clarify: "Timestamps are not included in audit log entries. The format is simply `[action] [details]` with newest entries at index 0."

---

## Verified Assumptions

✅ **Firebase is initialized in main()**: Verified in requirements and design mentions `firebase_options.dart` exists.

✅ **FirestoreService has customer/product/reseller persistence methods**: Verified in `firestore_service.dart` - methods `saveCustomer`, `loadCustomers`, `deleteCustomer`, `saveProduct`, `loadProducts`, `deleteProduct`, `saveReseller`, `loadResellers`, `deleteReseller` all exist.

✅ **DemoBatch has createdAt field**: Verified in `oms_demo.dart` line 116 - `final DateTime createdAt;` exists.

✅ **DemoOrder has createdAt field**: Verified in `oms_demo.dart` line 78 - `final DateTime createdAt;` exists (but it's `final`, which is the problem in HIGH-1).

✅ **settledBatchIds set exists**: Verified in `oms_demo.dart` - `final settledBatchIds = <String>{};` exists.

✅ **Background automation timer exists**: Verified in `oms_demo.dart` - `startAutomation()` method with `Timer.periodic` exists.

✅ **checkAndTransferExpiredOrders() exists**: Verified in `oms_demo.dart` around line 596.

✅ **checkAndAutoSettleBatch() exists**: Verified in `oms_demo.dart` around line 663.

✅ **_transferOrderDirect() exists**: Verified in `oms_demo.dart` line 636.

✅ **Round-robin reseller selection uses _resellerCursor**: Verified in `oms_demo.dart` - cursor-based selection exists.

✅ **Admin UI location assumption**: Design states "around line 4500-5500" for customer/product widgets in main.dart - this is a reasonable assumption for a large Flutter file.

---

## Unverified/Wrong Assumptions

❌ **DemoOrder.createdAt is mutable**: WRONG - It's `final` in the actual code, cannot be reassigned (HIGH-1).

❌ **Settings persistence methods exist**: WRONG - `saveSettings()` and `loadSettings()` do NOT exist in `firestore_service.dart` (HIGH-2).

❌ **Batch persistence methods exist**: WRONG - `saveBatch()`, `loadBatches()`, `updateBatchStatus()` do NOT exist in `firestore_service.dart` (acknowledged by design as "new methods", but needs specification detail in MEDIUM-3 and MEDIUM-4).

❌ **createNextBatch() saves to Firestore**: WRONG - The existing `createNextBatch()` does NOT call any Firestore methods. The design shows adding this, but doesn't mark it as an async method change (signature must change to `Future<void> createNextBatch()`).

❌ **settleCurrentBatch() updates Firestore**: WRONG - The existing method doesn't persist anything. The design needs to change the signature to `Future<bool> settleCurrentBatch()` to support async Firestore operations (affects all callers).

⚠️ **loadSystemData() loads settings**: PARTIALLY WRONG - The existing `loadSystemData()` in `firestore_service.dart` does NOT load settings, only customers/products/resellers. The design adds this but needs to modify the existing method, not just call a new method from main.

---

## Additional Concerns

### Concern 1: Async/Await Cascade

Multiple methods need to become async because they now call Firestore:
- `createNextBatch()` → calls `saveBatch()`
- `settleCurrentBatch()` → calls `updateBatchStatus()` and `updateResellerWallet()`
- All admin UI handlers → already use async patterns

The design doesn't consistently show `async`/`await` keywords in method signatures. Clarify which methods change from sync to async.

### Concern 2: Transaction Safety

The design doesn't address Firestore transaction boundaries. If `settleCurrentBatch()` fails halfway through (after settling some orders but not all), the system could be in an inconsistent state. Consider using Firestore transactions for batch settlement:
```dart
await _firestore.runTransaction((transaction) async {
  // Update batch status
  // Update all order statuses
  // Update all reseller wallets
});
```

### Concern 3: Order Persistence

Requirements FR4 mentions batch persistence, but orders are never persisted to Firestore in this design. If the app restarts mid-batch, all order assignments are lost. Is this intentional? The design should clarify whether orders need persistence or if they're considered ephemeral (recreated on restart).

---

## Recommendation

The design is fundamentally sound and addresses the core requirements. However, the HIGH-severity findings (especially the `final` field issue and missing method specifications) would block implementation. The MEDIUM findings would cause confusion during coding and potential bugs.

**Required Actions**:
1. Fix HIGH-1: Change `DemoOrder.createdAt` from `final` to mutable
2. Fix HIGH-2: Provide complete `saveSettings()` and `loadSettings()` signatures with error handling
3. Fix HIGH-3: Clarify duplicate prevention check placement in settlement flow
4. Fix MEDIUM-1 through MEDIUM-5: Add missing method specifications and clarify ambiguous integration points

Once these issues are resolved, the design will be implementation-ready.

---

## Approval Criteria

- [ ] All HIGH findings resolved
- [ ] All MEDIUM findings resolved
- [x] Architecture decisions are sound
- [x] Functional requirements coverage is complete
- [x] Edge cases are identified

**Status**: CHANGES_REQUESTED (3 HIGH + 5 MEDIUM findings must be addressed)
