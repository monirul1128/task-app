import 'package:cloud_firestore/cloud_firestore.dart';
import 'oms_demo.dart';

/// Firebase Firestore service for persistent data storage
class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collections
  static const String _customersCollection = 'customers';
  static const String _productsCollection = 'products';
  static const String _resellersCollection = 'resellers';
  static const String _ordersCollection = 'orders';
  static const String _batchesCollection = 'batches';
  static const String _settingsCollection = 'settings';
  static const String _adminCollection = 'admin';
  
  /// Save customer to Firestore
  static Future<void> saveCustomer(DemoCustomer customer) async {
    await _firestore.collection(_customersCollection).doc(customer.mobile).set({
      'name': customer.name,
      'mobile': customer.mobile,
      'address': customer.address,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  
  /// Load all customers from Firestore
  static Future<List<DemoCustomer>> loadCustomers() async {
    final snapshot = await _firestore.collection(_customersCollection).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return DemoCustomer(
        data['name'] as String,
        data['mobile'] as String,
        data['address'] as String,
      );
    }).toList();
  }
  
  /// Delete customer from Firestore
  static Future<void> deleteCustomer(String mobile) async {
    await _firestore.collection(_customersCollection).doc(mobile).delete();
  }
  
  /// Save product to Firestore
  static Future<void> saveProduct(DemoProduct product) async {
    await _firestore.collection(_productsCollection).doc(product.title).set({
      'title': product.title,
      'category': product.category,
      'description': product.description,
      'wholesalePrice': product.wholesalePrice,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  
  /// Load all products from Firestore
  static Future<List<DemoProduct>> loadProducts() async {
    final snapshot = await _firestore.collection(_productsCollection).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return DemoProduct(
        title: data['title'] as String,
        category: data['category'] as String,
        description: data['description'] as String,
        wholesalePrice: data['wholesalePrice'] as int,
      );
    }).toList();
  }
  
  /// Delete product from Firestore
  static Future<void> deleteProduct(String title) async {
    await _firestore.collection(_productsCollection).doc(title).delete();
  }
  
  /// Save reseller to Firestore
  static Future<void> saveReseller({
    required String email,
    required String name,
    required String mobile,
    required String password,
    bool active = true,
  }) async {
    await _firestore.collection(_resellersCollection).doc(email).set({
      'email': email,
      'name': name,
      'mobile': mobile,
      'password': password,
      'active': active,
      'capital': 0,
      'profit': 0,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  
  /// Load all resellers from Firestore
  static Future<Map<String, Map<String, dynamic>>> loadResellers() async {
    final snapshot = await _firestore.collection(_resellersCollection).get();
    final resellers = <String, Map<String, dynamic>>{};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      resellers[doc.id] = {
        'name': data['name'] as String,
        'mobile': data['mobile'] as String,
        'password': data['password'] as String,
        'active': data['active'] as bool? ?? true,
        'capital': data['capital'] as int? ?? 0,
        'profit': data['profit'] as int? ?? 0,
      };
    }
    
    return resellers;
  }
  
  /// Delete reseller from Firestore
  static Future<void> deleteReseller(String email) async {
    await _firestore.collection(_resellersCollection).doc(email).delete();
  }
  
  /// Update reseller wallet
  static Future<void> updateResellerWallet({
    required String email,
    required int capital,
    required int profit,
  }) async {
    await _firestore.collection(_resellersCollection).doc(email).update({
      'capital': capital,
      'profit': profit,
    });
  }
  
  /// Update reseller active status
  static Future<void> updateResellerStatus({
    required String email,
    required bool active,
  }) async {
    await _firestore.collection(_resellersCollection).doc(email).update({
      'active': active,
    });
  }
  
  /// Verify reseller login
  static Future<bool> verifyResellerLogin(String email, String password) async {
    final doc = await _firestore.collection(_resellersCollection).doc(email).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    return data['password'] == password;
  }
  
  /// Get reseller info
  static Future<Map<String, dynamic>?> getResellerInfo(String email) async {
    final doc = await _firestore.collection(_resellersCollection).doc(email).get();
    if (!doc.exists) return null;
    return doc.data();
  }
  
  /// Save admin credentials
  static Future<void> updateAdminEmail(String email) async {
    await _firestore.collection(_adminCollection).doc('credentials').set({
      'email': email,
    }, SetOptions(merge: true));
  }
  
  /// Get admin email
  static Future<String> getAdminEmail() async {
    final doc = await _firestore.collection(_adminCollection).doc('credentials').get();
    if (!doc.exists) return 'admin@bkh.com';
    return doc.data()?['email'] as String? ?? 'admin@bkh.com';
  }
  
  /// Save admin password
  static Future<void> updateAdminPassword(String password) async {
    await _firestore.collection(_adminCollection).doc('credentials').set({
      'password': password,
    }, SetOptions(merge: true));
  }
  
  /// Get admin password
  static Future<String> getAdminPassword() async {
    final doc = await _firestore.collection(_adminCollection).doc('credentials').get();
    if (!doc.exists) return 'admin123';
    return doc.data()?['password'] as String? ?? 'admin123';
  }
  
  /// Verify admin login
  static Future<bool> verifyAdminLogin(String email, String password) async {
    final adminEmail = await getAdminEmail();
    final adminPassword = await getAdminPassword();
    return email == adminEmail && password == adminPassword;
  }
  
  /// Reset password for reseller
  static Future<bool> resetResellerPassword({
    required String email,
    required String mobile,
    required String newPassword,
  }) async {
    final doc = await _firestore.collection(_resellersCollection).doc(email).get();
    if (!doc.exists) return false;
    
    final data = doc.data()!;
    if (data['mobile'] != mobile) return false;
    
    await _firestore.collection(_resellersCollection).doc(email).update({
      'password': newPassword,
    });
    
    return true;
  }
  
  /// Load all system data
  static Future<void> loadSystemData() async {
    final customers = await loadCustomers();
    final products = await loadProducts();
    final resellers = await loadResellers();
    
    // Load customers
    if (customers.isNotEmpty) {
      demoOms.customers.clear();
      demoOms.customers.addAll(customers);
    }
    
    // Load products
    if (products.isNotEmpty) {
      demoOms.products.clear();
      demoOms.products.addAll(products);
    }
    
    // Load resellers
    for (final entry in resellers.entries) {
      final email = entry.key;
      final data = entry.value;
      final exists = demoOms.resellers.any((r) => r.email == email);
      if (!exists) {
        final reseller = DemoReseller(
          data['name'] as String,
          data['mobile'] as String,
          email,
          active: data['active'] as bool? ?? true,
        );
        reseller.capital = data['capital'] as int? ?? 0;
        reseller.profit = data['profit'] as int? ?? 0;
        demoOms.resellers.add(reseller);
      }
    }
  }
  
  /// Clear all data (for reset)
  static Future<void> clearAllData() async {
    // Delete all customers
    final customersSnapshot = await _firestore.collection(_customersCollection).get();
    for (final doc in customersSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // Delete all products
    final productsSnapshot = await _firestore.collection(_productsCollection).get();
    for (final doc in productsSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // Don't clear resellers - they need to remain registered
  }
}
