import 'dart:async';
import 'package:excel/excel.dart';

enum DemoOrderStatus { pending, processing, delivered, cancelled }

enum DemoPaymentStatus { unpaid, simulated }

enum DemoWithdrawalStatus { pending, processing, approved, cancelled }

class DemoSettings {
  bool systemEnabled = true;
  int profitRate = 30;
  int initialBatchTarget = 500;
  int growthRate = 50;
  int cycleHours = 36;
  int transferHours = 6;
}

class DemoProduct {
  DemoProduct({
    required this.title,
    required this.category,
    required this.description,
    required this.wholesalePrice,
  });

  final String title;
  final String category;
  final String description;
  final int wholesalePrice;

  int retailPrice(int profitRate) =>
      (wholesalePrice * (100 + profitRate) / 100).round();
}

class DemoCustomer {
  const DemoCustomer(this.name, this.mobile, this.address);

  final String name;
  final String mobile;
  final String address;
}

class DemoReseller {
  DemoReseller(this.name, this.mobile, this.email, {this.active = true});

  final String name;
  final String mobile;
  final String email;
  bool active;
  int capital = 0;
  int profit = 0;
}

class DemoOrder {
  DemoOrder({
    required this.id,
    required this.batchId,
    required this.customer,
    required this.product,
    required this.reseller,
    required this.wholesalePrice,
    required this.retailPrice,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String batchId;
  final DemoCustomer customer;
  final DemoProduct product;
  DemoReseller reseller;
  final int wholesalePrice;
  int retailPrice;
  DemoOrderStatus status = DemoOrderStatus.pending;
  DemoPaymentStatus paymentStatus = DemoPaymentStatus.unpaid;
  int transferNumber = 0;
  final DateTime createdAt; // Timestamp for transfer period tracking

  int get profit => retailPrice - wholesalePrice;
}

class DemoWithdrawal {
  DemoWithdrawal({
    required this.id,
    required this.reseller,
    required this.amount,
    required this.method,
    required this.account,
  });

  final String id;
  final DemoReseller reseller;
  final int amount;
  final String method;
  final String account;
  DemoWithdrawalStatus status = DemoWithdrawalStatus.pending;
  String? transactionReference;
}

class DemoBatch {
  DemoBatch({
    required this.id,
    required this.target,
    required this.division,
    this.previousTarget,
    this.growthRate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final int target;
  final List<int> division;
  final int? previousTarget;
  final int? growthRate;
  final DateTime createdAt; // Timestamp for cycle period tracking
}

class DemoWalletEntry {
  const DemoWalletEntry({
    required this.reference,
    required this.orderId,
    required this.capital,
    required this.profit,
    required this.reseller,
  });

  final String reference;
  final String orderId;
  final int capital;
  final int profit;
  final DemoReseller reseller;
}

class DemoOmsStore {
  DemoOmsStore() {
    // Start with empty data - Admin will add customers, products, resellers
    // DO NOT load demo data automatically - only on reset
  }

  void _seedInitialData() {
    // This method is used for "Reset System" functionality only
    // Clear all existing data first
    customers.clear();
    products.clear();
    resellers.clear();
    orders.clear();
    batches.clear();
    withdrawals.clear();
    walletEntries.clear();
    settledBatchIds.clear();
    auditLog.clear();
    
    // Reset counters
    currentBatchId = 'B-001';
    currentBatchTarget = settings.initialBatchTarget;
    _nextOrderNumber = 1001;
    _nextWithdrawalNumber = 5001;
    _nextTransactionNumber = 1;
    _customerCursor = 0;
    _productCursor = 0;
    _resellerCursor = 0;
    
    // Add demo data
    customers.addAll(const [
      DemoCustomer('Rahim Uddin', '01700000001', 'Mirpur, Dhaka'),
      DemoCustomer('Karim Ahmed', '01700000002', 'Dhanmondi, Dhaka'),
      DemoCustomer('Nadia Akter', '01700000003', 'Uttara, Dhaka'),
    ]);
    
    products.addAll([
      DemoProduct(
        title: 'Type-C Fast Charging Cable',
        category: 'Electronics',
        description: 'Fast charging and data transfer cable.',
        wholesalePrice: 200,
      ),
      DemoProduct(
        title: 'USB Fast Charger',
        category: 'Electronics',
        description: 'Compact USB wall charger.',
        wholesalePrice: 300,
      ),
      DemoProduct(
        title: 'Wireless Mouse',
        category: 'Electronics',
        description: 'Ergonomic wireless mouse.',
        wholesalePrice: 250,
      ),
    ]);
    
    resellers.addAll([
      DemoReseller('Rahim Store', '01710000001', 'rahim@example.com'),
      DemoReseller('Karim Shop', '01710000002', 'karim@example.com'),
      DemoReseller(
        'Nadia Store',
        '01710000003',
        'nadia@example.com',
        active: false,
      ),
    ]);
    
    auditLog.add('System reset with demo data.');
  }

  final settings = DemoSettings();
  final customers = <DemoCustomer>[];
  final products = <DemoProduct>[];
  final resellers = <DemoReseller>[];
  final orders = <DemoOrder>[];
  final batches = <DemoBatch>[];
  final withdrawals = <DemoWithdrawal>[];
  final walletEntries = <DemoWalletEntry>[];
  final auditLog = <String>[
    'Demo workspace initialized; no real payments processed.',
  ];
  final settledBatchIds = <String>{};

  // Background automation timer
  Timer? _automationTimer;
  
  String currentBatchId = 'B-001';
  int currentBatchTarget = 500;
  int _nextOrderNumber = 1001;
  int _nextWithdrawalNumber = 5001;
  int _nextTransactionNumber = 1;
  int _customerCursor = 0;
  int _productCursor = 0;
  int _resellerCursor = 0;

  // Start background automation (call this after app initialization)
  void startAutomation() {
    // Check every 1 minute for expired orders and cycle completion
    // This ensures timely auto-transfer and auto-settlement
    _automationTimer?.cancel(); // Cancel any existing timer
    _automationTimer = Timer.periodic(
      const Duration(minutes: 1), // Check every minute for responsiveness
      (timer) {
        if (settings.systemEnabled) {
          try {
            // Check for expired orders (transfer period)
            checkAndTransferExpiredOrders();
            
            // Check for cycle completion (settlement period)
            checkAndAutoSettleBatch();
          } catch (e) {
            auditLog.insert(
              0,
              'Background automation error: ${e.toString()}',
            );
          }
        }
      },
    );
    
    auditLog.insert(0, 'Background automation started (checks every 1 minute).');
  }
  
  // Stop background automation
  void stopAutomation() {
    _automationTimer?.cancel();
    _automationTimer = null;
    auditLog.insert(0, 'Background automation stopped.');
  }

  List<DemoReseller> get activeResellers =>
      resellers.where((reseller) => reseller.active).toList();

  int get batchPaidTotal => orders
      .where(
        (order) =>
            order.batchId == currentBatchId &&
            order.paymentStatus == DemoPaymentStatus.simulated &&
            order.status == DemoOrderStatus.processing,
      )
      .fold(0, (total, order) => total + order.wholesalePrice);

  bool get canSettleCurrentBatch =>
      !settledBatchIds.contains(currentBatchId) &&
      batchOrderTotal == currentBatchTarget &&
      batchPaidTotal == currentBatchTarget;

  int get batchOrderTotal => orders
      .where(
        (order) =>
            order.batchId == currentBatchId &&
            order.status != DemoOrderStatus.cancelled,
      )
      .fold(0, (total, order) => total + order.wholesalePrice);

  int paidTotalFor(String batchId) => orders
      .where(
        (order) =>
            order.batchId == batchId &&
            order.paymentStatus == DemoPaymentStatus.simulated &&
            (order.status == DemoOrderStatus.processing ||
                order.status == DemoOrderStatus.delivered),
      )
      .fold(0, (total, order) => total + order.wholesalePrice);

  int get resellerCapital =>
      resellers.fold(0, (total, reseller) => total + reseller.capital);

  int get resellerProfit =>
      resellers.fold(0, (total, reseller) => total + reseller.profit);

  int get totalWalletBalance {
    final credited = resellers.fold<int>(
      0,
      (total, reseller) => total + reseller.capital + reseller.profit,
    );
    final approved = withdrawals.where(
      (item) => item.status == DemoWithdrawalStatus.approved,
    );
    return credited - approved.fold(0, (total, item) => total + item.amount);
  }

  int get availableBalance =>
      totalWalletBalance -
      withdrawals
          .where(
            (item) =>
                item.status == DemoWithdrawalStatus.pending ||
                item.status == DemoWithdrawalStatus.processing,
          )
          .fold(0, (total, item) => total + item.amount);

  List<int> get currentDivision => divideTarget(currentBatchTarget);

  static int calculateNextBatchTarget(int previousTarget, int growthRate) {
    // Calculate growth amount: Previous Target × (Growth Rate %)
    final growthAmount = (previousTarget * growthRate / 100).round();
    final calculatedTarget = previousTarget + growthAmount;
    
    // Round up to nearest multiple of 50
    final roundedTarget = ((calculatedTarget + 49) ~/ 50) * 50;
    
    return roundedTarget;
  }

  static List<int> divideTarget(int target) {
    if (target <= 0 || target % 50 != 0) {
      return const [];
    }
    
    // Division strategy:
    // Start with base sequence: 50, 100, 150, 200, 250, 300, ...
    // If target matches the sum of consecutive multiples, use that
    // Otherwise, redistribute the remainder
    
    final division = <int>[];
    var remaining = target;
    var currentAmount = 50;
    
    // First, try to build with progressive amounts
    while (remaining > currentAmount) {
      division.add(currentAmount);
      remaining -= currentAmount;
      currentAmount += 50;
    }
    
    // Handle the remaining amount
    if (remaining > 0) {
      if (remaining >= 50) {
        // If remaining is 50 or more, add it as a separate division
        division.add(remaining);
      } else {
        // If remaining is less than 50, this target cannot be divided properly
        return const [];
      }
    }
    
    // Verify total equals target
    final total = division.fold<int>(0, (sum, amount) => sum + amount);
    if (total != target) {
      return const [];
    }
    
    // Verify all amounts are multiples of 50
    if (!division.every((amount) => amount % 50 == 0)) {
      return const [];
    }
    
    return division;
  }

  void createNextBatch({bool initial = false}) {
    if (!settings.systemEnabled) {
      throw StateError('The system is off; a new batch cannot be assigned.');
    }
    if (activeResellers.isEmpty) {
      throw StateError(
        'At least one active reseller is required to create a batch.',
      );
    }
    if (products.isEmpty || customers.isEmpty) {
      throw StateError(
        'At least one customer and product are required to create orders.',
      );
    }
    final previousTarget = initial ? null : currentBatchTarget;
    final appliedGrowthRate = initial ? null : settings.growthRate;
    final target = initial
        ? settings.initialBatchTarget
        : calculateNextBatchTarget(previousTarget!, appliedGrowthRate!);
    final division = divideTarget(target);
    if (division.isEmpty) {
      throw StateError(
        'Target ৳$target must equal the sum of consecutive ৳50 multiples, such as ৳50 + ৳100 + ৳150 + ৳200.',
      );
    }
    if (!initial) {
      currentBatchId =
          'B-${(int.parse(currentBatchId.substring(2)) + 1).toString().padLeft(3, '0')}';
      currentBatchTarget = target;
    }
    batches.add(
      DemoBatch(
        id: currentBatchId,
        target: target,
        division: List.unmodifiable(division),
        previousTarget: previousTarget,
        growthRate: appliedGrowthRate,
      ),
    );
    for (final amount in division) {
      final product = products[_productCursor++ % products.length];
      final customer = customers[_customerCursor++ % customers.length];
      final active = activeResellers;
      final reseller = active[_resellerCursor++ % active.length];
      orders.add(
        DemoOrder(
          id: 'ORD-${_nextOrderNumber++}',
          batchId: currentBatchId,
          customer: customer,
          product: product,
          reseller: reseller,
          wholesalePrice: amount,
          retailPrice: (amount * (100 + settings.profitRate) / 100).round(),
        ),
      );
    }
    auditLog.insert(
      0,
      'Orders assigned for demo batch $currentBatchId; target ৳$target.',
    );
  }

  void reconfigureInitialBatch(int target) {
    if (currentBatchId != 'B-001' ||
        orders.any(
          (order) =>
              order.batchId == currentBatchId &&
              order.paymentStatus != DemoPaymentStatus.unpaid,
        )) {
      throw StateError(
        'The initial target can only be changed before the first batch receives a payment confirmation.',
      );
    }
    final division = divideTarget(target);
    if (division.isEmpty) {
      throw StateError(
        'Target ৳$target must equal the sum of consecutive ৳50 multiples, such as ৳50 + ৳100 + ৳150 + ৳200.',
      );
    }
    if (products.isEmpty || customers.isEmpty || activeResellers.isEmpty) {
      throw StateError(
        'Products, customers, and active resellers are required to assign orders.',
      );
    }
    orders.removeWhere((order) => order.batchId == currentBatchId);
    batches.removeWhere((batch) => batch.id == currentBatchId);
    currentBatchTarget = target;
    settings.initialBatchTarget = target;
    batches.add(
      DemoBatch(
        id: currentBatchId,
        target: target,
        division: List.unmodifiable(division),
      ),
    );
    for (final amount in division) {
      final product = products[_productCursor++ % products.length];
      final customer = customers[_customerCursor++ % customers.length];
      final active = activeResellers;
      final reseller = active[_resellerCursor++ % active.length];
      orders.add(
        DemoOrder(
          id: 'ORD-${_nextOrderNumber++}',
          batchId: currentBatchId,
          customer: customer,
          product: product,
          reseller: reseller,
          wholesalePrice: amount,
          retailPrice: (amount * (100 + settings.profitRate) / 100).round(),
        ),
      );
    }
    auditLog.insert(
      0,
      'Initial demo batch target changed to ৳$target and orders reassigned.',
    );
  }

  void updateProfitRate(int rate) {
    if (![20, 30, 40].contains(rate)) {
      throw StateError('Profit rate must be 20%, 30%, or 40%.');
    }
    settings.profitRate = rate;
    for (final order in orders) {
      if (order.paymentStatus == DemoPaymentStatus.unpaid &&
          order.status == DemoOrderStatus.pending) {
        order.retailPrice = (order.wholesalePrice * (100 + rate) / 100).round();
      }
    }
    auditLog.insert(
      0,
      'Demo profit rate updated to $rate%; pending order prices recalculated.',
    );
  }

  DemoOrder? orderById(String? id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  void confirmPayment(DemoOrder order) {
    // Find and update only the specific order, not all orders
    final orderIndex = orders.indexWhere((o) => o.id == order.id);
    if (orderIndex == -1) {
      throw StateError('Order ${order.id} not found.');
    }
    
    final targetOrder = orders[orderIndex];
    
    if (targetOrder.batchId != currentBatchId) {
      throw StateError(
        'This order belongs to batch ${targetOrder.batchId}, not the current open batch $currentBatchId.',
      );
    }
    if (!settings.systemEnabled) {
      throw StateError(
        'The system is off; new order confirmations are disabled.',
      );
    }
    if (targetOrder.status != DemoOrderStatus.pending ||
        targetOrder.paymentStatus != DemoPaymentStatus.unpaid) {
      throw StateError(
        'This order is no longer awaiting payment confirmation.',
      );
    }
    
    // Update only this specific order
    targetOrder.paymentStatus = DemoPaymentStatus.simulated;
    targetOrder.status = DemoOrderStatus.processing;
    
    auditLog.insert(
      0,
      'DEMO ONLY: ${targetOrder.id} marked paid by simulated confirmation; no provider transaction verified.',
    );
    
    // Check if current batch is now complete and trigger auto-settlement
    if (batchOrderTotal == currentBatchTarget &&
        batchPaidTotal == currentBatchTarget) {
      try {
        settleCurrentBatch();
        auditLog.insert(
          0,
          'Auto-settlement triggered: current batch completed with payment of ${targetOrder.id}.',
        );
      } catch (e) {
        auditLog.insert(
          0,
          'Auto-settlement check after payment: ${e.toString()}',
        );
      }
    }
  }

  void transferOrder(DemoOrder order, {bool skipAutoCheck = false}) {
    _requireCurrentOpenOrder(order);
    if (!settings.systemEnabled) {
      throw StateError('The system is off; order transfers are paused.');
    }
    
    // Use internal transfer method
    _transferOrderDirect(order);
    
    // After manual transfer, check for other expired orders (unless skipped)
    if (!skipAutoCheck) {
      checkAndTransferExpiredOrders();
    }
  }

  // Check and automatically transfer orders that exceeded transfer period
  void checkAndTransferExpiredOrders() {
    if (!settings.systemEnabled) {
      return; // System is off, don't auto-transfer
    }
    
    final now = DateTime.now();
    final transferDuration = Duration(hours: settings.transferHours);
    
    // Find all pending unpaid orders that exceeded transfer period
    final expiredOrders = orders.where((order) {
      return order.status == DemoOrderStatus.pending &&
             order.paymentStatus == DemoPaymentStatus.unpaid &&
             order.batchId == currentBatchId &&
             now.difference(order.createdAt) >= transferDuration;
    }).toList();
    
    // Transfer each expired order (without recursion)
    for (final order in expiredOrders) {
      try {
        // Direct transfer without calling checkAndTransferExpiredOrders again
        _transferOrderDirect(order);
      } catch (e) {
        // If transfer fails (e.g., no active resellers), skip this order
        auditLog.insert(
          0,
          'Auto-transfer failed for ${order.id}: ${e.toString()}',
        );
      }
    }
    
    if (expiredOrders.isNotEmpty) {
      auditLog.insert(
        0,
        'Auto-transferred ${expiredOrders.length} expired orders after ${settings.transferHours}h.',
      );
    }
  }

  // Internal transfer method without auto-check (prevents recursion)
  void _transferOrderDirect(DemoOrder order) {
    if (order.status != DemoOrderStatus.pending) {
      throw StateError('Only an unpaid pending order can be transferred.');
    }
    final active = activeResellers;
    if (active.isEmpty) {
      throw StateError(
        'No active reseller is available to receive this order.',
      );
    }
    order.transferNumber++;
    var nextIndex = _resellerCursor % active.length;
    if (active.length > 1 && identical(active[nextIndex], order.reseller)) {
      nextIndex = (nextIndex + 1) % active.length;
    }
    
    final previousReseller = order.reseller.name;
    order.reseller = active[nextIndex];
    _resellerCursor = nextIndex + 1;
    
    auditLog.insert(
      0,
      '${order.id} transferred from $previousReseller to ${order.reseller.name} (transfer ${order.transferNumber}).',
    );
  }

  // Check if cycle period has passed and auto-settle if needed
  void checkAndAutoSettleBatch() {
    if (!settings.systemEnabled) {
      return; // System is off
    }
    
    // Find current batch
    final currentBatch = batches.firstWhere(
      (b) => b.id == currentBatchId,
      orElse: () => throw StateError('Current batch not found'),
    );
    
    final now = DateTime.now();
    final cycleDuration = Duration(hours: settings.cycleHours);
    
    // Check if cycle period has passed
    if (now.difference(currentBatch.createdAt) >= cycleDuration) {
      // Check if current batch is fully paid
      if (batchOrderTotal == currentBatchTarget &&
          batchPaidTotal == currentBatchTarget) {
        try {
          // Auto-settle previous batch and create next batch
          settleCurrentBatch();
          auditLog.insert(
            0,
            'Auto-settlement triggered after ${settings.cycleHours}h cycle period.',
          );
        } catch (e) {
          auditLog.insert(
            0,
            'Auto-settlement failed: ${e.toString()}',
          );
        }
      }
    }
  }

  bool settleCurrentBatch() {
    // NEW LOGIC: Settle the PREVIOUS batch when current batch completes
    // When current batch is fully paid, settle previous batch and create next batch
    
    if (!settings.systemEnabled) {
      throw StateError(
        'Turn the system on before settling and creating the next batch.',
      );
    }
    
    // Check if current batch is fully paid
    if (batchOrderTotal != currentBatchTarget ||
        batchPaidTotal != currentBatchTarget) {
      throw StateError(
        'Full settlement is unavailable until all ৳$currentBatchTarget of this batch are paid.',
      );
    }
    
    // Find previous batch to settle (the one before current)
    final currentBatchIndex = batches.indexWhere((b) => b.id == currentBatchId);
    if (currentBatchIndex == -1) {
      throw StateError('Current batch not found.');
    }
    
    // If this is the first batch (B-001), settle it directly
    String batchToSettle;
    if (currentBatchIndex == 0) {
      // First batch - settle current batch
      batchToSettle = currentBatchId;
    } else {
      // Find previous batch that hasn't been settled yet
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
    
    // Check if already settled
    if (settledBatchIds.contains(batchToSettle)) {
      throw StateError('Batch $batchToSettle has already been settled.');
    }
    
    // Get all paid orders from the batch to settle
    final settledOrders = orders
        .where(
          (order) =>
              order.batchId == batchToSettle &&
              order.status == DemoOrderStatus.processing &&
              order.paymentStatus == DemoPaymentStatus.simulated,
        )
        .toList();
    
    if (settledOrders.isEmpty) {
      throw StateError(
        'No paid orders found in batch $batchToSettle to settle.',
      );
    }
    
    // Mark batch as settled and credit reseller wallets
    settledBatchIds.add(batchToSettle);
    
    // Track credited orders to prevent duplicate credits
    final creditedOrderIds = walletEntries.map((e) => e.orderId).toSet();
    
    for (final order in settledOrders) {
      // Skip if already credited (duplicate prevention)
      if (creditedOrderIds.contains(order.id)) {
        auditLog.insert(
          0,
          'Skipped duplicate credit for order ${order.id}.',
        );
        continue;
      }
      
      order.status = DemoOrderStatus.delivered;
      order.reseller.capital += order.wholesalePrice;
      order.reseller.profit += order.profit;
      walletEntries.add(
        DemoWalletEntry(
          reference:
              'TX-${(_nextTransactionNumber++).toString().padLeft(5, '0')}',
          orderId: order.id,
          capital: order.wholesalePrice,
          profit: order.profit,
          reseller: order.reseller,
        ),
      );
    }
    
    auditLog.insert(
      0,
      'Demo batch $batchToSettle fully settled; ${settledOrders.length} orders credited. No real funds moved.',
    );
    
    // Now create the next batch
    createNextBatch();
    return true;
  }

  DemoWithdrawal requestWithdrawal({
    required DemoReseller reseller,
    required int amount,
    required String method,
    required String account,
  }) {
    if (amount <= 0 || amount > availableBalanceFor(reseller)) {
      throw StateError(
        'Withdrawal amount must be within the available balance.',
      );
    }
    final request = DemoWithdrawal(
      id: 'WD-${_nextWithdrawalNumber++}',
      reseller: reseller,
      amount: amount,
      method: method,
      account: account,
    );
    withdrawals.insert(0, request);
    auditLog.insert(
      0,
      'Demo withdrawal ${request.id} requested for ৳$amount; no disbursement made.',
    );
    return request;
  }

  int availableBalanceFor(DemoReseller reseller) {
    final credited = reseller.capital + reseller.profit;
    final requests = withdrawals.where((item) => item.reseller == reseller);
    final reserved = requests
        .where(
          (item) =>
              item.status == DemoWithdrawalStatus.pending ||
              item.status == DemoWithdrawalStatus.processing ||
              item.status == DemoWithdrawalStatus.approved,
        )
        .fold(0, (total, item) => total + item.amount);
    return credited - reserved;
  }

  void movePendingWithdrawalsToProcessing() {
    for (final request in withdrawals) {
      if (request.status == DemoWithdrawalStatus.pending) {
        moveWithdrawalToProcessing(request);
      }
    }
  }

  void moveWithdrawalToProcessing(DemoWithdrawal request) {
    if (!withdrawals.contains(request) ||
        request.status != DemoWithdrawalStatus.pending) {
      throw StateError('Only a pending withdrawal request can be processed.');
    }
    request.status = DemoWithdrawalStatus.processing;
    auditLog.insert(0, '${request.id} moved to processing in demo.');
  }

  void applyDemoDisbursementResult(
    DemoWithdrawal request, {
    required bool approved,
  }) {
    if (request.status != DemoWithdrawalStatus.processing) {
      throw StateError(
        'Only processing withdrawal requests can receive a result.',
      );
    }

    request.status = approved
        ? DemoWithdrawalStatus.approved
        : DemoWithdrawalStatus.cancelled;
    request.transactionReference =
        'DEMO-${(_nextTransactionNumber++).toString().padLeft(5, '0')}';
    auditLog.insert(
      0,
      'DEMO RESULT ONLY: ${request.id} ${approved ? 'approved' : 'cancelled'} with ${request.transactionReference}; provider not contacted.',
    );
  }

  void resetSystem() {
    customers.clear();
    products.clear();
    resellers.clear();
    orders.clear();
    batches.clear();
    withdrawals.clear();
    walletEntries.clear();
    auditLog.clear();
    settledBatchIds.clear();
    settings
      ..systemEnabled = true
      ..profitRate = 30
      ..initialBatchTarget = 500
      ..growthRate = 50
      ..cycleHours = 36
      ..transferHours = 6;
    currentBatchId = 'B-001';
    currentBatchTarget = settings.initialBatchTarget;
    _nextOrderNumber = 1001;
    _nextWithdrawalNumber = 5001;
    _nextTransactionNumber = 1;
    _customerCursor = 0;
    _productCursor = 0;
    _resellerCursor = 0;
    _seedInitialData();
    createNextBatch(initial: true);
    auditLog.insert(0, 'System reset to default data and settings.');
    
    // Restart automation after reset
    startAutomation();
  }

  void _requireCurrentOpenOrder(DemoOrder order) {
    if (!orders.contains(order) || order.batchId != currentBatchId) {
      throw StateError('This order does not belong to the active batch.');
    }
    if (settledBatchIds.contains(order.batchId)) {
      throw StateError('Orders in a settled batch cannot be changed.');
    }
  }
}

final demoOms = DemoOmsStore();

List<List<String>> parseCsvRows(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  final source = input.startsWith('\uFEFF') ? input.substring(1) : input;
  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (character == '"') {
      if (quoted && index + 1 < source.length && source[index + 1] == '"') {
        field.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted && character == ',') {
      row.add(field.toString().trim());
      field.clear();
    } else if (!quoted && (character == '\n' || character == '\r')) {
      row.add(field.toString().trim());
      field.clear();
      if (row.any((value) => value.isNotEmpty)) rows.add(row);
      row = <String>[];
      if (character == '\r' &&
          index + 1 < source.length &&
          source[index + 1] == '\n') {
        index++;
      }
    } else {
      field.write(character);
    }
  }
  if (quoted) throw const FormatException('CSV contains an unclosed quote.');
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString().trim());
    if (row.any((value) => value.isNotEmpty)) rows.add(row);
  }
  return rows;
}

List<List<String>> parseExcelRows(List<int> bytes) {
  if (bytes.isEmpty) {
    throw const FormatException('The selected Excel file is empty.');
  }
  final workbook = Excel.decodeBytes(bytes);
  final sheets = workbook.tables.values;
  if (sheets.isEmpty) {
    throw const FormatException('The Excel workbook contains no worksheets.');
  }
  final rows = sheets.first.rows
      .map(
        (row) =>
            row.map((cell) => cell?.value?.toString().trim() ?? '').toList(),
      )
      .where((row) => row.any((value) => value.isNotEmpty))
      .toList();
  if (rows.isEmpty) {
    throw const FormatException('The selected Excel worksheet is empty.');
  }
  return rows;
}

List<int> createCustomerExcelTemplate() {
  final workbook = Excel.createExcel();
  final sheet = workbook[workbook.getDefaultSheet()!];
  sheet.appendRow([
    TextCellValue('name'),
    TextCellValue('mobile_number'),
    TextCellValue('address'),
  ]);
  sheet.appendRow([
    TextCellValue('Sample Customer'),
    TextCellValue('01700000000'),
    TextCellValue('Dhaka'),
  ]);
  final bytes = workbook.encode();
  if (bytes == null) {
    throw StateError('Unable to create the customer Excel template.');
  }
  return bytes;
}

List<int> createProductExcelTemplate() {
  final workbook = Excel.createExcel();
  final sheet = workbook[workbook.getDefaultSheet()!];
  sheet.appendRow([
    TextCellValue('category'),
    TextCellValue('title'),
    TextCellValue('description'),
    TextCellValue('wholesale_price'),
  ]);
  sheet.appendRow([
    TextCellValue('Electronics'),
    TextCellValue('Sample Product'),
    TextCellValue('Replace this example with your product details.'),
    IntCellValue(500),
  ]);
  final bytes = workbook.encode();
  if (bytes == null) {
    throw StateError('Unable to create the product Excel template.');
  }
  return bytes;
}
