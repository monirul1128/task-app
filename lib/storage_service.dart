import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'oms_demo.dart';

/// Persistent storage service for reseller authentication and system data
class StorageService {
  static const String _resellersKey = 'registered_resellers';
  static const String _customersKey = 'customers_data';
  static const String _productsKey = 'products_data';
  static const String _systemDataKey = 'system_data';
  
  /// Save registered reseller
  static Future<void> saveReseller({
    required String email,
    required String name,
    required String mobile,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final resellersJson = prefs.getString(_resellersKey) ?? '{}';
    final resellers = Map<String, dynamic>.from(jsonDecode(resellersJson));
    
    resellers[email] = {
      'name': name,
      'mobile': mobile,
      'password': password,
    };
    
    await prefs.setString(_resellersKey, jsonEncode(resellers));
    
    // Also add to demoOms.resellers if not already there
    final exists = demoOms.resellers.any((r) => r.email == email);
    if (!exists) {
      demoOms.resellers.add(DemoReseller(name, mobile, email));
    }
  }
  
  /// Get all registered resellers
  static Future<Map<String, Map<String, String>>> getResellers() async {
    final prefs = await SharedPreferences.getInstance();
    final resellersJson = prefs.getString(_resellersKey) ?? '{}';
    final resellersData = Map<String, dynamic>.from(jsonDecode(resellersJson));
    
    return resellersData.map((key, value) => MapEntry(
      key,
      Map<String, String>.from(value as Map),
    ));
  }
  
  /// Verify reseller login
  static Future<bool> verifyResellerLogin(String email, String password) async {
    final resellers = await getResellers();
    if (!resellers.containsKey(email)) return false;
    return resellers[email]!['password'] == password;
  }
  
  /// Get reseller info by email
  static Future<Map<String, String>?> getResellerInfo(String email) async {
    final resellers = await getResellers();
    return resellers[email];
  }
  
  /// Reset password for reseller
  static Future<bool> resetPassword({
    required String email,
    required String mobile,
    required String newPassword,
  }) async {
    final resellers = await getResellers();
    if (!resellers.containsKey(email)) return false;
    
    // Verify mobile number matches
    if (resellers[email]!['mobile'] != mobile) return false;
    
    // Update password
    final prefs = await SharedPreferences.getInstance();
    resellers[email]!['password'] = newPassword;
    await prefs.setString(_resellersKey, jsonEncode(resellers));
    
    return true;
  }
  
  /// Save customers data
  static Future<void> saveCustomers(List<DemoCustomer> customers) async {
    final prefs = await SharedPreferences.getInstance();
    final customersJson = customers.map((c) => {
      'name': c.name,
      'mobile': c.mobile,
      'address': c.address,
    }).toList();
    await prefs.setString(_customersKey, jsonEncode(customersJson));
  }
  
  /// Load customers data
  static Future<List<DemoCustomer>> loadCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final customersJson = prefs.getString(_customersKey);
    if (customersJson == null) return [];
    
    final customersList = List<Map<String, dynamic>>.from(jsonDecode(customersJson));
    return customersList.map((c) => DemoCustomer(
      c['name'] as String,
      c['mobile'] as String,
      c['address'] as String,
    )).toList();
  }
  
  /// Save products data
  static Future<void> saveProducts(List<DemoProduct> products) async {
    final prefs = await SharedPreferences.getInstance();
    final productsJson = products.map((p) => {
      'title': p.title,
      'category': p.category,
      'description': p.description,
      'wholesalePrice': p.wholesalePrice,
    }).toList();
    await prefs.setString(_productsKey, jsonEncode(productsJson));
  }
  
  /// Load products data
  static Future<List<DemoProduct>> loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final productsJson = prefs.getString(_productsKey);
    if (productsJson == null) return [];
    
    final productsList = List<Map<String, dynamic>>.from(jsonDecode(productsJson));
    return productsList.map((p) => DemoProduct(
      title: p['title'] as String,
      category: p['category'] as String,
      description: p['description'] as String,
      wholesalePrice: p['wholesalePrice'] as int,
    )).toList();
  }
  
  /// Save all system data
  static Future<void> saveSystemData() async {
    await saveCustomers(demoOms.customers);
    await saveProducts(demoOms.products);
  }
  
  /// Load all system data
  static Future<void> loadSystemData() async {
    final customers = await loadCustomers();
    final products = await loadProducts();
    final resellers = await getResellers();
    
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
    
    // Load resellers from storage
    for (final entry in resellers.entries) {
      final email = entry.key;
      final data = entry.value;
      final exists = demoOms.resellers.any((r) => r.email == email);
      if (!exists) {
        demoOms.resellers.add(DemoReseller(
          data['name']!,
          data['mobile']!,
          email,
        ));
      }
    }
  }
  
  /// Clear all data (for reset system)
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customersKey);
    await prefs.remove(_productsKey);
    // Don't clear resellers - they need to remain registered
  }
}
