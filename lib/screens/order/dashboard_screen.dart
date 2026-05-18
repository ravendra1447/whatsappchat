import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/local_auth_service.dart';
import '../../services/admin_dashboard_service.dart';
import '../../config.dart';
import 'all_orders_screen.dart';
import 'admin_all_orders_screen.dart';
import 'waiting_payment_orders_screen.dart';
import 'ready_shipment_orders_screen.dart';
import 'shipped_orders_screen.dart';
import 'pending_orders_screen.dart';
import 'delivered_orders_screen.dart';
import '../role/role_management_screen.dart';
import '../admin/product_management_screen.dart';
import '../profile_company/company_registration_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? stats;
  Map<String, dynamic>? codStats;
  Map<String, dynamic>? pickupStats;
  bool isLoading = true;
  String? errorMessage;
  late TabController _tabController;
  
  // Admin dashboard specific variables
  bool isAdmin = false;
  Map<String, dynamic>? adminData;
  List<Map<String, dynamic>>? adminWebsites;
  Map<String, dynamic>? adminStats;
  
  // Order status counts
  Map<String, int> statusCounts = {
    'Pending': 0,
    'Waiting Payment': 0,
    'Ready Shipment': 0,
    'Shipped': 0,
    'Delivered': 0,
  };
  
  // Filter variables
  String _selectedTimeFilter = 'Pending'; // Changed from 'Last 30 Days'
  String _selectedWebsite = 'BangkokMart'; // Default website
  String _selectedDashboardView = 'Overview'; // Default dashboard view

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _checkAdminAndFetchData();
    _fetchOrderStatusCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Check if user is admin and fetch appropriate data
  Future<void> _checkAdminAndFetchData() async {
    try {
      final adminStatus = await AdminDashboardService.isAdminUser();
      print('🔍 Admin Status Check Result: $adminStatus');
      setState(() {
        isAdmin = adminStatus;
        print('🔍 Set isAdmin state to: $isAdmin');
      });
      
      // Use local variable instead of state to avoid race condition
      if (adminStatus) {
        print('🔍 Fetching admin dashboard data...');
        await _fetchAdminDashboardData();
      } else {
        print('🔍 Fetching regular dashboard data...');
        await _fetchDashboardStats();
      }
    } catch (e) {
      print('Error checking admin status: $e');
      await _fetchDashboardStats(); // Fallback to regular dashboard
    }
  }

  // Fetch order status counts
  Future<void> _fetchOrderStatusCounts() async {
    try {
      print('=== FETCHING ORDER STATUS COUNTS ===');
      
      // Use admin dashboard orders to calculate exact counts
      if (isAdmin && adminData != null && adminData!['orders'] != null) {
        final orders = adminData!['orders'] as List;
        print('Using admin dashboard orders data, total orders: ${orders.length}');
        
        // Calculate counts from admin dashboard orders
        final counts = {
          'Pending': 0,
          'Waiting for Payment': 0,
          'Ready for Shipment': 0,
          'Shipped': 0,
          'Delivered': 0,
        };
        
        for (final order in orders) {
          final status = order['order_status']?.toString() ?? '';
          
          // Skip cancelled orders from counting
          if (status == 'Cancelled') {
            continue;
          }
          
          if (status == 'Pending') {
            counts['Pending'] = counts['Pending']! + 1;
          } else if (status == 'Waiting for Payment') {
            counts['Waiting for Payment'] = counts['Waiting for Payment']! + 1;
          } else if (status == 'Ready for Shipment') {
            counts['Ready for Shipment'] = counts['Ready for Shipment']! + 1;
          } else if (status == 'Shipped') {
            counts['Shipped'] = counts['Shipped']! + 1;
          } else if (status == 'Delivered') {
            counts['Delivered'] = counts['Delivered']! + 1;
          }
        }
        
        print('📊 Exact counts from admin orders: $counts');
        
        // Use calculated values for dynamic updates
        setState(() {
          statusCounts['Pending'] = counts['Pending']!;
          statusCounts['Waiting Payment'] = counts['Waiting for Payment']!;
          statusCounts['Ready Shipment'] = counts['Ready for Shipment']!;
          statusCounts['Shipped'] = counts['Shipped']!;
          statusCounts['Delivered'] = counts['Delivered']!;
        });
        
        print('✅ Final status counts (dynamic): $statusCounts');
        print('� These counts will update automatically when database changes');
      } else {
        print('❌ Admin data not available');
      }
    } catch (e) {
      print('❌ Error fetching order status counts: $e');
      // Don't set demo values - keep 0 to show there's an issue
    }
  }

  // Refresh order status counts
  Future<void> _refreshOrderStatusCounts() async {
    await _fetchOrderStatusCounts();
  }

  // Update order status counts dynamically when order status changes
  void _updateOrderStatusCount(String oldStatus, String newStatus) {
    setState(() {
      // Decrease count from old status
      if (statusCounts.containsKey(oldStatus) && statusCounts[oldStatus]! > 0) {
        statusCounts[oldStatus] = statusCounts[oldStatus]! - 1;
      }
      // Increase count for new status
      if (statusCounts.containsKey(newStatus)) {
        statusCounts[newStatus] = statusCounts[newStatus]! + 1;
      }
    });
  }

  // Method to be called from order detail screens when status changes
  void onOrderStatusChanged(String oldStatus, String newStatus) {
    _updateOrderStatusCount(oldStatus, newStatus);
  }

  // Fetch admin dashboard data
  Future<void> _fetchAdminDashboardData() async {
    try {
      print('Fetching admin dashboard data...');
      
      final data = await AdminDashboardService.getAdminDashboardData();
      
      setState(() {
        adminData = data;
        adminStats = data['stats'];
        adminWebsites = (data['websites'] as List?)?.cast<Map<String, dynamic>>();
        isLoading = false;
        errorMessage = null;
      });
      
      print('Admin dashboard data loaded successfully');
      print('Websites: ${adminWebsites?.length}');
      print('Stats: $adminStats');
      
      // Fetch order status counts after admin data is loaded
      await _fetchOrderStatusCounts();
      
    } catch (e) {
      print('Admin Dashboard Error: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Admin dashboard error: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchDashboardStats() async {
    try {
      print('Fetching dashboard stats using working endpoint...');
      
      final userId = LocalAuthService.getUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      final response = await http.get(
        Uri.parse('${Config.baseNodeApiUrl}/orders/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('Dashboard Response status: ${response.statusCode}');
      print('Dashboard Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] && responseData['orders'] != null) {
          final orders = responseData['orders'] as List;
          
          // Filter orders by payment method
          final codOrders = orders.where((order) => 
            order['payment_method']?.toString().toLowerCase() == 'cod'
          ).toList();
          
          final pickupOrders = orders.where((order) => 
            order['payment_method']?.toString().toLowerCase() != 'cod'
          ).toList();
          
          // Calculate stats for all orders
          stats = _calculateStats(orders);
          
          // Calculate stats for COD orders
          codStats = _calculateStats(codOrders);
          
          // Calculate stats for Pickup & Delivery orders
          pickupStats = _calculateStats(pickupOrders);
          
          setState(() {
            isLoading = false;
            errorMessage = null;
          });
        } else {
          throw Exception('API returned failure');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Dashboard API Error: $e');
      // Show demo data when API fails
      setState(() {
        stats = _getDemoStats();
        codStats = _getDemoStats();
        pickupStats = _getDemoStats();
        isLoading = false;
        errorMessage = 'Server not available - Using demo data';
      });
    }
  }

  Map<String, dynamic> _calculateStats(List orders) {
    final totalOrders = orders.length;
    
    // Calculate today's orders
    final todayOrders = orders.where((order) {
      try {
        final orderDate = DateTime.parse(order['order_date']);
        final today = DateTime.now();
        return orderDate.day == today.day && 
               orderDate.month == today.month && 
               orderDate.year == today.year;
      } catch (e) {
        return false;
      }
    }).length;
    
    // Calculate yesterday's orders
    final yesterdayOrders = orders.where((order) {
      try {
        final orderDate = DateTime.parse(order['order_date']);
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        return orderDate.day == yesterday.day && 
               orderDate.month == yesterday.month && 
               orderDate.year == yesterday.year;
      } catch (e) {
        return false;
      }
    }).length;
    
    // Calculate cancelled orders
    final cancelledOrders = orders.where((o) => 
      o['order_status']?.toString().toLowerCase() == 'cancelled'
    ).length;
    
    // Calculate total revenue
    final totalRevenue = orders.fold<double>(0, (sum, order) {
      final amount = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0;
      return sum + amount;
    });
    
    return {
      'todayOrders': todayOrders,
      'yesterdayOrders': yesterdayOrders,
      'totalOrders': totalOrders,
      'cancelledOrders': cancelledOrders,
      'totalRevenue': totalRevenue,
      'weekRevenue': 0, // TODO: Calculate this week revenue
      'monthRevenue': 0, // TODO: Calculate this month revenue
    };
  }

  Map<String, dynamic> _getDemoStats() {
    return {
      'todayOrders': 0,
      'yesterdayOrders': 0,
      'totalOrders': 0,
      'cancelledOrders': 0,
      'totalRevenue': 0,
      'weekRevenue': 0,
      'monthRevenue': 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 Build method - isAdmin: $isAdmin, isLoading: $isLoading');
    
    // Show Access Denied immediately for non-admins (even during loading)
    if (!isAdmin && !isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          iconTheme: const IconThemeData(
            color: Colors.black,
          ),
        ),
        body: _buildAccessDeniedView(),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.black,
        ),
        actions: [
          // Company Registration Icon
          IconButton(
            icon: Icon(
              Icons.business_center_outlined,
              color: Colors.green.shade700,
              size: 24,
            ),
            onPressed: () async {
              await _showCompanyRegistrationDialog();
            },
            tooltip: 'Company Registration',
          ),
          if (isAdmin)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.purple.shade700),
              onSelected: (value) {
                if (value == 'roles') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RoleManagementScreen(),
                    ),
                  );
                } else if (value == 'products') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductManagementScreen(),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'roles',
                  child: Row(
                    children: [
                      Icon(Icons.manage_accounts, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('Manage Roles'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'products',
                  child: Row(
                    children: [
                      Icon(Icons.inventory, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Manage Products'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkAdminAndFetchData();
          await _refreshOrderStatusCounts();
        },
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    if (errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Order Status Tabs - Slidable with Counting Badges
                    Container(
                      height: 90,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 5,
                        itemBuilder: (context, index) {
                          final statuses = ['Pending', 'Waiting Payment', 'Ready Shipment', 'Shipped', 'Delivered'];
                          final colors = [Colors.orange, Colors.blue, Colors.purple, Colors.green, Colors.teal];
                          final status = statuses[index];
                          final color = colors[index];
                          final count = statusCounts[status] ?? 0;
                          
                          print('🏷️ Building UI badge: $status = $count');
                          
                          return Container(
                            width: 85,
                            margin: const EdgeInsets.all(4),
                            child: Stack(
                              children: [
                                // Main status box
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: color.withOpacity(0.3)),
                                    ),
                                    child: InkWell(
                                      onTap: () => _navigateToOrderStatusScreen(status),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _getStatusIcon(status),
                                            size: 18,
                                            color: color,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                              color: color,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Counting badge positioned above the box
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(0.3),
                                            spreadRadius: 1,
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        count.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Main Dashboard Content - only for admin users
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (isAdmin)
                      _buildMainDashboardContent(),
                  ],
                ),
              ),
      ),
    );
  }

  // Build main dashboard content (replaces TabBarView)
  Widget _buildMainDashboardContent() {
    return Column(
      children: [
        // Tab Selector for Overview, COD, Pickup & Delivery
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchDashboardView('Overview'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedDashboardView == 'Overview' ? Colors.purple : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Overview',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedDashboardView == 'Overview' ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchDashboardView('COD'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedDashboardView == 'COD' ? Colors.purple : Colors.transparent,
                    ),
                    child: Text(
                      'COD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedDashboardView == 'COD' ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchDashboardView('Pickup & Delivery'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedDashboardView == 'Pickup & Delivery' ? Colors.purple : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Pickup & Delivery',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedDashboardView == 'Pickup & Delivery' ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Dashboard Content Based on Selection
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (isAdmin)
          _buildAdminDashboardView(adminStats, _selectedDashboardView)
        else
          _buildAccessDeniedView(),
      ],
    );
  }

  // Build Access Denied view for regular users
  Widget _buildAccessDeniedView() {
    print('🔍 Building Access Denied view - isAdmin: $isAdmin');
    print('🚫 Access Denied: Regular user trying to access dashboard');
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.admin_panel_settings,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'Access Denied',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You don\'t have permission to access the dashboard.\n\nPlease contact your admin for assistance.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Admin access required',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Switch dashboard view
  void _switchDashboardView(String view) {
    setState(() {
      _selectedDashboardView = view;
    });
  }

  // Get status icon
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.pending;
      case 'Waiting Payment':
        return Icons.payment;
      case 'Ready Shipment':
        return Icons.local_shipping;
      case 'Shipped':
        return Icons.inventory;
      case 'Delivered':
        return Icons.check_circle;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[400],
          ),
          const SizedBox(height: 20),
          Text(
            errorMessage ?? 'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _fetchDashboardStats,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Text(
        'No data available',
        style: TextStyle(
          fontSize: 18,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDashboardView(Map<String, dynamic>? currentStats, String title) {
    if (currentStats == null) {
      return _buildEmptyView();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Orders Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Orders',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (title == 'Overview')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTimeFilter,
                      icon: Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]),
                      items: const [
                        DropdownMenuItem(value: 'Pending', child: Text('Pending', style: TextStyle(fontSize: 14))),
                        DropdownMenuItem(value: 'Today', child: Text('Today', style: TextStyle(fontSize: 14))),
                        DropdownMenuItem(value: 'Yesterday', child: Text('Yesterday', style: TextStyle(fontSize: 14))),
                        DropdownMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days', style: TextStyle(fontSize: 14))),
                        DropdownMenuItem(value: 'Last 30 Days', child: Text('Last 30 Days', style: TextStyle(fontSize: 14))),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            _selectedTimeFilter = value;
                          });
                          _navigateToOrdersWithFilter(value);
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Today's and Yesterday's Orders Row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminAllOrdersScreen(
                          orders: [],
                          initialFilter: 'today',
                        ),
                      ),
                    );
                  },
                  child: _buildOrderCard(
                    'Today\'s Orders',
                    currentStats['todayOrders'].toString(),
                    Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminAllOrdersScreen(
                          orders: [],
                          initialFilter: 'yesterday',
                        ),
                      ),
                    );
                  },
                  child: _buildOrderCard(
                    'Yesterday\'s Orders',
                    currentStats['yesterdayOrders'].toString(),
                    Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Total Orders (Clickable only in Overview)
          if (title == 'Overview')
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AllOrdersScreen(),
                  ),
                );
              },
              child: _buildOrderCard(
                'Total Orders',
                currentStats['totalOrders'].toString(),
                Colors.green,
                isClickable: true,
              ),
            )
          else
            _buildOrderCard(
              'Total Orders',
              currentStats['totalOrders'].toString(),
              Colors.green,
            ),
          
          const SizedBox(height: 16),
          
          // Cancelled Orders
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminAllOrdersScreen(
                    orders: [],
                    initialFilter: 'cancelled',
                  ),
                ),
              );
            },
            child: _buildOrderCard(
              'Cancelled Orders',
              currentStats['cancelledOrders'].toString(),
              Colors.red,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Summary Lines
          _buildSummaryLine('Total Freight Charges', '₹0'),
          _buildSummaryLine('Average Shipping Cost', '₹0'),
          
          const SizedBox(height: 24),
          
          // Revenue Section
          const Text(
            'Revenue',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          
          // Revenue Cards
          Row(
            children: [
              Expanded(
                child: _buildRevenueCard(
                  'Lifetime',
                  '₹${currentStats['totalRevenue'].toString()}',
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRevenueCard(
                  'This Week',
                  '₹${currentStats['weekRevenue'].toString()}',
                  Colors.teal,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          _buildRevenueCard(
            'This Month',
            '₹${currentStats['monthRevenue'].toString()}',
            Colors.indigo,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(String title, String value, Color color, {bool isClickable = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              if (isClickable)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[600],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Show admin orders screen
  void _showAdminOrders() {
    if (adminData != null && adminData!['orders'] != null) {
      final orders = adminData!['orders'] as List;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminAllOrdersScreen(orders: orders),
        ),
      );
    }
  }

  // Navigate to orders with time filter
  void _navigateToOrdersWithFilter(String filter) {
    if (isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminAllOrdersScreen(
            orders: adminData?['orders'] ?? [],
            initialFilter: filter.toLowerCase(),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AllOrdersScreen(),
        ),
      );
    }
  }

  // Navigate to orders with website filter
  void _navigateToOrdersWithWebsite(String website) {
    if (isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminAllOrdersScreen(
            orders: adminData?['orders'] ?? [],
            initialFilter: _selectedTimeFilter.toLowerCase(),
            websiteFilter: website,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AllOrdersScreen(),
        ),
      );
    }
  }

  // Quick navigation to order status screens
  void _navigateToOrderStatusScreen(String screenName) {
    switch (screenName) {
      case 'Pending':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PendingOrdersScreen(
              onOrderStatusChanged: (oldStatus, newStatus) => onOrderStatusChanged(oldStatus, newStatus),
            ),
          ),
        );
        break;
      case 'Waiting Payment':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingPaymentOrdersScreen(
              onOrderStatusChanged: (oldStatus, newStatus) => onOrderStatusChanged(oldStatus, newStatus),
            ),
          ),
        );
        break;
      case 'Ready Shipment':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReadyShipmentOrdersScreen(
              onOrderStatusChanged: (oldStatus, newStatus) => onOrderStatusChanged(oldStatus, newStatus),
            ),
          ),
        );
        break;
      case 'Shipped':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShippedOrdersScreen(
              onOrderStatusChanged: (oldStatus, newStatus) => onOrderStatusChanged(oldStatus, newStatus),
            ),
          ),
        );
        break;
      case 'Delivered':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeliveredOrdersScreen(
              onOrderStatusChanged: (oldStatus, newStatus) => onOrderStatusChanged(oldStatus, newStatus),
            ),
          ),
        );
        break;
      default:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AllOrdersScreen(),
          ),
        );
    }
  }

  // Helper method to get status color
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Build order status tab content
  Widget _buildOrderStatusTab(String status) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.purple.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            '$status Orders',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Click below to view all $status orders',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _navigateToOrderStatusScreen(status),
            icon: const Icon(Icons.list),
            label: Text('View $status Orders'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Admin Dashboard View
  Widget _buildAdminDashboardView(Map<String, dynamic>? currentStats, String title) {
    if (currentStats == null) {
      return _buildEmptyView();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Admin Badge and Websites Info
          if (isAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                border: Border.all(color: Colors.purple.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.purple.shade700, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  if (adminWebsites != null && adminWebsites!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Managed Websites:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...adminWebsites!.map((website) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.link, color: Colors.purple.shade600, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${website['website_name']} (${website['domain']})',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ],
                ],
              ),
            ),
          
          // Orders Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Orders',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (title == 'Admin Dashboard')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedWebsite,
                      icon: Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]),
                      items: const [
                        DropdownMenuItem(value: 'BangkokMart', child: Text('BangkokMart', style: TextStyle(fontSize: 14))),
                        DropdownMenuItem(value: 'Zakhira', child: Text('Zakhira', style: TextStyle(fontSize: 14))),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            _selectedWebsite = value;
                          });
                          _navigateToOrdersWithWebsite(value);
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Today's and Yesterday's Orders Row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminAllOrdersScreen(
                          orders: adminData?['orders'] ?? [],
                          initialFilter: 'today',
                        ),
                      ),
                    );
                  },
                  child: _buildOrderCard(
                    'Today\'s Orders',
                    currentStats['todayOrders'].toString(),
                    Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminAllOrdersScreen(
                          orders: adminData?['orders'] ?? [],
                          initialFilter: 'yesterday',
                        ),
                      ),
                    );
                  },
                  child: _buildOrderCard(
                    'Yesterday\'s Orders',
                    currentStats['yesterdayOrders'].toString(),
                    Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Total Orders (Clickable for admin users)
          if (isAdmin && title == 'Overview')
            GestureDetector(
              onTap: () {
                _showAdminOrders();
              },
              child: _buildOrderCard(
                'Total Orders',
                currentStats['totalOrders'].toString(),
                Colors.green,
                isClickable: true,
              ),
            )
          else if (!isAdmin && title == 'Overview')
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AllOrdersScreen(),
                  ),
                );
              },
              child: _buildOrderCard(
                'Total Orders',
                currentStats['totalOrders'].toString(),
                Colors.green,
                isClickable: true,
              ),
            )
          else
            _buildOrderCard(
              'Total Orders',
              currentStats['totalOrders'].toString(),
              Colors.green,
            ),
          
          const SizedBox(height: 16),
          
          // Cancelled Orders
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminAllOrdersScreen(
                    orders: adminData?['orders'] ?? [],
                    initialFilter: 'cancelled',
                  ),
                ),
              );
            },
            child: _buildOrderCard(
              'Cancelled Orders',
              currentStats['cancelledOrders'].toString(),
              Colors.red,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Summary Lines
          _buildSummaryLine('Managed Websites', '${adminWebsites?.length ?? 0}'),
          if (adminData != null && adminData!['products'] != null)
            _buildSummaryLine('Total Products', '${adminData!['products'].length}'),
          
          const SizedBox(height: 24),
          
          // Revenue Section
          const Text(
            'Revenue',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          
          // Revenue Cards
          Row(
            children: [
              Expanded(
                child: _buildRevenueCard(
                  'Lifetime',
                  '₹${currentStats['totalRevenue'].toString()}',
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRevenueCard(
                  'This Week',
                  '₹${currentStats['weekRevenue'].toString()}',
                  Colors.teal,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          _buildRevenueCard(
            'This Month',
            '₹${currentStats['monthRevenue'].toString()}',
            Colors.indigo,
          ),
        ],
      ),
    );
  }

  // Show company registration dialog
  Future<bool> _showCompanyRegistrationDialog() async {
    try {
      // Get user phone number
      final userId = LocalAuthService.getUserId();
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return false;
      }

      // Get user info to get phone number
      final response = await http.get(
        Uri.parse('${Config.baseNodeApiUrl}/users/user-info/${userId.toString()}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final userInfo = data['data'];
          final userPhone = userInfo['phone'];

          if (userPhone != null) {
            // Show registration screen
            final registered = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CompanyRegistrationScreen(
                  userPhone: userPhone,
                  userId: userId.toString(),
                ),
              ),
            );

            if (registered == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Company registered successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              // Refresh dashboard data after registration
              _checkAdminAndFetchData();
            }
            
            return registered == true;
          }
        }
      }
      
      return false;
    } catch (e) {
      print('Error showing registration dialog: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }
}
