import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../models/product.dart';
import '../../../services/local_auth_service.dart';
import '../../services/cart_service.dart';
import '../order/order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Product? product;
  final Map<String, dynamic>? selectedVariation;
  final int? quantity;
  final double? totalPrice;
  final List<CartItem>? cartItems;
  final Map<String, int>? selectedVariations; // Map of variation name to quantity (for color-only mode)
  final Map<String, String>? variationImages; // Map of variation name to image URL
  final Map<String, Map<String, int>>? variationSizeQuantities; // Map of {color: {size: qty}}
  final List<String>? availableSizes; // List of available sizes

  const CheckoutScreen({
    super.key,
    this.product,
    this.selectedVariation,
    this.quantity,
    this.totalPrice,
    this.cartItems,
    this.selectedVariations,
    this.variationImages,
    this.variationSizeQuantities,
    this.availableSizes,
  }) : assert(
          (product != null && selectedVariation != null && quantity != null && totalPrice != null) ||
          (cartItems != null) ||
          (product != null && selectedVariations != null && totalPrice != null) ||
          (product != null && variationSizeQuantities != null && totalPrice != null),
          'Either provide single product details, cart items list, selectedVariations map, or variationSizeQuantities map',
        );

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  bool _setDefaultAddress = false;
  String _selectedPaymentMethod = 'COD';
  String _selectedAddressMethod = 'manual'; // 'map' or 'manual'
  
  // Address data
  Map<String, dynamic>? _savedAddress;
  bool _addressLoaded = false;
  
  // Quantity management for different item types
  List<int>? _cartItemQuantities; // For cart items
  Map<String, int>? _variationQuantities; // For selected variations
  Map<String, Map<String, int>>? _variationSizeQuantities; // For color+size combinations

  @override
  void initState() {
    super.initState();
    _initializeQuantities();
    _loadSavedAddress();
  }

  // Initialize quantities based on item type
  void _initializeQuantities() {
    if (widget.cartItems != null) {
      // Initialize cart item quantities
      _cartItemQuantities = widget.cartItems!.map((item) => item.quantity).toList();
    } else if (widget.variationSizeQuantities != null) {
      // Deep copy variation size quantities for modification
      _variationSizeQuantities = {};
      widget.variationSizeQuantities!.forEach((color, sizes) {
        _variationSizeQuantities![color] = Map<String, int>.from(sizes);
      });
    } else if (widget.selectedVariations != null) {
      // Deep copy selected variations for modification
      _variationQuantities = Map<String, int>.from(widget.selectedVariations!);
    }
  }

  // Load saved address from database
  Future<void> _loadSavedAddress() async {
    final userId = LocalAuthService.getUserId();
    if (userId == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://node-api.bangkokmart.in/api/addresses/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] && responseData['addresses'].isNotEmpty) {
          final address = responseData['addresses'].firstWhere(
            (addr) => addr['is_default'] == 1,
            orElse: () => responseData['addresses'].first,
          );
          
          setState(() {
            _savedAddress = address;
            _addressLoaded = true;
            
            // Fill controllers with saved address
            _nameController.text = address['name'] ?? '';
            _phoneController.text = address['phone'] ?? '';
            _addressController.text = address['street'] ?? '';
            _cityController.text = address['city'] ?? '';
            _stateController.text = address['state'] ?? '';
            _pincodeController.text = address['pincode'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading address: $e');
    }
  }

  // Get current location (placeholder for now)
  Future<void> _getCurrentLocation() async {
    // Show location detection message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location detection will be implemented with GPS service'),
        backgroundColor: Colors.orange,
      ),
    );
    
    // TODO: Implement actual location detection with geolocator package
    // Add geolocator to pubspec.yaml and uncomment the import above
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showEditAddressDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add a new address',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your information is encrypted and secure',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Country / region',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const Center(
                                child: Text(
                                  '🇮🇳',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('India'),
                            const Spacer(),
                            const Icon(Icons.keyboard_arrow_down),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full name or company name',
                          labelStyle: const TextStyle(color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.orange, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your full name or company name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone number',
                          labelStyle: const TextStyle(color: Colors.black54),
                          prefixText: '+91 ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.orange, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (value.length < 10) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Only used to contact you for delivery updates',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Map section
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Stack(
                          children: [
                            // Map placeholder
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Map View',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Select on map button
                            Positioned(
                              top: 12,
                              left: 12,
                              child: GestureDetector(
                                onTap: () {
                                  _getCurrentLocation();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on, size: 16, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Select on map',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Search bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Search by street, address, or ZIP code',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Enter manually button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAddressMethod = 'manual';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Enter manually',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                            ],
                          ),
                        ),
                      ),
                      
                      // Manual address fields (shown when Enter manually is selected)
                      if (_selectedAddressMethod == 'manual') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'Street address',
                            labelStyle: const TextStyle(color: Colors.black54),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.grey, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.grey, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.orange, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your street address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cityController,
                                decoration: InputDecoration(
                                  labelText: 'City',
                                  labelStyle: const TextStyle(color: Colors.black54),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.grey, width: 1),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.grey, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.orange, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter city';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _stateController,
                                decoration: InputDecoration(
                                  labelText: 'State',
                                  labelStyle: const TextStyle(color: Colors.black54),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.grey, width: 1),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.grey, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.orange, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter state';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _pincodeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Pincode',
                            labelStyle: const TextStyle(color: Colors.black54),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.grey, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.grey, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.orange, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter pincode';
                            }
                            if (value.length != 6) {
                              return 'Please enter a valid 6-digit pincode';
                            }
                            return null;
                          },
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Checkbox(
                            value: _setDefaultAddress,
                            onChanged: (value) {
                              setState(() {
                                _setDefaultAddress = value!;
                              });
                            },
                          ),
                          const Text('Set as default shipping address'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _saveAddress();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Save address to database
  Future<void> _saveAddress() async {
    final userId = LocalAuthService.getUserId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _cityController.text.isEmpty ||
        _stateController.text.isEmpty ||
        _pincodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all delivery address details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final addressData = {
        'user_id': userId,
        'name': _nameController.text,
        'phone': _phoneController.text,
        'street': _addressController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'pincode': _pincodeController.text,
        'is_default': _setDefaultAddress,
      };

      final response = await http.post(
        Uri.parse('http://184.168.126.71:3000/api/addresses/create'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(addressData),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
          setState(() {}); // Refresh UI to show saved address
        } else {
          throw Exception(responseData['message']);
        }
      } else {
        throw Exception('Failed to save address');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getSelectedSize() {
    if (widget.selectedVariation != null) {
      final currentVarName = widget.selectedVariation!['name']?.toString() ?? '';
      final sizes = widget.product?.sizes ?? [];
      final variationQuantities = widget.selectedVariation!['quantities'] as Map<String, int>? ?? {};
      
      for (var size in sizes) {
        final qty = variationQuantities[size] ?? 0;
        if (qty > 0) {
          return size; // Return the size that has quantity
        }
      }
      
      // Fallback to first size if no quantity found
      return sizes.isNotEmpty ? sizes.first : 'No Size';
    }
    return 'No Size';
  }

  // Get total price for both single product and multiple cart items
  double _getTotalPrice() {
    if (widget.cartItems != null && _cartItemQuantities != null) {
      return widget.cartItems!.asMap().entries.fold(0.0, (sum, entry) {
        final index = entry.key;
        final item = entry.value;
        final quantity = _cartItemQuantities![index];
        return sum + (item.price * quantity);
      });
    } else if (_variationSizeQuantities != null && widget.product != null) {
      // Calculate total based on modified color+size combinations
      double total = 0.0;
      final priceSlabs = widget.product!.priceSlabs;
      
      // Calculate total quantity across all colors and sizes using modified quantities
      int totalQty = 0;
      for (var colorEntry in _variationSizeQuantities!.entries) {
        final sizes = colorEntry.value;
        for (var sizeEntry in sizes.entries) {
          totalQty += sizeEntry.value;
        }
      }
      
      // Find applicable price based on total quantity
      double unitPrice = 0.0;
      if (priceSlabs.isNotEmpty) {
        // Sort by MOQ descending to find best price
        final sortedSlabs = List<Map<String, dynamic>>.from(priceSlabs)
          ..sort((a, b) => ((b['moq'] as num?)?.toInt() ?? 0).compareTo((a['moq'] as num?)?.toInt() ?? 0));
        
        for (final slab in sortedSlabs) {
          final moq = (slab['moq'] as num?)?.toInt() ?? 0;
          if (totalQty >= moq) {
            unitPrice = double.tryParse(slab['price']?.toString() ?? '0') ?? 0.0;
            break;
          }
        }
        
        // If no slab matched, use first (lowest MOQ) slab
        if (unitPrice == 0.0 && sortedSlabs.isNotEmpty) {
          unitPrice = double.tryParse(sortedSlabs.last['price']?.toString() ?? '0') ?? 0.0;
        }
      }
      
      total = unitPrice * totalQty;
      return total;
    } else if (_variationQuantities != null && widget.product != null) {
      // Calculate total based on modified selected variations
      double total = 0.0;
      final priceSlabs = widget.product!.priceSlabs;
      final totalQty = _variationQuantities!.values.fold(0, (sum, qty) => sum + qty);
      
      // Find applicable price based on total quantity
      double unitPrice = 0.0;
      if (priceSlabs.isNotEmpty) {
        // Sort by MOQ descending to find best price
        final sortedSlabs = List<Map<String, dynamic>>.from(priceSlabs)
          ..sort((a, b) => ((b['moq'] as num?)?.toInt() ?? 0).compareTo((a['moq'] as num?)?.toInt() ?? 0));
        
        for (final slab in sortedSlabs) {
          final moq = (slab['moq'] as num?)?.toInt() ?? 0;
          if (totalQty >= moq) {
            unitPrice = double.tryParse(slab['price']?.toString() ?? '0') ?? 0.0;
            break;
          }
        }
        
        // If no slab matched, use first (lowest MOQ) slab
        if (unitPrice == 0.0 && sortedSlabs.isNotEmpty) {
          unitPrice = double.tryParse(sortedSlabs.last['price']?.toString() ?? '0') ?? 0.0;
        }
      }
      
      total = unitPrice * totalQty;
      return total;
    } else {
      return widget.totalPrice!;
    }
  }

  Future<void> _placeOrder() async {
    // Get user ID from LocalAuthService like other screens
    final userId = LocalAuthService.getUserId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first to place order'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate all required fields before placing order
    if (_addressController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _stateController.text.trim().isEmpty ||
        _pincodeController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all shipping details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if address is filled and loaded
    if (!_addressLoaded || 
        _nameController.text.isEmpty || 
        _phoneController.text.isEmpty || 
        _addressController.text.isEmpty || 
        _cityController.text.isEmpty || 
        _stateController.text.isEmpty || 
        _pincodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all delivery address details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final double totalPrice = _getTotalPrice();
      // Shipping is now free, processing fee removed as per request
      final double grandTotal = totalPrice;

      final orderData = {
        'user_id': userId, // ✅ Same as ProductService - LocalAuthService.getUserId()
        'total_amount': grandTotal,
        'shipping_street': _addressController.text,
        'shipping_city': _cityController.text,
        'shipping_state': _stateController.text,
        'shipping_pincode': _pincodeController.text,
        'shipping_phone': _phoneController.text,
        'payment_method': _selectedPaymentMethod,
        'items': widget.cartItems != null
            ? widget.cartItems!.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return {
                  'product_id': item.product.id,
                  'quantity': _cartItemQuantities![index],
                  'price': item.price,
                  'size': item.size,
                  'color': item.colorName,
                  'image_url': item.productImage,
                };
              }).toList()
            : _variationSizeQuantities != null && widget.product != null
                ? // Color+Size combinations - flatten the nested structure
                _variationSizeQuantities!.entries
                    .expand((colorEntry) {
                      final colorName = colorEntry.key;
                      final sizes = colorEntry.value;
                      final imageUrl = widget.variationImages?[colorName] ?? '';
                      
                      // Calculate total quantity across all colors and sizes using modified quantities
                      int totalQty = 0;
                      for (var cEntry in _variationSizeQuantities!.entries) {
                        for (var sEntry in cEntry.value.entries) {
                          totalQty += sEntry.value;
                        }
                      }
                      
                      // Calculate unit price based on total quantity
                      double unitPrice = 0.0;
                      final priceSlabs = widget.product!.priceSlabs;
                      if (priceSlabs.isNotEmpty) {
                        final sortedSlabs = List<Map<String, dynamic>>.from(priceSlabs)
                          ..sort((a, b) => ((b['moq'] as num?)?.toInt() ?? 0).compareTo((a['moq'] as num?)?.toInt() ?? 0));
                        for (final slab in sortedSlabs) {
                          final moq = (slab['moq'] as num?)?.toInt() ?? 0;
                          if (totalQty >= moq) {
                            unitPrice = double.tryParse(slab['price']?.toString() ?? '0') ?? 0.0;
                            break;
                          }
                        }
                        if (unitPrice == 0.0 && sortedSlabs.isNotEmpty) {
                          unitPrice = double.tryParse(sortedSlabs.last['price']?.toString() ?? '0') ?? 0.0;
                        }
                      }
                      
                      return sizes.entries.where((e) => e.value > 0).map((sizeEntry) {
                        final sizeName = sizeEntry.key;
                        final quantity = sizeEntry.value;
                        return {
                          'product_id': widget.product!.id,
                          'quantity': quantity,
                          'price': unitPrice,
                          'size': sizeName,
                          'color': colorName,
                          'image_url': imageUrl,
                        };
                      });
                    }).toList()
                : _variationQuantities != null && widget.product != null
                    ? // Multiple variations - create an item for each variation
                    _variationQuantities!.entries.where((e) => e.value > 0).map((entry) {
                      final variationName = entry.key;
                      final quantity = entry.value;
                      final imageUrl = widget.variationImages?[variationName] ?? '';
                      final totalQty = _variationQuantities!.values.fold(0, (sum, qty) => sum + qty);
                      
                      // Calculate unit price based on total quantity
                      double unitPrice = 0.0;
                      final priceSlabs = widget.product!.priceSlabs;
                      if (priceSlabs.isNotEmpty) {
                        final sortedSlabs = List<Map<String, dynamic>>.from(priceSlabs)
                          ..sort((a, b) => ((b['moq'] as num?)?.toInt() ?? 0).compareTo((a['moq'] as num?)?.toInt() ?? 0));
                        for (final slab in sortedSlabs) {
                          final moq = (slab['moq'] as num?)?.toInt() ?? 0;
                          if (totalQty >= moq) {
                            unitPrice = double.tryParse(slab['price']?.toString() ?? '0') ?? 0.0;
                            break;
                          }
                        }
                        if (unitPrice == 0.0 && sortedSlabs.isNotEmpty) {
                          unitPrice = double.tryParse(sortedSlabs.last['price']?.toString() ?? '0') ?? 0.0;
                        }
                      }
                      
                      return {
                        'product_id': widget.product!.id,
                        'quantity': quantity,
                        'price': unitPrice,
                        'size': 'No Size',
                        'color': variationName,
                        'image_url': imageUrl,
                      };
                    }).toList()
                    : [
                        {
                          'product_id': widget.product!.id,
                          'quantity': widget.quantity,
                          'price': widget.totalPrice! / widget.quantity!,
                          'size': _getSelectedSize(),
                          'color': widget.selectedVariation!['name'] ?? 'Default Color',
                          'image_url': widget.product?.images?.isNotEmpty == true ? widget.product!.images.first : '',
                        }
                      ]
      };

      print('Placing order for user_id: $userId'); // Debug log
      print('Order data: $orderData'); // Debug log

      final response = await http.post(
        Uri.parse('http://184.168.126.71:3000/api/orders/create'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(orderData),
      );

      print('Response status code: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Response data: $responseData'); // Debug log
        
        if (responseData['success']) {
          // Clear cart after successful order
          CartService.clearCart();
          
          // Show order success screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => OrderSuccessScreen(
                orderId: responseData['orderId'].toString(),
                totalAmount: _getTotalPrice(),
              ),
            ),
            (route) => false,
          );
        } else {
          throw Exception(responseData['message'] ?? 'Order failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = _getTotalPrice();
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'Checkout',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Your information is encrypted and secure',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 10,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined, color: Colors.black),
            onPressed: () {
              // Support toggle
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address Section
                    _buildAddressSection(),
                    
                    const SizedBox(height: 12),
                    
                    // Delivery Section
                    _buildDeliverySection(),
                    
                    const SizedBox(height: 12),
                    
                    // Items Section
                    _buildItemsSection(),
                    
                    const SizedBox(height: 12),
                    
                    // Payment Method Section
                    _buildPaymentSection(),
                    
                    const SizedBox(height: 12),
                    
                    // Order Summary Section
                    _buildOrderSummarySection(totalPrice),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          // Fixed Bottom Bar
          _buildBottomBar(totalPrice),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_nameController.text.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            _nameController.text,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _phoneController.text,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_addressController.text}, ${_cityController.text}, ${_stateController.text}, ${_pincodeController.text}, India',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else
                      const Text(
                        'Add delivery address',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onPressed: _showEditAddressDialog,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated delivery by 24 Feb-10 Mar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Shipping fee: Free',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.withOpacity(0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    int totalItems = 0;
    if (widget.cartItems != null && _cartItemQuantities != null) {
      totalItems = _cartItemQuantities!.fold(0, (sum, qty) => sum + qty);
    } else if (_variationSizeQuantities != null) {
      _variationSizeQuantities!.forEach((_, sizes) {
        sizes.forEach((_, qty) => totalItems += qty);
      });
    } else if (_variationQuantities != null) {
      _variationQuantities!.forEach((_, qty) => totalItems += qty);
    } else {
      totalItems = widget.quantity ?? 1;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalItems items in total',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Text(
                'View or edit',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildItemList(),
          const SizedBox(height: 16),
          Text(
            'Add note to supplier',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    if (widget.cartItems != null && _cartItemQuantities != null) {
      return SizedBox(
        height: 140,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: widget.cartItems!.length,
          itemBuilder: (context, index) {
            final item = widget.cartItems![index];
            final quantity = _cartItemQuantities![index];
            return _buildItemCard(
              imageUrl: item.productImage,
              title: '${item.colorName} , ${item.size}',
              price: item.price,
              quantity: quantity,
              onIncrease: () => _updateCartItemQuantity(index, quantity + 1),
              onDecrease: () => _updateCartItemQuantity(index, quantity - 1),
            );
          },
        ),
      );
    } else if (_variationSizeQuantities != null) {
      List<Widget> cards = [];
      _variationSizeQuantities!.forEach((color, sizes) {
        sizes.forEach((size, qty) {
          if (qty > 0) {
            cards.add(_buildItemCard(
              imageUrl: widget.variationImages?[color] ?? '',
              title: '$color , $size',
              price: _getUnitPrice(),
              quantity: qty,
              onIncrease: () => _updateVariationSizeQuantity(color, size, qty + 1),
              onDecrease: () => _updateVariationSizeQuantity(color, size, qty - 1),
            ));
          }
        });
      });
      return SizedBox(
        height: 140,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: cards,
        ),
      );
    } else if (_variationQuantities != null) {
      List<Widget> cards = [];
      _variationQuantities!.forEach((variation, qty) {
        if (qty > 0) {
          cards.add(_buildItemCard(
            imageUrl: widget.variationImages?[variation] ?? '',
            title: variation,
            price: _getUnitPrice(),
            quantity: qty,
            onIncrease: () => _updateVariationQuantity(variation, qty + 1),
            onDecrease: () => _updateVariationQuantity(variation, qty - 1),
          ));
        }
      });
      return SizedBox(
        height: 140,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: cards,
        ),
      );
    } else {
      return _buildItemCard(
        imageUrl: widget.product?.images.isNotEmpty == true ? widget.product!.images.first : '',
        title: '${widget.selectedVariation?['name'] ?? ''} , ${_getSelectedSize()}',
        price: _getUnitPrice(),
        quantity: widget.quantity ?? 1,
      );
    }
  }

  double _getUnitPrice() {
    if (widget.product != null) {
      final priceSlabs = widget.product!.priceSlabs;
      int totalQty = 0;
      if (widget.variationSizeQuantities != null) {
        widget.variationSizeQuantities!.forEach((_, sizes) {
          sizes.forEach((_, qty) => totalQty += qty);
        });
      } else if (widget.selectedVariations != null) {
        widget.selectedVariations!.forEach((_, qty) => totalQty += qty);
      } else {
        totalQty = widget.quantity ?? 1;
      }

      if (priceSlabs.isNotEmpty) {
        final sortedSlabs = List<Map<String, dynamic>>.from(priceSlabs)
          ..sort((a, b) => ((b['moq'] as num?)?.toInt() ?? 0).compareTo((a['moq'] as num?)?.toInt() ?? 0));
        
        for (final slab in sortedSlabs) {
          final moq = (slab['moq'] as num?)?.toInt() ?? 0;
          if (totalQty >= moq) {
            return double.tryParse(slab['price']?.toString() ?? '0') ?? 0.0;
          }
        }
        return double.tryParse(sortedSlabs.last['price']?.toString() ?? '0') ?? 0.0;
      }
    }
    return (widget.totalPrice ?? 0) / (widget.quantity ?? 1);
  }

  // Quantity update methods
  void _updateCartItemQuantity(int index, int newQuantity) {
    if (newQuantity < 1) return;
    
    setState(() {
      _cartItemQuantities![index] = newQuantity;
    });
  }

  void _updateVariationQuantity(String variation, int newQuantity) {
    if (newQuantity < 1) return;
    
    setState(() {
      _variationQuantities![variation] = newQuantity;
    });
  }

  void _updateVariationSizeQuantity(String color, String size, int newQuantity) {
    if (newQuantity < 1) return;
    
    setState(() {
      _variationSizeQuantities![color]![size] = newQuantity;
    });
  }

  Widget _buildItemCard({
    required String imageUrl, 
    required String title, 
    required double price, 
    required int quantity,
    VoidCallback? onIncrease,
    VoidCallback? onDecrease,
  }) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover, width: 100, height: 80)
                      : const Center(child: Icon(Icons.image, color: Colors.grey)),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      color: Colors.black.withOpacity(0.5),
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'INR ${price.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              GestureDetector(
                onTap: onDecrease != null && quantity > 1 ? onDecrease : null,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                    color: (onDecrease != null && quantity > 1) ? Colors.white : Colors.grey[100],
                  ),
                  child: Icon(
                    Icons.remove, 
                    size: 14, 
                    color: (onDecrease != null && quantity > 1) ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('$quantity', style: const TextStyle(fontSize: 12)),
                ),
              ),
              GestureDetector(
                onTap: onIncrease,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                    color: onIncrease != null ? Colors.white : Colors.grey[100],
                  ),
                  child: Icon(
                    Icons.add, 
                    size: 14, 
                    color: onIncrease != null ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 14, color: Colors.grey[600]),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Payment method',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.security, size: 14, color: Colors.green[600]),
              const SizedBox(width: 4),
              Text(
                'Secure payment',
                style: TextStyle(fontSize: 11, color: Colors.green[600], fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPaymentOption(
            'Credit Card',
            'Add a new card',
            Icons.credit_card,
            showLogos: true,
          ),
          const SizedBox(height: 12),
          _buildPaymentOption(
            'PayPal',
            'PayPal',
            null,
            isPaypal: true,
          ),
          const SizedBox(height: 12),
          _buildPaymentOption(
            'T/T',
            'Other payment methods',
            Icons.account_balance,
            subtitle: 'Place order first, pay later with your preferred method.',
            isTT: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, String title, IconData? icon, {bool showLogos = false, bool isPaypal = false, bool isTT = false, String? subtitle}) {
    final bool isSelected = _selectedPaymentMethod == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[50]?.withOpacity(0.3) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.orange[800]! : Colors.grey[200]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.orange[800]! : Colors.grey[400]!,
                  width: isSelected ? 5 : 1.5,
                ),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isPaypal)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003087),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('PayPal', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      else if (icon != null)
                        Icon(icon, size: 20, color: isSelected ? Colors.orange[800] : Colors.grey[600])
                      else
                        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      
                      const SizedBox(width: 8),
                      if (isPaypal || icon != null)
                        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      
                      if (showLogos) ...[
                        const Spacer(),
                        Row(
                          children: [
                            _buildPaymentLogo('assets/icons/visa.png', Icons.payment),
                            const SizedBox(width: 4),
                            _buildPaymentLogo('assets/icons/mastercard.png', Icons.credit_card),
                          ],
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentLogo(String asset, IconData fallback) {
    return Container(
      width: 24,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Image.asset(
        asset,
        errorBuilder: (context, error, stackTrace) => Icon(fallback, size: 10, color: Colors.grey),
      ),
    );
  }

  Widget _buildOrderSummarySection(double total) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, size: 18, color: Colors.orange[800]),
              const SizedBox(width: 8),
              const Text(
                'Order summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSummaryRow('Item subtotal', 'INR ${total.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          _buildSummaryRow('Shipping fee', 'Free', isGreen: true),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              Text(
                'INR ${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool hasInfo = false, bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isBold ? Colors.black : Colors.grey[600],
                fontWeight: isBold ? FontWeight.bold : FontWeight.w400,
              ),
            ),
            if (hasInfo) ...[
              const SizedBox(width: 4),
              const Icon(Icons.info_outline, size: 14, color: Colors.grey),
            ],
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isGreen ? Colors.green[700] : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) {
                      return Container(
                        padding: const EdgeInsets.only(top: 12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            _buildOrderSummarySection(total),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    },
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'INR ${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_up, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Proceed to pay',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
