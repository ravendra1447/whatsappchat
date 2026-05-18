import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/local_auth_service.dart';
import '../../services/marketplace/marketplace_chat_service.dart';
import '../../services/product_service.dart';
import '../../models/marketplace/marketplace_chat_room.dart';
import '../../models/product.dart';
import '../chat_screen.dart';
import '../product/detail/product_detail_screen.dart';
import '../order/order_detail_screen.dart';
import '../marketplace/marketplace_chat_screen.dart';
import 'seller_orders_screen.dart';
import 'seller_notification_screen.dart';
import '../../config.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/modern_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../profile_company/company_registration_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  List<Product> _publishedProducts = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _currentUserId;
  int _unreadMessageCount = 0;
  int _totalOrders = 0;
  int _unreadOrderNotifications = 0;

  @override
  void initState() {
    super.initState();
    _currentUserId = LocalAuthService.getUserId();
    if (_currentUserId != null) {
      _loadSellerProducts();
      _loadSellerOrderCount();
      _loadSellerNotifications();
      _initializeChatListener();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "Please login to view seller dashboard";
      });
    }
  }

  void _initializeChatListener() {
    // Listen for new messages to update unread count
    final chatService = MarketplaceChatService();
    chatService.on('new_message', (data) {
      if (data['senderId'] != _currentUserId) {
        // Message from buyer, increment unread count
        setState(() {
          _unreadMessageCount++;
        });
      }
    });
  }

  void _resetUnreadCount() {
    setState(() {
      _unreadMessageCount = 0;
    });
  }

  Future<void> _loadSellerProducts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get current user's published products ONLY
      final result = await ProductService.getProducts(
        user_id: _currentUserId!,
        status: 'publish',
        marketplace: false, // FALSE = Sirf current user ke products
        limit: 100,
      );

      if (result['success'] == true && result['data'] != null) {
        final productsData = result['data'] as List<dynamic>;
        final products = productsData.map((p) {
          try {
            final productMap = Map<String, dynamic>.from(p);
            
            // Handle marketplace_enabled field
            if (productMap['marketplace_enabled'] != null) {
              productMap['marketplace_enabled'] = productMap['marketplace_enabled'] == 1 ||
                  productMap['marketplace_enabled'] == '1' ||
                  productMap['marketplace_enabled'] == true;
            }
            
            return Product.fromMap(productMap);
          } catch (e) {
            print('Error parsing product: $e');
            return null;
          }
        }).whereType<Product>().toList();

        setState(() {
          _publishedProducts = products;
          _isLoading = false;
        });

        print('✅ Loaded ${products.length} seller products');
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load products';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading products: $e';
        _isLoading = false;
      });
      print('Error loading seller products: $e');
    }
  }

  Future<void> _refreshProducts() async {
    await _loadSellerProducts();
    await _loadSellerOrderCount();
    await _loadSellerNotifications();
  }

  // Load seller's total order count
  Future<void> _loadSellerOrderCount() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/seller-orders/count/${_currentUserId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _totalOrders = data['totalOrders'] ?? 0;
          });
          print('✅ Loaded seller order count: ${_totalOrders}');
        }
      }
    } catch (e) {
      print('❌ Error loading seller order count: $e');
    }
  }

  // Load seller's notifications
  Future<void> _loadSellerNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/seller-orders/notifications/${_currentUserId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _unreadOrderNotifications = data['unreadCount'] ?? 0;
          });
          print('✅ Loaded seller notifications: ${_unreadOrderNotifications} unread');
        }
      }
    } catch (e) {
      print('❌ Error loading seller notifications: $e');
    }
  }

  // Show order notifications dialog
  // Show seller orders list
  void _showSellerOrders() async {
    try {
      // Get all orders (no limit to show all orders)
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/seller-orders/recent/${_currentUserId}?limit=100'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final orders = data['orders'] as List<dynamic>;
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SellerOrdersScreen(
                orders: orders,
                totalOrders: _totalOrders,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error showing orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $e')),
        );
      }
    }
  }

  void _showOrderNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/seller-orders/notifications/${_currentUserId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          final notifications = data['notifications'] as List<dynamic>;
          final unreadCount = data['unreadCount'] ?? 0;
          
          print('🔔 API Response: ${data.toString()}');
          print('🔔 Unread count from API: $unreadCount');
          print('🔔 Notifications length: ${notifications.length}');
          
          // Update the unread count
          setState(() {
            _unreadOrderNotifications = unreadCount;
          });
          
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.notifications, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('Order Notifications (${_unreadOrderNotifications})'),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: notifications.isEmpty
                      ? const Center(
                          child: Text('No new orders'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.receipt, color: Colors.blue),
                                title: Text(
                                  notification['title'] ?? 'New Order',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  notification['message'] ?? 'Order received',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                onTap: () {
                                  print('🔔 Notification clicked: ${notification.toString()}');
                                  print('🔔 Notification message: ${notification['message']}');
                                  
                                  // Extract order ID from notification message
                                  final message = notification['message'] ?? '';
                                  print('🔔 Extracting order ID from: $message');
                                  
                                  final orderIdMatch = RegExp(r'Order #(\d+)').firstMatch(message);
                                  final orderId = orderIdMatch?.group(1);
                                  
                                  print('🔔 Extracted order ID: $orderId');
                                  
                                  if (orderId != null) {
                                    print('🔔 Navigating to order details for order: $orderId');
                                    Navigator.pop(context);
                                    _showOrderDetails(int.parse(orderId));
                                  } else {
                                    print('❌ Could not extract order ID from message');
                                  }
                                },
                                trailing: Text(
                                  _formatNotificationTime(notification['created_at']),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      print('❌ Error showing notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
    }
  }

  // Show order details
  void _showOrderDetails(int orderId) async {
    try {
      print('🚀 Navigating to OrderDetailScreen with orderId: $orderId');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailScreen(
            orderId: orderId,
          ),
        ),
      );
      
      print('✅ Successfully navigated to OrderDetailScreen');
    } catch (e) {
      print('❌ Error showing order details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order details: $e')),
        );
      }
    }
  }

  String _formatNotificationTime(String? timeString) {
    if (timeString == null) return '';
    
    try {
      final dateTime = DateTime.parse(timeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return timeString;
    }
  }

  void _openSellerChats() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to access chats'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Reset unread count when opening chats
    _resetUnreadCount();

    // Show product selection for chat
    _showProductSelectionForChat();
  }

  void _showProductSelectionForChat() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Product for Chat'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: _publishedProducts.isEmpty
                ? const Center(
                    child: Text('No products available for chat'),
                  )
                : ListView.builder(
                    itemCount: _publishedProducts.length,
                    itemBuilder: (context, index) {
                      final product = _publishedProducts[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: product.images.isNotEmpty
                              ? Image.network(
                                  product.images.first,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image, color: Colors.grey),
                                    );
                                  },
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image, color: Colors.grey),
                                ),
                        ),
                        title: Text(
                          product.name ?? 'Unknown Product',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '₹${product.price?.toStringAsFixed(0) ?? '0'}',
                          style: const TextStyle(color: Colors.green),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _openProductChat(product);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _openProductChat(Product product) async {
    try {
      // Create real chat room for this product
      final chatService = MarketplaceChatService();
      
      final chatRoom = await chatService.createOrGetChatRoom(
        productId: product.id ?? 0,
        buyerId: 1, // This will be updated when actual buyer joins
        sellerId: _currentUserId!,
      );
      
      if (chatRoom != null && mounted) {
        // Navigate to MarketplaceChatScreen with product context
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatRoom.id,
              otherUserId: _currentUserId! == chatRoom.sellerId 
                  ? chatRoom.buyerId 
                  : chatRoom.sellerId,
              otherUserName: _currentUserId! == chatRoom.sellerId 
                  ? "Buyer" 
                  : "Seller",
              isMarketplaceChat: true, // ✅ Enable marketplace chat
              marketplaceChatRoom: chatRoom, // ✅ Pass chat room data
              product: product, // ✅ Pass product info
            ),
          ),
        );
      }
    } catch (e) {
      // Fallback to mock if API fails
      print('API Error, using mock: $e');
      final mockChatRoom = MarketplaceChatRoom(
        id: DateTime.now().millisecondsSinceEpoch,
        productId: product.id ?? 0,
        buyerId: 1,
        sellerId: _currentUserId!,
        status: 'active', // Required parameter
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: mockChatRoom.id,
              otherUserId: _currentUserId! == mockChatRoom.sellerId 
                  ? mockChatRoom.buyerId 
                  : mockChatRoom.sellerId,
              otherUserName: _currentUserId! == mockChatRoom.sellerId 
                  ? "Buyer" 
                  : "Seller",
              isMarketplaceChat: true, // ✅ Enable marketplace chat
              marketplaceChatRoom: mockChatRoom, // ✅ Pass chat room data
              product: product, // ✅ Pass product info
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seller Dashboard',
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
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.chat, color: Colors.green),
                onPressed: _openSellerChats,
                tooltip: 'Seller Chats',
              ),
              if (_unreadMessageCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadMessageCount > 99 ? '99+' : '$_unreadMessageCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.blue),
                onPressed: () {
                  print('🔔 Notification icon clicked!');
                  print('🔔 Unread notifications count: $_unreadOrderNotifications');
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SellerNotificationScreen(
                        sellerId: _currentUserId!,
                      ),
                    ),
                  );
                },
                tooltip: 'Order Notifications',
              ),
              if (_unreadOrderNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadOrderNotifications > 99 ? '99+' : '$_unreadOrderNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _refreshProducts,
            tooltip: 'Refresh Products',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading your products...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshProducts,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_publishedProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Published Products',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your published products will appear here',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF128C7E),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Modern Stats Header - Very Light Green
        Container(
          width: double.infinity,
          margin: AppSpacing.paddingMD,
          padding: AppSpacing.paddingSM, // Smaller padding
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8F1), // Very light green background
            borderRadius: BorderRadius.circular(12), // Smaller radius
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05), // Lighter shadow
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildModernStatCard(
                  'Total Products',
                  '${_publishedProducts.length}',
                  Icons.inventory,
                  const Color(0xFF1976D2), // Light blue text
                  const Color(0xFFE3F2FD), // Light blue icon bg
                ),
              ),
              AppSpacing.horizontalSpaceMD,
              Expanded(
                child: GestureDetector(
                  onTap: _showSellerOrders,
                  child: _buildModernStatCard(
                    'Total Orders',
                    '$_totalOrders',
                    Icons.shopping_cart,
                    const Color(0xFFD32F2F), // Orange text
                    const Color(0xFFF5F5F5), // Light orange icon bg
                  ),
                ),
              ),
              AppSpacing.horizontalSpaceMD,
              Expanded(
                child: _buildModernStatCard(
                  'Published',
                  '${_publishedProducts.where((p) => p.status == 'publish').length}',
                  Icons.check_circle,
                  const Color(0xFF2E7D32), // Green text
                  const Color(0xFFE8F5E8), // Light green icon bg
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Products Grid - Marketplace Style
        Expanded(
          child: Padding(
            padding: AppSpacing.paddingHorizontalMD,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.68, // Marketplace aspect ratio
              ),
              itemCount: _publishedProducts.length,
              itemBuilder: (context, index) {
                final product = _publishedProducts[index];
                return _buildMarketplaceStyleProductCard(product);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color textColor, Color iconBgColor) {
    return Container(
      padding: AppSpacing.paddingSM,
      decoration: BoxDecoration(
        color: iconBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: textColor, size: 24),
          AppSpacing.verticalSpaceXS,
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          AppSpacing.verticalSpaceXS,
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceStyleProductCard(Product product) {
    // Get first image or use placeholder
    String imageUrl = 'https://via.placeholder.com/200x200.png?text=No+Image';
    if (product.images.isNotEmpty) {
      imageUrl = product.images.first;
    } else if (product.variations.isNotEmpty) {
      final firstVariation = product.variations.first;
      if (firstVariation['image'] != null) {
        imageUrl = firstVariation['image'].toString();
      }
    }

    // Calculate price and discount (Marketplace style)
    double? currentPrice;
    double? originalPrice;
    int discountPercent = 0;

    if (product.priceSlabs.isNotEmpty) {
      final firstSlab = product.priceSlabs.first;
      final priceStr = firstSlab['price']?.toString() ?? '';
      if (priceStr.isNotEmpty) {
        try {
          currentPrice = double.tryParse(priceStr);
          originalPrice = currentPrice != null ? currentPrice * 1.3 : null;
          if (originalPrice != null && currentPrice != null) {
            discountPercent = ((originalPrice - currentPrice) / originalPrice * 100).round();
          }
        } catch (e) {
          print('Error parsing price: $e');
        }
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: product,
              variation: product.variations.isNotEmpty 
                  ? product.variations.first 
                  : {'name': product.name, 'image': imageUrl},
              initialImageIndex: 0,
            ),
          ),
        );
      },
      child: ModernCard(
        padding: EdgeInsets.zero,
        elevation: 0.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Product Image - Marketplace Style
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: AppColors.surface(context),
                      child: _buildMarketplaceImageWidget(imageUrl),
                    ),
                  ),
                  // Discount Badge - Remove 23% OFF
                  // if (discountPercent > 0)
                  //   Positioned(
                  //     top: 8,
                  //     left: 8,
                  //     child: Container(
                  //       padding: AppSpacing.paddingHorizontalXS.add(AppSpacing.paddingVerticalXS),
                  //       decoration: BoxDecoration(
                  //         color: Colors.red,
                  //         borderRadius: BorderRadius.circular(4),
                  //       ),
                  //       child: Text(
                  //         '$discountPercent% OFF',
                  //         style: const TextStyle(
                  //           color: Colors.white,
                  //           fontSize: 10,
                  //           fontWeight: FontWeight.bold,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                ],
              ),
            ),

            // Product Details - Marketplace Style
            Padding(
              padding: AppSpacing.paddingSM,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Name
                  Text(
                    product.name,
                    style: AppTypography.bodyMedium(context).copyWith(
                      fontWeight: AppTypography.semibold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.verticalSpaceXS,

                  // Price Row
                  Row(
                    children: [
                      if (currentPrice != null) ...[
                        Flexible(
                          child: Text(
                            '₹${currentPrice.toStringAsFixed(0)}',
                            style: AppTypography.price(context).copyWith(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  AppSpacing.verticalSpaceXS,
                  
                  // Stock Info
                  Text(
                    'Stock: ${product.availableQty}',
                    style: AppTypography.bodySmall(context).copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketplaceImageWidget(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.image_not_supported, color: Colors.grey),
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }
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
              // Refresh seller data after registration
              _loadSellerProducts();
              _loadSellerOrderCount();
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
