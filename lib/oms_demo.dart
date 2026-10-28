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
  });

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
  const DemoBatch({
    required this.id,
    required this.target,
    required this.division,
    this.previousTarget,
    this.growthRate,
  });

  final String id;
  final int target;
  final List<int> division;
  final int? previousTarget;
  final int? growthRate;
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
    _seedInitialData();
    createNextBatch(initial: true);
  }

  void _seedInitialData() {
    if (customers.isEmpty) {
      customers.addAll(const [
        DemoCustomer('Rahim Uddin', '01700000001', 'Mirpur, Dhaka'),
        DemoCustomer('Karim Ahmed', '01700000002', 'Dhanmondi, Dhaka'),
        DemoCustomer('Nadia Akter', '01700000003', 'Uttara, Dhaka'),
      ]);
    }
    if (products.isEmpty) {
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
    }
    if (resellers.isEmpty) {
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
    }
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

  String currentBatchId = 'B-001';
  int currentBatchTarget = 500;
  int _nextOrderNumber = 1001;
  int _nextWithdrawalNumber = 5001;
  int _nextTransactionNumber = 1;
  int _customerCursor = 0;
  int _productCursor = 0;
  int _resellerCursor = 0;

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
    final desiredTarget =
        (previousTarget * (100 + growthRate) / 5000).round() * 50;
    var previousTargetOption = 0;
    for (var count = 1; ; count++) {
      final targetOption = 25 * count * (count + 1);
      if (targetOption >= desiredTarget) {
        final distanceBelow = desiredTarget - previousTargetOption;
        final distanceAbove = targetOption - desiredTarget;
        return distanceAbove <= distanceBelow
            ? targetOption
            : previousTargetOption;
      }
      previousTargetOption = targetOption;
    }
  }

  static List<int> divideTarget(int target) {
    if (target <= 0 || target % 50 != 0) {
      return const [];
    }
    final division = <int>[];
    var total = 0;
    for (var amount = 50; total < target; amount += 50) {
      total += amount;
      division.add(amount);
    }
    return total == target ? division : const [];
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
    _requireCurrentOpenOrder(order);
    if (!settings.systemEnabled) {
      throw StateError(
        'The system is off; new order confirmations are disabled.',
      );
    }
    if (order.status != DemoOrderStatus.pending ||
        order.paymentStatus != DemoPaymentStatus.unpaid) {
      throw StateError(
        'This order is no longer awaiting payment confirmation.',
      );
    }
    order.paymentStatus = DemoPaymentStatus.simulated;
    order.status = DemoOrderStatus.processing;
    auditLog.insert(
      0,
      'DEMO ONLY: ${order.id} marked paid by simulated confirmation; no provider transaction verified.',
    );
  }

  void transferOrder(DemoOrder order) {
    _requireCurrentOpenOrder(order);
    if (!settings.systemEnabled) {
      throw StateError('The system is off; order transfers are paused.');
    }
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
    order.reseller = active[nextIndex];
    _resellerCursor = nextIndex + 1;
    auditLog.insert(
      0,
      '${order.id} transferred to ${order.reseller.name} (transfer ${order.transferNumber}).',
    );
  }

  bool settleCurrentBatch() {
    if (!settings.systemEnabled) {
      throw StateError(
        'Turn the system on before settling and creating the next batch.',
      );
    }
    if (settledBatchIds.contains(currentBatchId)) {
      throw StateError('This batch has already been settled.');
    }
    if (batchOrderTotal != currentBatchTarget ||
        batchPaidTotal != currentBatchTarget) {
      throw StateError(
        'Full settlement is unavailable until all ৳$currentBatchTarget of this batch are paid.',
      );
    }
    final nextTarget = calculateNextBatchTarget(
      currentBatchTarget,
      settings.growthRate,
    );
    final nextDivision = divideTarget(nextTarget);
    if (nextDivision.isEmpty ||
        products.isEmpty ||
        customers.isEmpty ||
        activeResellers.isEmpty) {
      throw StateError(
        nextDivision.isEmpty
            ? 'The next target ৳$nextTarget cannot be divided into consecutive ৳50 multiples.'
            : products.isEmpty
            ? 'Add at least one product before creating the next batch.'
            : customers.isEmpty
            ? 'Add at least one customer before creating the next batch.'
            : 'At least one active reseller is required for the next batch.',
      );
    }
    final batchId = currentBatchId;
    final settledOrders = orders
        .where(
          (order) =>
              order.batchId == batchId &&
              order.status == DemoOrderStatus.processing &&
              order.paymentStatus == DemoPaymentStatus.simulated,
        )
        .toList();
    if (settledOrders.fold(0, (sum, order) => sum + order.wholesalePrice) !=
        currentBatchTarget) {
      throw StateError(
        'Paid order total does not match the full batch target.',
      );
    }
    settledBatchIds.add(batchId);
    for (final order in settledOrders) {
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
      'Demo batch $batchId fully settled; ${settledOrders.length} orders credited. No real funds moved.',
    );
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
