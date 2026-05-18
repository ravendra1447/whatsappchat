import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../camera_interface_screen.dart';
import 'category_selection_screen.dart';
import 'attributes_management_screen.dart';
import '../../services/product_service.dart';
import '../../services/local_auth_service.dart';
import '../chat_home.dart';
import '../../config.dart';
import 'package:whatsappchat/theme/app_theme.dart';
import 'package:whatsappchat/theme/app_colors.dart';
import 'package:whatsappchat/theme/app_typography.dart';
import 'package:whatsappchat/theme/app_spacing.dart';
import 'package:whatsappchat/widgets/auto_focus_text_field.dart';
import 'package:whatsappchat/widgets/gradient_button.dart';
import 'package:whatsappchat/widgets/modern_card.dart';
import '../profile_company/company_registration_screen.dart';

class AddProductBasicInfoScreen extends StatefulWidget {
  final List<File> images;
  final Map<String, List<File>>? colorImagesMap; // Color name -> List of images
  const AddProductBasicInfoScreen({
    super.key,
    required this.images,
    this.colorImagesMap,
  });
  @override
  State<AddProductBasicInfoScreen> createState() =>
      _AddProductBasicInfoScreenState();
}

class _AddProductBasicInfoScreenState extends State<AddProductBasicInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _category;
  String? _subcategory;
  final TextEditingController _availableQtyController = TextEditingController();
  final FocusNode _availableQtyFocusNode = FocusNode();
  final List<Map<String, dynamic>> _priceSlabs = [];
  final Set<String> _selectedSizes = {};
  final List<Map<String, dynamic>> _colorItems = [];
  Map<String, List<String>> _attributes = {
    'Fabric': ['Cotton', 'Silk', 'Wool', 'Polyester', 'Linen'],
    'Fit': ['Regular', 'Slim', 'Loose', 'Tight'],
    'Sleeve': ['Half Sleeve', 'Full Sleeve', 'Sleeveless', 'Short Sleeve'],
    'Pattern': ['Solid', 'Striped', 'Printed', 'Checked', 'Floral'],
  };
  Map<String, String> _selectedAttributeValues = {};
  final TextEditingController _descController = TextEditingController();
  bool _attributesExpanded = false;
  final Map<String, bool> _expandedAttributeItems = {};
  final List<String> _sizes = ['S', 'M', 'L', 'XL', 'XXL'];
  final TextEditingController _tempNameController = TextEditingController();
  final TextEditingController _tempValueController = TextEditingController();
  bool _showAddAttributeFields = false;
  bool _marketplaceEnabled = true; // Marketplace toggle
  bool _publishWebsiteEnabled = false; // Publish Website toggle
  List<Map<String, dynamic>> _websites = []; // List of available websites
  List<int> _selectedWebsiteIds = []; // Selected website IDs
  // Stock management
  String _stockMode = 'always_available'; // 'simple', 'color_size', or 'always_available'
  String? _selectedColorForStock;
  final Map<String, Map<String, int>> _stockByColorSize = {}; // {color: {size: qty}}
  final TextEditingController _quickStockController = TextEditingController();
  bool _applyQuickToAllColors = false;
  // Always Available / On Demand fields
  final TextEditingController _dispatchTimeController = TextEditingController();
  bool _showMadeOnOrderBadge = false;

  // Recently selected items
  List<String> _recentCategories = [];
  List<String> _recentSizes = [];
  List<String> _recentColors = [];

  @override
  void initState() {
    super.initState();
    _loadRecentlySelectedItems();
    _fetchWebsites(); // Fetch websites on initialization
    // Initialize color items from colorImagesMap if available
    if (widget.colorImagesMap != null && widget.colorImagesMap!.isNotEmpty) {
      // Use color names from map - store all images for each color
      widget.colorImagesMap!.forEach((colorName, images) {
        if (images.isNotEmpty) {
          // Store all images for each color
          _colorItems.add({
            'name': colorName,
            'image': images.first, // First image for display
            'allImages': images, // All images for this color
          });
        }
      });
    } else if (widget.images.isNotEmpty) {
      // Fallback: Initialize color items from images (default names)
      for (int i = 0; i < widget.images.length; i++) {
        _colorItems.add({
          'name': 'Color ${i + 1}',
          'image': widget.images[i],
          'allImages': [widget.images[i]],
        });
      }
    }
  }

  // Load recently selected items from SharedPreferences
  Future<void> _loadRecentlySelectedItems() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentCategories = prefs.getStringList('recent_categories') ?? [];
      _recentSizes = prefs.getStringList('recent_sizes') ?? [];
      _recentColors = prefs.getStringList('recent_colors') ?? [];
    });
  }

  // Save recently selected category
  Future<void> _saveRecentCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    _recentCategories.remove(category); // Remove if exists
    _recentCategories.insert(0, category); // Add to beginning
    if (_recentCategories.length > 10) {
      _recentCategories = _recentCategories.take(10).toList(); // Keep only 10
    }
    await prefs.setStringList('recent_categories', _recentCategories);
    setState(() {});
  }

  // Save recently selected size
  Future<void> _saveRecentSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    _recentSizes.remove(size); // Remove if exists
    _recentSizes.insert(0, size); // Add to beginning
    if (_recentSizes.length > 10) {
      _recentSizes = _recentSizes.take(10).toList(); // Keep only 10
    }
    await prefs.setStringList('recent_sizes', _recentSizes);
    setState(() {});
  }

  // Save recently added color
  Future<void> _saveRecentColor(String color) async {
    final prefs = await SharedPreferences.getInstance();
    _recentColors.remove(color); // Remove if exists
    _recentColors.insert(0, color); // Add to beginning
    if (_recentColors.length > 20) {
      _recentColors = _recentColors.take(20).toList(); // Keep only 20
    }
    await prefs.setStringList('recent_colors', _recentColors);
    setState(() {});
  }

  void _selectRecentColor(String colorName) {
    // Create a new color item with the selected recent color
    final newColorItem = {
      'name': colorName,
      'image': null, // No image initially
      'allImages': <File>[],
    };

    setState(() {
      _colorItems.add(newColorItem);
    });

    // Optionally, save this new color to recent colors again
    _saveRecentColor(colorName);
  }

  // Fetch websites from API
  Future<void> _fetchWebsites() async {
    try {
      final userId = LocalAuthService.getUserId();
      
      if (userId != null) {
        print('🔍 Found userId: $userId');
        // Use Config.baseNodeApiUrl instead of direct IP
        final String baseUrl = Config.baseNodeApiUrl;
        
        // First test all websites endpoint
        print('🔍 Testing ALL websites endpoint on Node API...');
        try {
          final testResponse = await http.get(
            Uri.parse('$baseUrl/product-domain-visibility/test/websites'),
            headers: {
              'Content-Type': 'application/json',
            },
          );
          
          print('📊 Test response status: ${testResponse.statusCode}');
          if (testResponse.statusCode == 200) {
            final testData = json.decode(testResponse.body);
            print('📊 Total websites in DB: ${testData['count']}');
            print('📊 Sample data: ${testData['websites'].take(2)}');
          }
        } catch (e) {
          print('❌ Test endpoint failed: $e');
        }
        
        // Now try debug endpoint to see if websites exist
        print('🔍 Trying debug endpoint on Node API...');
        final debugResponse = await http.get(
          Uri.parse('$baseUrl/product-domain-visibility/websites/all'),
          headers: {
            'Content-Type': 'application/json',
          },
        );
        
        print('📊 Debug response status: ${debugResponse.statusCode}');
        if (debugResponse.statusCode == 200) {
          final debugData = json.decode(debugResponse.body);
          print('📊 Debug websites found: ${debugData['websites']?.length ?? 0}');
        }
        
        // Now try the actual endpoint - temporarily use debug endpoint to show all websites
        print('🔍 Using debug endpoint to show all websites (temporary fix)...');
        final response = await http.get(
          Uri.parse('$baseUrl/product-domain-visibility/websites/all'),
          headers: {
            'Content-Type': 'application/json',
          },
        );
        
        print('📊 User response status: ${response.statusCode}');
        print('📊 User response body: ${response.body}');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true && data['websites'] != null) {
            setState(() {
              _websites = List<Map<String, dynamic>>.from(data['websites']);
            });
            print('✅ Successfully loaded ${_websites.length} websites');
          }
        } else {
          print('HTTP Error: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      } else {
        print('❌ User ID is null - user not logged in');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please login to access websites'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching websites: $e');
    }
  }

  // Save product-website associations
  Future<void> _saveProductWebsiteAssociations(int productId) async {
    try {
      if (_publishWebsiteEnabled && _selectedWebsiteIds.isNotEmpty) {
        print('🌐 Saving product-website associations...');
        print('🌐 Product ID: $productId');
        print('🌐 Selected Website IDs: $_selectedWebsiteIds');
        
        final String baseUrl = Config.baseNodeApiUrl;
        final response = await http.post(
          Uri.parse('$baseUrl/product-domain-visibility/save'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'productId': productId,
            'selectedWebsiteIds': _selectedWebsiteIds,
          }),
        );
        
        print('🌐 Save response status: ${response.statusCode}');
        print('🌐 Save response body: ${response.body}');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            print('✅ Product-website associations saved successfully');
          } else {
            print('❌ Failed to save associations: ${data['message']}');
          }
        } else {
          print('❌ HTTP Error: ${response.statusCode}');
        }
      } else {
        print('🌐 No websites selected or publish website disabled');
      }
    } catch (e) {
      print('❌ Error saving product-website associations: $e');
    }
  }

  // Show website selection modal
  Future<void> _showWebsiteSelectionModal() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: AppColors.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Websites',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: AppColors.textSecondary(context)),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_websites.isEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.language, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'No websites found',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add websites to publish products',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  print('🔄 Refreshing websites...');
                                  await _fetchWebsites();
                                  setModalState(() {});
                                  print('🔄 Refresh completed. Websites count: ${_websites.length}');
                                },
                                icon: Icon(Icons.refresh, size: 16),
                                label: Text('Refresh'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Choose websites where this product will be visible:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._websites.map((website) {
                          final websiteId = website['website_id'] as int;
                          final isSelected = _selectedWebsiteIds.contains(websiteId);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    _selectedWebsiteIds.remove(websiteId);
                                  } else {
                                    _selectedWebsiteIds.add(websiteId);
                                  }
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF25D366).withOpacity(0.6)
                                        : AppColors.border(context),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: isSelected
                                      ? const Color(0xFF25D366).withOpacity(0.08)
                                      : AppColors.surface(context),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF25D366)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF25D366)
                                              : AppColors.border(context),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            website['website_name'] ?? 'Unknown Website',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? const Color(0xFF25D366)
                                                  : AppColors.textPrimary(context),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            website['domain'] ?? 'No domain',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.language,
                                      size: 16,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                      const SizedBox(height: 16),
                      // Done button
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {}); // Update main UI with selected websites
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper function to get color from color name
  Color _getColorFromName(String colorName) {
    final name = colorName.toLowerCase();
    switch (name) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'yellow':
        return Colors.yellow;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'pink':
        return Colors.pink;
      case 'brown':
        return Colors.brown;
      case 'grey':
      case 'gray':
        return Colors.grey;
      default:
        return Colors.grey.shade400;
    }
  }

  // Helper function to get text color for background
  Color _getTextColorForBackground(Color backgroundColor) {
    // Calculate luminance to determine if text should be white or black
    double luminance = (0.299 * backgroundColor.red +
        0.587 * backgroundColor.green +
        0.114 * backgroundColor.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _availableQtyController.dispose();
    _availableQtyFocusNode.dispose();
    _descController.dispose();
    _tempNameController.dispose();
    _tempValueController.dispose();
    _dispatchTimeController.dispose();
    super.dispose();
  }

  Future<void> _addPriceSlab() async {
    final priceCtrl = TextEditingController();
    final moqCtrl = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Price Slab',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: AppColors.textSecondary(context)),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Price input field
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          prefixStyle: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                          hintText: 'Price (per piece)',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: AppColors.textHint(context),
                          ),
                          filled: true,
                          fillColor: AppColors.surface(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.border(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.border(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF25D366),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // MOQ field with label
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Minimum Order Quantity (MOQ):',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: moqCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: InputDecoration(
                                    suffixText: 'PCS',
                                    suffixStyle: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary(context),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.surface(context),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.border(context),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.border(context),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF25D366),
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Recommendation text
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade700,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.help_outline,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Add button
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            final p = double.tryParse(priceCtrl.text.trim());
                            final m = int.tryParse(moqCtrl.text.trim());
                            if (p != null && m != null && m > 0) {
                              Navigator.pop(ctx, {
                                'price': p,
                                'moq': m,
                                'sizes': [],
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null) {
      setState(() {
        _priceSlabs.add(result);
      });
    }
  }

  Future<void> _showSizeSelectionModal() async {
    final Set<String> tempSelectedSizes = Set<String>.from(_selectedSizes);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: AppColors.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and + button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Sizes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              // Open Add New Size modal
                              final newSizes = await _showAddNewSizeModal(ctx);
                              if (newSizes != null && newSizes.isNotEmpty) {
                                setState(() {
                                  // Add each size individually to avoid comma-separated display
                                  for (final newSize in newSizes) {
                                    // Check for duplicates before adding
                                    if (!_sizes.contains(newSize)) {
                                      _sizes.add(newSize);
                                    }
                                  }
                                });
                                setModalState(() {});
                              }
                            },
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select Sizes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Recently selected sizes section
                      if (_recentSizes.isNotEmpty) ...[
                        const Text(
                          'Recently Selected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ..._recentSizes.map((s) {
                          final selected = tempSelectedSizes.contains(s);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  if (selected) {
                                    tempSelectedSizes.remove(s);
                                  } else {
                                    // Check if size is already selected in main list
                                    if (!_selectedSizes.contains(s)) {
                                      tempSelectedSizes.add(s);
                                    }
                                  }
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFF25D366).withOpacity(0.6)
                                        : AppColors.border(context),
                                    width: selected ? 1.5 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  color: selected
                                      ? const Color(0xFF25D366).withOpacity(0.08)
                                      : AppColors.surface(context),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(
                                          0xFF25D366,
                                        ).withOpacity(0.8)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: selected
                                              ? const Color(
                                            0xFF25D366,
                                          ).withOpacity(0.6)
                                              : AppColors.border(context),
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: selected
                                          ? const Icon(
                                        Icons.check,
                                        size: 10,
                                        color: Colors.white,
                                      )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      s,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: selected
                                            ? const Color(
                                          0xFF25D366,
                                        ).withOpacity(0.8)
                                            : AppColors.textPrimary(context),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Recent',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 12),
                        Text(
                          'All Sizes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      // Size checkboxes - one per line
                      ..._sizes.map((s) {
                        final selected = tempSelectedSizes.contains(s);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                if (selected) {
                                  tempSelectedSizes.remove(s);
                                } else {
                                  // Check if size is already selected in main list
                                  if (!_selectedSizes.contains(s)) {
                                    tempSelectedSizes.add(s);
                                  }
                                }
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF25D366).withOpacity(0.6)
                                      : AppColors.border(context),
                                  width: selected ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                color: selected
                                    ? const Color(0xFF25D366).withOpacity(0.08)
                                    : AppColors.surface(context),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(
                                        0xFF25D366,
                                      ).withOpacity(0.8)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: selected
                                            ? const Color(
                                          0xFF25D366,
                                        ).withOpacity(0.6)
                                            : AppColors.border(context),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: selected
                                        ? const Icon(
                                      Icons.check,
                                      size: 10,
                                      color: Colors.white,
                                    )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    s,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: selected
                                          ? const Color(
                                        0xFF25D366,
                                      ).withOpacity(0.8)
                                          : AppColors.textPrimary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 12),
                      // Done button
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedSizes.clear();
                              _selectedSizes.addAll(tempSelectedSizes);
                            });
                            // Save recently selected sizes
                            for (final size in tempSelectedSizes) {
                              _saveRecentSize(size);
                            }
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddAttributeModal() async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    final List<String> valueOptions = [];

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add Attribute',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.grey,
                              size: 18,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Show existing attributes
                      ..._attributes.entries.map((e) {
                        final selectedValue =
                            _selectedAttributeValues[e.key] ??
                                (e.value.isNotEmpty ? e.value.first : '');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      selectedValue,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 14,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      // Add Custom Attribute section
                      const Text(
                        '+ Add Custom Attribute',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // + button above Name and Value
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final value = valueController.text.trim();
                              if (value.isNotEmpty) {
                                setModalState(() {
                                  valueOptions.add(value);
                                  valueController.clear();
                                });
                              }
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Name and Value in same line
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nameController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Name',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: valueController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Value',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                suffixIcon: valueOptions.isEmpty
                                    ? Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey.shade400,
                                  size: 16,
                                )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Show added value options
                      if (valueOptions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: valueOptions.map((value) {
                            return Chip(
                              label: Text(
                                value,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onDeleted: () {
                                setModalState(() {
                                  valueOptions.remove(value);
                                });
                              },
                              deleteIcon: const Icon(Icons.close, size: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final value = valueOptions.isNotEmpty
                                ? valueOptions.first
                                : valueController.text.trim();
                            if (name.isNotEmpty && value.isNotEmpty) {
                              setState(() {
                                _attributes[name] = [value];
                                _selectedAttributeValues[name] = value;
                              });
                              Navigator.pop(ctx);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddValueToAttribute(String attributeName) async {
    final valueController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Value to $attributeName',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valueController,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Enter value',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () {
                          final value = valueController.text.trim();
                          if (value.isNotEmpty) {
                            setState(() {
                              if (!_attributes[attributeName]!.contains(
                                value,
                              )) {
                                _attributes[attributeName]!.add(value);
                              }
                            });
                            Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showValueDropdown(
      String attributeName,
      List<String> values,
      ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select $attributeName',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...values.map((value) {
                  return ListTile(
                    title: Text(value, style: const TextStyle(fontSize: 12)),
                    onTap: () {
                      setState(() {
                        _selectedAttributeValues[attributeName] = value;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditAttributeAndValue(
      String attributeName,
      String currentValue,
      ) async {
    final nameController = TextEditingController(text: attributeName);
    final valueController = TextEditingController(text: currentValue);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Attribute',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Attribute Name',
                    hintText: 'Enter attribute name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Attribute Value',
                    hintText: 'Enter attribute value',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () {
                      final newName = nameController.text.trim();
                      final newValue = valueController.text.trim();
                      if (newName.isNotEmpty && newValue.isNotEmpty) {
                        setState(() {
                          // Update attribute name if changed
                          if (newName != attributeName) {
                            final values = _attributes[attributeName]!;
                            final selectedValue =
                            _selectedAttributeValues[attributeName];
                            _attributes.remove(attributeName);
                            _attributes[newName] = values;
                            if (selectedValue != null) {
                              _selectedAttributeValues.remove(attributeName);
                              _selectedAttributeValues[newName] = selectedValue;
                            }
                            attributeName = newName;
                          }
                          // Update the current value
                          final index = _attributes[attributeName]!.indexOf(
                            currentValue,
                          );
                          if (index != -1) {
                            _attributes[attributeName]![index] = newValue;
                            if (_selectedAttributeValues[attributeName] ==
                                currentValue) {
                              _selectedAttributeValues[attributeName] =
                                  newValue;
                            }
                          }
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                    ),
                    child: const Text('Save', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditAttribute(String attributeName) async {
    final nameController = TextEditingController(text: attributeName);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Attribute',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Attribute name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () {
                      final newName = nameController.text.trim();
                      if (newName.isNotEmpty && newName != attributeName) {
                        setState(() {
                          final values = _attributes[attributeName]!;
                          final selectedValue =
                          _selectedAttributeValues[attributeName];
                          _attributes.remove(attributeName);
                          _attributes[newName] = values;
                          if (selectedValue != null) {
                            _selectedAttributeValues.remove(attributeName);
                            _selectedAttributeValues[newName] = selectedValue;
                          }
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                    ),
                    child: const Text('Save', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteAttribute(String attributeName) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Attribute'),
          content: Text('Are you sure you want to delete "$attributeName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _attributes.remove(attributeName);
                  _selectedAttributeValues.remove(attributeName);
                });
                Navigator.pop(ctx);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditAttributeValue(
      String attributeName,
      String currentValue,
      ) async {
    final valueController = TextEditingController(text: currentValue);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Value for $attributeName',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Enter value',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () {
                      final newValue = valueController.text.trim();
                      if (newValue.isNotEmpty && newValue != currentValue) {
                        setState(() {
                          final index = _attributes[attributeName]!.indexOf(
                            currentValue,
                          );
                          if (index != -1) {
                            _attributes[attributeName]![index] = newValue;
                            if (_selectedAttributeValues[attributeName] ==
                                currentValue) {
                              _selectedAttributeValues[attributeName] =
                                  newValue;
                            }
                          }
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                    ),
                    child: const Text('Save', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteAttributeValue(String attributeName, String value) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Value'),
          content: Text(
            'Are you sure you want to delete "$value" from "$attributeName"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _attributes[attributeName]!.remove(value);
                  if (_selectedAttributeValues[attributeName] == value) {
                    if (_attributes[attributeName]!.isNotEmpty) {
                      _selectedAttributeValues[attributeName] =
                          _attributes[attributeName]!.first;
                    } else {
                      _selectedAttributeValues.remove(attributeName);
                    }
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<List<String>?> _showAddNewSizeModal(BuildContext parentContext) async {
    final sizeNameController = TextEditingController();
    final List<String> tempSizes = [];

    return await showDialog<List<String>>(
      context: parentContext,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: AppColors.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add New Size',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: AppColors.textSecondary(context),
                              size: 18,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Size Name label
                      Text(
                        'Size Name',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Size Name input with tick circle
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sizeNameController,
                              textCapitalization: TextCapitalization.characters,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary(context),
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. Free Size, 3XL, 500g',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint(context),
                                ),
                                filled: true,
                                fillColor: AppColors.surface(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.border(context)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.border(context)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF25D366),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              onSubmitted: (value) {
                                final sizeName = value.trim();
                                if (sizeName.isNotEmpty && 
                                    !tempSizes.contains(sizeName) &&
                                    !_selectedSizes.contains(sizeName)) {
                                  setModalState(() {
                                    tempSizes.add(sizeName);
                                    sizeNameController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Tick circle button
                          GestureDetector(
                            onTap: () {
                              final sizeName = sizeNameController.text.trim();
                              if (sizeName.isNotEmpty && 
                                  !tempSizes.contains(sizeName) &&
                                  !_selectedSizes.contains(sizeName)) {
                                setModalState(() {
                                  tempSizes.add(sizeName);
                                  sizeNameController.clear();
                                });
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Display added sizes in one line
                      if (tempSizes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: tempSizes.map((size) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Chip(
                                  backgroundColor: AppColors.surface(context),
                                  label: Text(
                                    size,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                  onDeleted: () {
                                    setModalState(() {
                                      tempSizes.remove(size);
                                    });
                                  },
                                  deleteIcon: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: AppColors.textSecondary(context),
                                  ),
                                  side: BorderSide(color: AppColors.border(context)),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Save Size button
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            if (tempSizes.isNotEmpty) {
                              // Return the list of sizes to be combined
                              Navigator.pop(ctx, tempSizes);
                            } else {
                              Navigator.pop(ctx);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text(
                            'Save Size',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addNewColor() async {
    print('🔍 DEBUG: _addNewColor called in AddProductBasicInfoScreen');
    
    // TEMPORARY TEST: Always show company check result
    final userId = LocalAuthService.getUserId();
    print('🔍 DEBUG: Current User ID: $userId');
    
    // Check if user has company registered
    final hasCompany = await _checkUserCompany();
    print('🔍 DEBUG: hasCompany result in AddProductBasicInfoScreen: $hasCompany');
    
    // TEMPORARY: Force show registration dialog for testing
    if (!hasCompany) { // Simple blocking check
      print('🔍 DEBUG: FORCING registration dialog for testing');
      // Show company registration dialog first
      final registered = await _showCompanyRegistrationDialog();
      print('🔍 DEBUG: Registration dialog result: $registered');
      
      if (!registered) {
        // User cancelled registration, don't proceed
        print('🔍 DEBUG: User cancelled registration');
        return;
      }
      
      // Check again after registration
      final hasCompanyAfter = await _checkUserCompany();
      print('🔍 DEBUG: hasCompany after registration: $hasCompanyAfter');
      
      if (!hasCompanyAfter) {
        // Registration failed or was incomplete
        print('🔍 DEBUG: Registration failed, showing error');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company registration is required to add product colors'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    
    if (!hasCompany) {
      print('🔍 DEBUG: No company found, showing registration dialog');
      // Show company registration dialog first
      final registered = await _showCompanyRegistrationDialog();
      print('🔍 DEBUG: Registration dialog result: $registered');
      
      if (!registered) {
        // User cancelled registration, don't proceed
        return;
      }
      
      // Check again after registration
      final hasCompanyAfter = await _checkUserCompany();
      if (!hasCompanyAfter) {
        // Registration failed or was incomplete
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company registration is required to add product colors'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    
    // Company is registered, proceed with camera
    final result = await Navigator.push<List<File>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const CameraInterfaceScreen(returnImagesDirectly: true),
      ),
    );
    File? picked;
    if (result != null && result.isNotEmpty) {
      picked = result.first;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.card(context),
          title: Text(
            'Add Color',
            style: TextStyle(color: AppColors.textPrimary(context)),
          ),
          content: TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: AppColors.textPrimary(context)),
            decoration: InputDecoration(
              hintText: 'Enter color name',
              hintStyle: TextStyle(color: AppColors.textHint(context)),
              filled: true,
              fillColor: AppColors.surface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF25D366),
                  width: 2,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text(
                'Add',
                style: TextStyle(color: Color(0xFF25D366)),
              ),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      // Check for duplicate colors (case-insensitive)
      final isDuplicate = _colorItems.any((item) =>
      item['name'].toString().toLowerCase() == name.toLowerCase());

      if (!isDuplicate) {
        setState(() {
          _colorItems.add({'name': name, 'image': picked});
        });
        _saveRecentColor(name); // Save to recent colors
      } else {
        // Show error message for duplicate color
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Color "$name" already exists!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProduct(String type) async {
    try {
      print('🚀 _saveProduct called with type: $type');
      
      if (type == 'publish') {
        final hasCompany = await _checkUserCompany();
        
        if (!hasCompany) {
          print('❌ No company found - showing registration dialog');
          // Show company registration dialog
          final registered = await _showCompanyRegistrationDialog();
          print('📝 Registration result: $registered');
          
          if (!registered) {
            print('❌ User cancelled registration');
            return; // User cancelled registration
          }
          
          // Check again after registration
          print('🔍 Checking company after registration...');
          final hasCompanyAfter = await _checkUserCompany();
          print('📊 Has company after registration: $hasCompanyAfter');
          
          if (!hasCompanyAfter) {
            print('❌ Still no company after registration');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Company registration required to publish products'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      } else {
        print('📝 Saving draft product - company check skipped');
      }

      print('✅ Company check passed - proceeding to save product');
      
      // Show loading
      if (mounted) {
        print('📱 Showing loading dialog');
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
          const Center(child: CircularProgressIndicator()),
        );
      }

      // Convert _colorItems to JSON-serializable format (File objects to paths)
      final variations = _colorItems.map((item) {
        final colorName = item['name'] as String;
        final Map<String, dynamic> variation = {
          'name': colorName,
        };

        // Convert File to path string
        if (item['image'] != null) {
          final image = item['image'];
          if (image is File) {
            variation['image'] = image.path;
          } else {
            variation['image'] = image.toString();
          }
        }

        // Convert allImages List<File> to List<String>
        if (item['allImages'] != null) {
          final allImages = item['allImages'] as List;
          variation['allImages'] = allImages.map((img) {
            if (img is File) {
              return img.path;
            }
            return img.toString();
          }).toList();
        }

        // If stock mode is color_size, include stock data for this color
        if (_stockMode == 'color_size' && _stockByColorSize.containsKey(colorName)) {
          variation['stock'] = Map<String, int>.from(_stockByColorSize[colorName]!);
          // Calculate total stock for this color
          final totalStock = _stockByColorSize[colorName]!.values.fold<int>(0, (a, b) => a + b);
          variation['totalStock'] = totalStock;
        }

        return variation;
      }).toList();

      // Prepare product data
      // Debug: Print category and subcategory before saving
      print('📦 Saving product with category: $_category, subcategory: $_subcategory');
      final productData = {
        'name': _nameController.text.trim(),
        'category': _category ?? '',
        'subcategory': _subcategory?.trim().isNotEmpty == true ? _subcategory!.trim() : null,
        // For simple stock, use availableQty. For color_size, calculate total from all colors. For always_available, set to empty or special value
        'availableQty': _stockMode == 'simple'
            ? _availableQtyController.text.trim()
            : _stockMode == 'color_size'
            ? _stockByColorSize.values
            .expand((sizeMap) => sizeMap.values)
            .fold<int>(0, (a, b) => a + b)
            .toString()
            : '0', // For always_available, set to 0 or empty
        'stockMode': _stockMode, // 'simple', 'color_size', or 'always_available'
        'priceSlabs': _priceSlabs,
        'variations': variations,
        'attributes': _attributes,
        'selectedAttributeValues': _selectedAttributeValues,
        'description': _descController.text.trim(),
        'sizes': _selectedSizes, // Keep as Set<String> - ProductService expects Set<String>?
        'marketplaceEnabled': _marketplaceEnabled,
        'publishWebsiteEnabled': _publishWebsiteEnabled,
        'selectedWebsiteIds': _selectedWebsiteIds,
        // Include full stock data for color_size mode
        'stockByColorSize': _stockMode == 'color_size'
            ? _stockByColorSize.map((color, sizeMap) =>
            MapEntry(color, Map<String, int>.from(sizeMap)))
            : null,
        // Always Available / On Demand fields
        'dispatchTime': _stockMode == 'always_available' ? _dispatchTimeController.text.trim() : null,
        'showMadeOnOrderBadge': _stockMode == 'always_available' ? _showMadeOnOrderBadge : false,
      };

      // Debug: Print save details
      print('🎯 About to save product with status: $type');
      print('🎯 _publishWebsiteEnabled: $_publishWebsiteEnabled');
      print('🎯 _selectedWebsiteIds: $_selectedWebsiteIds');

      // Save to database using ProductService
      final result = await ProductService.saveProduct(
        productData: productData,
        images: widget.images,
        status: type, // 'draft' or 'publish'
      );

      // Debug: Print save result
      print('🎯 ProductService.saveProduct result: $result');

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                type == 'draft'
                    ? 'Product saved as draft successfully'
                    : 'Product published successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // If published, navigate to profile tab
          // Marketplace will auto-refresh when tab is selected
          if (type == 'publish') {
            // Pop all screens and navigate to ChatHomePage with profile tab
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatHomePage(initialTabIndex: 2),
              ),
                  (route) => false,
            );
          } else {
            Navigator.pop(context); // Go back for draft
          }
        } else {
          // Check if company registration is required
          if (result['needs_company_registration'] == true) {
            // Show company registration dialog
            await _showCompanyRegistrationDialog();
            
            // After registration, retry saving product
            if (mounted) {
              await _saveProduct(type);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Error saving product'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Check if user has company
  Future<bool> _checkUserCompany() async {
    try {
      print('🔍 _checkUserCompany called');
      final userId = LocalAuthService.getUserId();
      print('👤 User ID: $userId');
      
      if (userId == null) {
        print('❌ User ID is null');
        return false;
      }

      // Method 1: Try API first with new endpoint
      try {
        final url = '${Config.baseNodeApiUrl}/users/user-info-by-id/${userId.toString()}';
        print('🌐 Calling API: $url');
        
        final response = await http.get(
          Uri.parse(url),
        ).timeout(const Duration(seconds: 10));
        
        print('📡 Response status: ${response.statusCode}');
        print('📡 Response body: ${response.body}');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('📊 Parsed data: $data');
          
          if (data['success'] && data['data'] != null) {
            final userInfo = data['data'];
            print('👤 User info: $userInfo');
            
            // Check if user has company_id and branch_id
            final hasCompany = userInfo['company_id'] != null && 
                              userInfo['branch_id'] != null &&
                              userInfo['company_id'].toString().isNotEmpty &&
                              userInfo['branch_id'].toString().isNotEmpty;
            print('🏢 Company ID: ${userInfo['company_id']}');
            print('🏢 Branch ID: ${userInfo['branch_id']}');
            print('👤 User Role: ${userInfo['role']}');
            print('📊 Has company: $hasCompany');
            
            // Special handling for admin users without company
            if (!hasCompany) {
              print('🔑 User without company - checking role...');
              print('👤 User role: ${userInfo['role']}');
              
              if (userInfo['role'] == 'admin') {
                print('🔑 Admin user without company - attempting auto-registration...');
                
                // Try to auto-create company for admin
                final autoRegistered = await _autoRegisterCompanyForAdmin(userInfo);
                if (autoRegistered) {
                  print('✅ Admin company auto-registered successfully');
                  return true; // Now has company
                } else {
                  print('❌ Admin auto-registration failed - showing manual registration');
                }
              } else {
                print('👤 Non-admin user - showing manual registration');
              }
            }
            
            return hasCompany;
          } else {
            print('❌ API returned success: false or no data');
          }
        } else {
          print('❌ API failed with status: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ API call failed: $e');
      }

      // Method 1.5: Try with phone number as fallback
      try {
        print('🔄 Trying fallback with phone number...');
        
        // Get user phone from local storage or API
        final phoneUrl = '${Config.baseNodeApiUrl}/flutter/users/profile/${userId.toString()}';
        print('🌐 Getting user phone: $phoneUrl');
        
        final phoneResponse = await http.get(
          Uri.parse(phoneUrl),
        ).timeout(const Duration(seconds: 5));
        
        if (phoneResponse.statusCode == 200) {
          final phoneData = json.decode(phoneResponse.body);
          if (phoneData['success'] && phoneData['data']['phone'] != null) {
            final userPhone = phoneData['data']['phone'];
            print('📱 User phone: $userPhone');
            
            // Now try user-info with phone
            final phoneInfoUrl = '${Config.baseNodeApiUrl}/users/user-info/$userPhone';
            print('🌐 Calling phone info API: $phoneInfoUrl');
            
            final phoneInfoResponse = await http.get(
              Uri.parse(phoneInfoUrl),
            ).timeout(const Duration(seconds: 5));
            
            if (phoneInfoResponse.statusCode == 200) {
              final phoneInfoData = json.decode(phoneInfoResponse.body);
              if (phoneInfoData['success'] && phoneInfoData['data'] != null) {
                final userInfo = phoneInfoData['data'];
                print('👤 User info from phone: $userInfo');
                
                final hasCompany = userInfo['company_id'] != null && 
                                  userInfo['branch_id'] != null &&
                                  userInfo['company_id'].toString().isNotEmpty &&
                                  userInfo['branch_id'].toString().isNotEmpty;
                print('🏢 Company ID (phone): ${userInfo['company_id']}');
                print('🏢 Branch ID (phone): ${userInfo['branch_id']}');
                print('📊 Has company (phone): $hasCompany');
                
                return hasCompany;
              }
            }
          }
        }
      } catch (e) {
        print('❌ Phone fallback failed: $e');
      }

      // Method 2: Fallback - Try direct product service check
      print('🔄 Trying fallback method - direct database check...');
      try {
        final result = await ProductService.getProducts(status: 'publish', limit: 1);
        print('📦 ProductService check result: $result');
        
        // If we can get published products, user might have company
        // But this is not reliable, so we'll still return false
        if (result['success'] == true) {
          print('⚠️ User can access products but company status unclear');
        }
      } catch (e) {
        print('❌ ProductService fallback failed: $e');
      }
      
      // Method 3: Default to false for safety
      print('🛡️ Defaulting to false - requiring company registration');
      return false;
      
    } catch (e) {
      print('❌ Error checking user company: $e');
      return false;
    }
  }

  // Auto-register company for admin users
  Future<bool> _autoRegisterCompanyForAdmin(Map<String, dynamic> userInfo) async {
    try {
      print('🔧 Starting auto company registration for admin...');
      
      final userId = userInfo['user_id'];
      final userName = userInfo['name'] ?? 'Admin';
      final userPhone = userInfo['phone'] ?? '';
      
      if (userPhone.isEmpty) {
        print('❌ User phone is empty - cannot register company');
        return false;
      }
      
      print('👤 Admin User: $userName ($userPhone)');
      
      // Method 1: Try exact database structure company creation
      print('📝 Method 1: Creating company and branch (exact database structure)...');
      try {
        // Step 1: Create company with exact database fields
        final companyData = {
          'company_name': '${userName}\'s Company',
        };
        
        print('📦 Company data: $companyData');
        
        final companyResponse = await http.post(
          Uri.parse('${Config.baseNodeApiUrl}/companies/create'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(companyData),
        ).timeout(const Duration(seconds: 15));
        
        print('📡 Company creation response: ${companyResponse.statusCode}');
        print('📡 Company creation body: ${companyResponse.body}');
        
        if (companyResponse.statusCode == 200) {
          final companyResult = json.decode(companyResponse.body);
          if (companyResult['success']) {
            final companyId = companyResult['data']['company_id'];
            print('✅ Company created with ID: $companyId');
            
            // Step 2: Create branch with exact database fields
            final branchData = {
              'company_id': companyId,
              'branch_name': 'Main Branch',
              'city': userInfo['address_city'] ?? 'Noida',
            };
            
            print('📦 Branch data: $branchData');
            
            final branchResponse = await http.post(
              Uri.parse('${Config.baseNodeApiUrl}/companies/branches/create'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(branchData),
            ).timeout(const Duration(seconds: 15));
            
            print('📡 Branch creation response: ${branchResponse.statusCode}');
            print('📡 Branch creation body: ${branchResponse.body}');
            
            if (branchResponse.statusCode == 200) {
              final branchResult = json.decode(branchResponse.body);
              if (branchResult['success']) {
                final branchId = branchResult['data']['branch_id'];
                print('✅ Branch created with ID: $branchId');
                
                // Step 3: Assign user to company and branch
                final assignData = {
                  'phone': userPhone,
                  'company_id': companyId,
                  'branch_id': branchId,
                };
                
                print('📦 Assignment data: $assignData');
                
                final assignResponse = await http.put(
                  Uri.parse('${Config.baseNodeApiUrl}/users/assign-company-branch'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode(assignData),
                ).timeout(const Duration(seconds: 15));
                
                print('📡 Assignment response: ${assignResponse.statusCode}');
                print('📡 Assignment body: ${assignResponse.body}');
                
                if (assignResponse.statusCode == 200) {
                  final assignResult = json.decode(assignResponse.body);
                  if (assignResult['success']) {
                    print('✅ Full auto-registration completed successfully!');
                    return true;
                  } else {
                    print('❌ Assignment API returned failure: ${assignResult['message']}');
                  }
                } else {
                  print('❌ Assignment failed with status: ${assignResponse.statusCode}');
                }
              } else {
                print('❌ Branch creation API returned failure: ${branchResult['message']}');
              }
            } else {
              print('❌ Branch creation failed with status: ${branchResponse.statusCode}');
            }
          } else {
            print('❌ Company creation API returned failure: ${companyResult['message']}');
          }
        } else {
          print('❌ Company creation failed with status: ${companyResponse.statusCode}');
        }
      } catch (e) {
        print('❌ Method 1 failed: $e');
      }
      
      // Method 2: Direct assignment with dummy IDs
      print('🔄 Method 2: Direct assignment with dummy company/branch...');
      try {
        final assignResponse = await http.put(
          Uri.parse('${Config.baseNodeApiUrl}/users/assign-company-branch'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'phone': userPhone,
            'company_id': 1,  // Dummy company ID
            'branch_id': 1,   // Dummy branch ID
          }),
        ).timeout(const Duration(seconds: 10));
        
        print('📡 Direct assignment response: ${assignResponse.statusCode}');
        print('📡 Direct assignment body: ${assignResponse.body}');
        
        if (assignResponse.statusCode == 200) {
          final assignResult = json.decode(assignResponse.body);
          if (assignResult['success']) {
            print('✅ Direct assignment completed successfully!');
            return true;
          }
        }
      } catch (e) {
        print('❌ Method 2 failed: $e');
      }
      
      // Method 3: Create custom endpoint call
      print('🔄 Method 3: Custom admin assignment...');
      try {
        final customResponse = await http.post(
          Uri.parse('${Config.baseNodeApiUrl}/users/admin-assign-company'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': userId,
            'company_name': '${userName}\'s Company',
            'branch_name': 'Main Branch',
            'phone': userPhone,
          }),
        ).timeout(const Duration(seconds: 10));
        
        print('📡 Custom assignment response: ${customResponse.statusCode}');
        print('📡 Custom assignment body: ${customResponse.body}');
        
        if (customResponse.statusCode == 200) {
          final customResult = json.decode(customResponse.body);
          if (customResult['success']) {
            print('✅ Custom assignment completed successfully!');
            return true;
          }
        }
      } catch (e) {
        print('❌ Method 3 failed: $e');
      }
      
      print('❌ All auto-registration methods failed');
      return false;
      
    } catch (e) {
      print('❌ Auto-registration error: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  // Show company registration dialog
  Future<bool> _showCompanyRegistrationDialog() async {
    try {
      // Get user phone number
      final userId = LocalAuthService.getUserId();
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User not logged in')),
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

  PreferredSizeWidget _header() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFF1F1F1F),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: const Color(0xDEFFFFFF)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Add Product',
        style: TextStyle(
          color: const Color(0xDEFFFFFF),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary(context).withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _header(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Product Name'),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Enter product name',
                      hintStyle: TextStyle(fontSize: 14, color: AppColors.textHint(context)),
                      filled: true,
                      fillColor: AppColors.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border(context)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(
                          color: Color(0xFF25D366),
                          width: 2,
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _sectionTitle('Category'),
                  InkWell(
                    onTap: () async {
                      final picked = await Navigator.push<Map<String, String?>>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategorySelectionScreen(),
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _category = picked['category'];
                          _subcategory = picked['subcategory'];
                        });
                        // Debug: Print category and subcategory to verify
                        print('✅ Category selected: $_category');
                        print('✅ Subcategory selected: $_subcategory');
                        final displayName = _subcategory != null
                            ? '$_category > $_subcategory'
                            : _category;
                        if (displayName != null) {
                          _saveRecentCategory(displayName); // Save to recent categories
                        }
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _availableQtyFocusNode.requestFocus();
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _category == null
                                  ? 'Select category'
                                  : _subcategory != null
                                  ? '$_category > $_subcategory'
                                  : _category!,
                              style: TextStyle(
                                color: (_category == null)
                                    ? AppColors.textHint(context)
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: AppColors.textHint(context)),
                        ],
                      ),
                    ),
                  ),
                  // Recently selected categories
                  if (_recentCategories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success(context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.success(context).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recently Selected Categories',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _recentCategories.take(5).map((categoryDisplay) {
                              // Parse category display string (format: "Category > Subcategory" or just "Category")
                              final parts = categoryDisplay.split(' > ');
                              final category = parts[0];
                              final subcategory = parts.length > 1 ? parts[1] : null;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _category = category;
                                    _subcategory = subcategory;
                                  });
                                  _saveRecentCategory(categoryDisplay);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.card(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.success(context).withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    categoryDisplay,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.success(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Available Quantity'),
                  const SizedBox(height: 12),
                  // Modern segmented control
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Row(
                      children: [
                        // Simple - First
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _stockMode = 'simple';
                              });
                            },
                            child: Container(
                              height: 40,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _stockMode == 'simple'
                                    ? AppColors.card(context)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _stockMode == 'simple'
                                    ? [
                                  BoxShadow(
                                    color: AppColors.textPrimary(context).withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Simple',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _stockMode == 'simple'
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _stockMode == 'simple'
                                        ? const Color(0xFF25D366)
                                        : AppColors.textSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Color & Size - Second
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _stockMode = 'color_size';
                                if (_selectedColorForStock == null &&
                                    _colorItems.isNotEmpty) {
                                  _selectedColorForStock =
                                  _colorItems.first['name'] as String;
                                }
                              });
                            },
                            child: Container(
                              height: 40,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _stockMode == 'color_size'
                                    ? AppColors.card(context)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _stockMode == 'color_size'
                                    ? [
                                  BoxShadow(
                                    color: AppColors.textPrimary(context).withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Color & Size',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _stockMode == 'color_size'
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _stockMode == 'color_size'
                                        ? const Color(0xFF25D366)
                                        : AppColors.textSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Unlimited - Third
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _stockMode = 'always_available';
                              });
                            },
                            child: Container(
                              height: 40,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _stockMode == 'always_available'
                                    ? AppColors.card(context)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _stockMode == 'always_available'
                                    ? [
                                  BoxShadow(
                                    color: AppColors.textPrimary(context).withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Unlimited',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _stockMode == 'always_available'
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _stockMode == 'always_available'
                                        ? const Color(0xFF25D366)
                                        : AppColors.textSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_stockMode == 'simple') ...[
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _availableQtyController,
                        focusNode: _availableQtyFocusNode,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade400,
                          ),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'PCS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                  ] else if (_stockMode == 'always_available') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success(context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success(context).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.success(context).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppColors.success(context),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Unlimited Stock',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Accept orders without tracking inventory',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Show Made on Order badge checkbox
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.card(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border(context)),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _showMadeOnOrderBadge,
                                  onChanged: (value) {
                                    setState(() {
                                      _showMadeOnOrderBadge = value ?? false;
                                    });
                                  },
                                  activeColor: const Color(0xFF25D366),
                                ),
                                Expanded(
                                  child: Text(
                                    'Show "Made on Order" badge',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_showMadeOnOrderBadge) ...[
                            const SizedBox(height: 8),
                            Text(
                              'This label will highlight that the product is manufactured after order confirmation.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Dispatch Time',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _dispatchTimeController,
                              keyboardType: TextInputType.text,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary(context),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter dispatch time (e.g., 5-7 days)',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textHint(context),
                                ),
                                filled: true,
                                fillColor: AppColors.surface(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.border(context)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.border(context)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                  borderSide: BorderSide(
                                    color: AppColors.primary(context),
                                    width: 2,
                                  ),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Price & MoQ'),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ..._priceSlabs.asMap().entries.map((entry) {
                            final index = entry.key;
                            final slab = entry.value;
                            final sizes = slab['sizes'] as List<dynamic>? ?? [];
                            final sizesText = sizes.isNotEmpty ? sizes.join(' ') : '';
                            return Container(
                              margin: const EdgeInsets.only(right: 10),
                              child: SizedBox(
                                width: 140,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        color: Colors.grey.shade100,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Price slab ${index + 1}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '₹ ${slab['price']}/pc',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Min. order: ${slab['moq']} pcs',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (sizesText.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Size $sizesText',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          // Add price slab box
                          Container(
                            margin: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              onTap: _addPriceSlab,
                              child: SizedBox(
                                width: 140,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      style: BorderStyle.solid,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add,
                                        color: Colors.grey.shade600,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Add price slab',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Variation label and Add New Color button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Variation label - left side
                      Text(
                        'Variation',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      // Add New Color button - right side (smaller and thinner)
                      OutlinedButton.icon(
                        onPressed: _addNewColor,
                        icon: const Icon(
                          Icons.add,
                          color: Color(0xFF25D366),
                          size: 18,
                        ),
                        label: const Text(
                          'Add New Color',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary(context),
                          side: const BorderSide(
                            color: Color(0xFF25D366),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Color tab - selected (orange/yellow)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Color',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Recently added colors - show before variation items if no colors added yet
                  if (_recentColors.isNotEmpty && _colorItems.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.purple.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.history,
                                size: 14,
                                color: Colors.purple.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Recent Colors (Tap to add)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _recentColors.take(10).map((color) {
                              final isAdded = _colorItems.any((item) =>
                              item['name'].toString().toLowerCase() == color.toLowerCase());
                              return GestureDetector(
                                onTap: isAdded ? null : () {
                                  setState(() {
                                    _colorItems.add({'name': color, 'image': null});
                                    _saveRecentColor(color);
                                  });
                                },
                                child: Opacity(
                                  opacity: isAdded ? 0.5 : 1.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _getColorFromName(color),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.border(context),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isAdded) ...[
                                          const Icon(Icons.check, size: 14, color: Colors.white),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          color,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _getTextColorForBackground(_getColorFromName(color)),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._colorItems.map((item) {
                          final File? f = item['image'] as File?;
                          final colorName = item['name'] as String;
                          final color = _getColorFromName(colorName);
                          final isSelected = colorName == _selectedColorForStock;
                          final isRecentColor = _recentColors.contains(colorName);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColorForStock = colorName;
                              });
                            },
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: AppColors.card(context),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF25D366)
                                      : (isRecentColor ? Colors.purple.shade400 : AppColors.border(context)),
                                  width: isSelected ? 1.5 : (isRecentColor ? 1.5 : 1),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Header with color name and units badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(11),
                                        topRight: Radius.circular(11),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isRecentColor) ...[
                                                const Icon(
                                                  Icons.history,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 4),
                                              ],
                                              Flexible(
                                                child: Text(
                                                  colorName,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: _getTextColorForBackground(color),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            final totalUnits = (_stockByColorSize[
                                            colorName] ??
                                                {})
                                                .values
                                                .fold<int>(0, (a, b) => a + b);
                                            if (totalUnits > 0) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  borderRadius:
                                                  BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '+$totalUnits',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(11),
                                      bottomRight: Radius.circular(11),
                                    ),
                                    child: SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: f != null
                                          ? Image.file(f, fit: BoxFit.cover)
                                          : Container(
                                        color: color,
                                        child: Center(
                                          child: Text(
                                            colorName.substring(0, 1).toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: _getTextColorForBackground(color),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  // Recently added colors
                  if (_recentColors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.purple.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recently Added Colors (Last 20)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _recentColors.take(20).map((color) {
                              final isDuplicate = _colorItems.any((item) =>
                              item['name'].toString().toLowerCase() == color.toLowerCase());

                              return GestureDetector(
                                onTap: isDuplicate ? null : () {
                                  // Add color from recent list
                                  setState(() {
                                    _colorItems.add({'name': color, 'image': null});
                                  });
                                },
                                child: Opacity(
                                  opacity: isDuplicate ? 0.5 : 1.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getColorFromName(color),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.border(context),
                                      ),
                                    ),
                                    child: Text(
                                      color,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _getTextColorForBackground(_getColorFromName(color)),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_stockMode == 'color_size') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Quick Stock Entry',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _quickStockController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Enter Qty',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            final q = int.tryParse(
                                _quickStockController.text.trim()) ??
                                0;
                            final color = _selectedColorForStock;
                            if (q > 0 && color != null) {
                              setState(() {
                                _stockByColorSize.putIfAbsent(
                                    color, () => {});
                                for (final s in (_selectedSizes.isNotEmpty
                                    ? _selectedSizes
                                    : _sizes)) {
                                  _stockByColorSize[color]![s] = q;
                                }
                              });
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            side: const BorderSide(color: Color(0xFF25D366)),
                            foregroundColor: const Color(0xFF25D366),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Apply to all sizes'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Checkbox(
                          value: _applyQuickToAllColors,
                          onChanged: (v) {
                            setState(() {
                              _applyQuickToAllColors = v ?? false;
                              final q = int.tryParse(
                                  _quickStockController.text.trim()) ??
                                  0;
                              if (_applyQuickToAllColors && q > 0) {
                                for (final item in _colorItems) {
                                  final color = item['name'] as String;
                                  _stockByColorSize.putIfAbsent(
                                      color, () => {});
                                  for (final s in (_selectedSizes.isNotEmpty
                                      ? _selectedSizes
                                      : _sizes)) {
                                    _stockByColorSize[color]![s] = q;
                                  }
                                }
                              } else {
                                // Remove auto-applied stock from all colors except currently selected color
                                for (final item in _colorItems) {
                                  final color = item['name'] as String;
                                  if (color != _selectedColorForStock) {
                                    _stockByColorSize.remove(color);
                                  }
                                }
                              }
                            });
                          },
                        ),
                        const Text('Apply this stock to all colors'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_selectedColorForStock != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Stock for: ${_selectedColorForStock!}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${(_stockByColorSize[_selectedColorForStock!] ?? {}).values.fold<int>(0, (a, b) => a + b)} Units',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Column(
                        children:
                        (_selectedSizes.isNotEmpty ? _selectedSizes : _sizes)
                            .map((s) {
                          final cs = _stockByColorSize.putIfAbsent(
                              _selectedColorForStock!, () => {});
                          final qty = cs[s] ?? 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                    child:
                                    Text(s, style: const TextStyle(fontSize: 13))),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          final cur = cs[s] ?? 0;
                                          if (cur > 0) cs[s] = cur - 1;
                                        });
                                      },
                                      icon:
                                      const Icon(Icons.remove_circle_outline),
                                    ),
                                    Text('$qty',
                                        style:
                                        const TextStyle(fontWeight: FontWeight.w600)),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          final cur = cs[s] ?? 0;
                                          cs[s] = cur + 1;
                                        });
                                      },
                                      icon: const Icon(Icons.add_circle_outline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            // Separate card for Add New Size - moved below Variation
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF25D366),
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.surface(context),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _showSizeSelectionModal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                color: const Color(0xFF25D366),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Add Size',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF25D366),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_selectedSizes.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.check_circle,
                                  color: const Color(0xFF25D366),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(${_selectedSizes.length} sizes)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(width: 8),
                                Text(
                                  '(S, M, L, XL, XXL)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint(context),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_selectedSizes.isNotEmpty) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: _showSizeSelectionModal,
                            child: Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.orange,
                              size: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Display selected sizes as individual chips
                  if (_selectedSizes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF25D366).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Sizes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF25D366),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _selectedSizes.map((size) {
                              return Chip(
                                backgroundColor: const Color(0xFF25D366).withOpacity(0.1),
                                label: Text(
                                  size,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: const Color(0xFF25D366),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                deleteIcon: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: const Color(0xFF25D366),
                                ),
                                onDeleted: () {
                                  setState(() {
                                    _selectedSizes.remove(size);
                                  });
                                },
                                side: BorderSide(
                                  color: const Color(0xFF25D366).withOpacity(0.3),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Recently selected sizes
                  if (_recentSizes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recently Selected Sizes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _recentSizes.take(8).map((size) {
                              final isSelected = _selectedSizes.contains(size);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (!_selectedSizes.contains(size)) {
                                      _selectedSizes.add(size);
                                      _saveRecentSize(size);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue.shade100
                                        : AppColors.card(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue.shade400
                                          : Colors.blue.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    size,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSelected ? Colors.blue.shade700 : Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attributes header with expand/collapse
                  InkWell(
                    onTap: () {
                      setState(() {
                        _attributesExpanded = !_attributesExpanded;
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionTitle('Attributes'),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final result = await Navigator.push<
                                    Map<String, dynamic>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AttributesManagementScreen(
                                          attributes: _attributes,
                                          selectedAttributeValues:
                                          _selectedAttributeValues,
                                        ),
                                  ),
                                );
                                if (result != null) {
                                  setState(() {
                                    _attributes.clear();
                                    _attributes.addAll(
                                      Map<String, List<String>>.from(
                                        result['attributes'],
                                      ),
                                    );
                                    _selectedAttributeValues.clear();
                                    _selectedAttributeValues.addAll(
                                      Map<String, String>.from(
                                        result['selectedValues'],
                                      ),
                                    );
                                  });
                                }
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _attributesExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.chevron_right,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_attributesExpanded) ...[
                    const SizedBox(height: 6),
                    ..._attributes.entries.map((e) {
                      final values = e.value;
                      final selectedValue = _selectedAttributeValues[e.key] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Fixed width value box
                            GestureDetector(
                              onTap: () => _showValueDropdown(e.key, values),
                              child: Container(
                                width: 120,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.card(context),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.border(context),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        selectedValue,
                                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 16,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Expand/Collapse arrow
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _expandedAttributeItems[e.key] =
                                  !(_expandedAttributeItems[e.key] ?? false);
                                });
                              },
                              child: Icon(
                                (_expandedAttributeItems[e.key] ?? false)
                                    ? Icons.keyboard_arrow_up
                                    : Icons.chevron_right,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                            // Show buttons only when expanded
                            if (_expandedAttributeItems[e.key] ?? false) ...[
                              const SizedBox(width: 4),
                              // + button
                              GestureDetector(
                                onTap: () =>
                                    _showAddValueToAttribute(e.key),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Edit button
                              GestureDetector(
                                onTap: () => _showEditAttributeAndValue(
                                  e.key,
                                  selectedValue,
                                ),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Delete button
                              GestureDetector(
                                onTap: () => _deleteAttribute(e.key),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _sectionTitle('Product Description'),
                          const Text(' *', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                      Text(
                        '${_descController.text.length} / 500 chars',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descController,
                    maxLines: 6,
                    maxLength: 500,
                    style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
                    onChanged: (value) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter product description',
                      hintStyle: TextStyle(fontSize: 14, color: AppColors.textHint(context)),
                      filled: true,
                      fillColor: AppColors.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border(context)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(
                          color: Color(0xFF25D366),
                          width: 2,
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Marketplace Toggle
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.store,
                                color: Color(0xFF25D366), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Marketplace',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _marketplaceEnabled,
                          onChanged: (value) {
                            setState(() {
                              _marketplaceEnabled = value;
                            });
                          },
                          activeColor: const Color(0xFF25D366),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Publish Website Toggle
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.language,
                                    color: Color(0xFF25D366), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Publish Website',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _publishWebsiteEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _publishWebsiteEnabled = value;
                                });
                                if (value) {
                                  print('🌐 Website toggle enabled - fetching websites...');
                                  _fetchWebsites();
                                }
                              },
                              activeColor: const Color(0xFF25D366),
                            ),
                          ],
                        ),
                        if (_publishWebsiteEnabled) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              print('🌐 Website selection button tapped. Websites available: ${_websites.length}');
                              _showWebsiteSelectionModal();
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.list_alt, 
                                       size: 16, 
                                       color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedWebsiteIds.isEmpty
                                          ? 'Select websites...'
                                          : '${_selectedWebsiteIds.length} website(s) selected',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _selectedWebsiteIds.isEmpty
                                            ? Colors.grey.shade500
                                            : const Color(0xFF25D366),
                                        fontWeight: _selectedWebsiteIds.isEmpty
                                            ? FontWeight.normal
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, 
                                       size: 12, 
                                       color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: AppSpacing.paddingHorizontalLG.add(AppSpacing.paddingVerticalSM),
              child: Column(
                children: [
                  // Force auto-registration test (keep this one)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          print('🔧 DEBUG: Force auto-registration test...');
                          
                          // Get user info first
                          final userId = LocalAuthService.getUserId();
                          if (userId != null) {
                            try {
                              final url = '${Config.baseNodeApiUrl}/users/user-info-by-id/${userId.toString()}';
                              final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
                              
                              if (response.statusCode == 200) {
                                final data = json.decode(response.body);
                                if (data['success'] && data['data'] != null) {
                                  final userInfo = data['data'];
                                  print('👤 Forcing auto-registration for: ${userInfo['name']}');
                                  
                                  final registered = await _autoRegisterCompanyForAdmin(userInfo);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Auto-Registration: ${registered ? "SUCCESS" : "FAILED"}'),
                                      backgroundColor: registered ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              print('❌ Force registration error: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('🔧 DEBUG: Force Auto-Register'),
                      ),
                    ),
                  ),
                  
                  // Main buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _saveProduct('draft'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.border(context), width: 2),
                            foregroundColor: AppColors.textPrimary(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: AppSpacing.paddingVerticalMD,
                            minimumSize: const Size(0, 48),
                          ),
                          child: Text(
                            'Save as Draft',
                            style: AppTypography.button(context).copyWith(
                              color: AppColors.textPrimary(context),
                            ),
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                      AppSpacing.horizontalSpaceMD,
                      Expanded(
                        child: GradientButton(
                          text: 'Publish',
                          onPressed: () => _saveProduct('publish'),
                          height: 48,
                          icon: Icons.publish,
                          gradientColors: [
                            AppColors.orange(context),
                            AppColors.orange(context).withOpacity(0.8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddProductPriceMoqScreen extends StatefulWidget {
  final List<File> images;
  final String? name;
  final String? category;
  final String sellingUnit;
  final bool varSize;
  final bool varColor;
  final double price;
  final int stock;
  final int moq;

  const AddProductPriceMoqScreen({
    super.key,
    required this.images,
    this.name,
    this.category,
    required this.sellingUnit,
    required this.varSize,
    required this.varColor,
    required this.price,
    required this.stock,
    required this.moq,
  });

  @override
  State<AddProductPriceMoqScreen> createState() =>
      _AddProductPriceMoqScreenState();
}

class _AddProductPriceMoqScreenState extends State<AddProductPriceMoqScreen> {
  bool _autoCalc = true;
  int _availableQty = 126;
  final List<Map<String, dynamic>> _priceSlabs = [
    {'price': 6.45, 'moq': 2},
    {'price': 6.09, 'moq': 150},
  ];
  final List<String> _colors = [
    'Blue',
    'Gray',
    'Brown',
    'Black',
    'Pink',
    'Dark Blue',
  ];
  final Map<String, String> _attributes = {
    'Fabric': 'Cotton',
    'Fit': 'Regular',
    'Sleeve': 'Half Sleeve',
    'Pattern': 'Solid',
  };
  final TextEditingController _descController = TextEditingController();
  final List<Map<String, dynamic>> _colorItems = [];
  List<String> _recentColors = []; // Add recent colors list

  @override
  void initState() {
    super.initState();
    _loadRecentlySelectedItems(); // Load recent colors
    for (int i = 0; i < _colors.length; i++) {
      _colorItems.add({
        'name': _colors[i],
        'image': i < widget.images.length ? widget.images[i] : null,
      });
    }
  }

  // Load recently selected items from SharedPreferences
  Future<void> _loadRecentlySelectedItems() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentColors = prefs.getStringList('recent_colors') ?? [];
    });
  }

  // Save recently added color
  Future<void> _saveRecentColor(String color) async {
    final prefs = await SharedPreferences.getInstance();
    _recentColors.remove(color); // Remove if exists
    _recentColors.insert(0, color); // Add to beginning
    if (_recentColors.length > 20) {
      _recentColors = _recentColors.take(20).toList(); // Keep only 20
    }
    await prefs.setStringList('recent_colors', _recentColors);
    setState(() {});
  }

  // Helper function to get color from color name
  Color _getColorFromName(String colorName) {
    final name = colorName.toLowerCase();
    switch (name) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'yellow':
        return Colors.yellow;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'pink':
        return Colors.pink;
      case 'brown':
        return Colors.brown;
      case 'grey':
      case 'gray':
        return Colors.grey;
      default:
        return Colors.grey.shade400;
    }
  }

  // Helper function to get text color for background
  Color _getTextColorForBackground(Color backgroundColor) {
    // Calculate luminance to determine if text should be white or black
    double luminance = (0.299 * backgroundColor.red +
        0.587 * backgroundColor.green +
        0.114 * backgroundColor.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Widget _buildImageStrip() {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 70,
              height: 70,
              color: Colors.grey.shade200,
              child: Image.file(widget.images[index], fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Widget _pill(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey.shade200),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text),
    );
  }

  Future<void> _addPriceSlab() async {
    final priceCtrl = TextEditingController();
    final moqCtrl = TextEditingController();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Price Slab',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'Price per piece',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: moqCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Minimum order quantity',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      final p = double.tryParse(priceCtrl.text.trim());
                      final m = int.tryParse(moqCtrl.text.trim());
                      if (p != null && m != null) {
                        Navigator.pop(ctx, {'price': p, 'moq': m});
                      } else {
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result != null) {
      setState(() {
        _priceSlabs.add(result);
      });
    }
  }

  Future<void> _saveToFile(String type) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/product_${type}_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      final data = {
        'name': widget.name,
        'category': widget.category,
        'sellingUnit': widget.sellingUnit,
        'varSize': widget.varSize,
        'varColor': widget.varColor,
        'price': widget.price,
        'stock': widget.stock,
        'moq': widget.moq,
        'availableQty': _availableQty,
        'autoCalc': _autoCalc,
        'priceSlabs': _priceSlabs,
        'attributes': _attributes,
        'description': _descController.text,
        'images': widget.images.map((f) => f.path).toList(),
      };
      await file.writeAsString(jsonEncode(data));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == 'draft' ? 'Saved as draft' : 'Product published',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  // Check if user has company
  Future<bool> _checkUserCompany() async {
    try {
      print('🔍 _checkUserCompany called');
      final userId = LocalAuthService.getUserId();
      print('👤 User ID: $userId');
      
      if (userId == null) {
        print('❌ User ID is null');
        return false;
      }

      // Method 1: Try API first with new endpoint
      try {
        final url = '${Config.baseNodeApiUrl}/users/user-info-by-id/${userId.toString()}';
        print('🌐 Calling API: $url');
        
        final response = await http.get(
          Uri.parse(url),
        ).timeout(const Duration(seconds: 10));
        
        print('📡 Response status: ${response.statusCode}');
        print('📡 Response body: ${response.body}');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('📊 Parsed data: $data');
          
          if (data['success'] && data['data'] != null) {
            final userInfo = data['data'];
            print('👤 User info: $userInfo');
            
            // Check if user has company_id and branch_id
            final hasCompany = userInfo['company_id'] != null && 
                              userInfo['branch_id'] != null &&
                              userInfo['company_id'].toString().isNotEmpty &&
                              userInfo['branch_id'].toString().isNotEmpty;
            print('🏢 Company ID: ${userInfo['company_id']}');
            print('🏢 Branch ID: ${userInfo['branch_id']}');
            print('👤 User Role: ${userInfo['role']}');
            print('📊 Has company: $hasCompany');
            
            // Special handling for admin users without company
            if (!hasCompany) {
              print('🔑 User without company - checking role...');
              print('👤 User role: ${userInfo['role']}');
              
              if (userInfo['role'] == 'admin') {
                print('🔑 Admin user without company - attempting auto-registration...');
                
                // Try to auto-create company for admin
                final autoRegistered = await _autoRegisterCompanyForAdmin(userInfo);
                if (autoRegistered) {
                  print('✅ Admin company auto-registered successfully');
                  return true; // Now has company
                } else {
                  print('❌ Admin auto-registration failed - showing manual registration');
                }
              } else {
                print('👤 Non-admin user - showing manual registration');
              }
            }
            
            return hasCompany;
          } else {
            print('❌ API returned success: false or no data');
          }
        } else {
          print('❌ API failed with status: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ API call failed: $e');
      }
      
      return false;
    } catch (e) {
      print('❌ _checkUserCompany error: $e');
      return false;
    }
  }

  // Show company registration dialog
  Future<bool> _showCompanyRegistrationDialog() async {
    try {
      // Get user phone number
      final userId = LocalAuthService.getUserId();
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User not logged in')),
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

  // Auto register company for admin
  Future<bool> _autoRegisterCompanyForAdmin(Map<String, dynamic> userInfo) async {
    try {
      final userId = userInfo['id'];
      final userName = userInfo['name'] ?? 'Admin User';
      final userPhone = userInfo['phone'] ?? '0000000000';
      final userEmail = userInfo['email'] ?? 'admin@example.com';

      print('🔧 Auto-registering company for admin user: $userId');

      // Create company registration payload
      final companyPayload = {
        'user_id': userId,
        'company_name': '$userName Company',
        'company_type': 'Manufacturer',
        'industry_type': 'Textiles',
        'address': 'Default Address',
        'city': 'Default City',
        'state': 'Default State',
        'pincode': '000000',
        'country': 'India',
        'phone': userPhone,
        'email': userEmail,
        'website': '',
        'description': 'Auto-registered company for admin user',
        'registration_number': 'AUTO-REG-${DateTime.now().millisecondsSinceEpoch}',
      };

      // Register company
      final companyResponse = await http.post(
        Uri.parse('${Config.baseNodeApiUrl}/company/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(companyPayload),
      ).timeout(const Duration(seconds: 15));

      print('📡 Company registration response: ${companyResponse.statusCode}');
      print('📡 Company registration body: ${companyResponse.body}');

      if (companyResponse.statusCode == 200 || companyResponse.statusCode == 201) {
        final companyData = json.decode(companyResponse.body);
        if (companyData['success'] && companyData['data'] != null) {
          final companyInfo = companyData['data'];
          final companyId = companyInfo['company_id'] ?? companyInfo['id'];

          if (companyId != null) {
            // Create branch
            final branchPayload = {
              'company_id': companyId,
              'branch_name': 'Main Branch',
              'address': 'Default Branch Address',
              'city': 'Default City',
              'state': 'Default State',
              'pincode': '000000',
              'country': 'India',
              'phone': userPhone,
              'email': userEmail,
              'is_main_branch': true,
            };

            final branchResponse = await http.post(
              Uri.parse('${Config.baseNodeApiUrl}/company/branch/register'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(branchPayload),
            ).timeout(const Duration(seconds: 15));

            print('📡 Branch registration response: ${branchResponse.statusCode}');
            print('📡 Branch registration body: ${branchResponse.body}');

            if (branchResponse.statusCode == 200 || branchResponse.statusCode == 201) {
              final branchData = json.decode(branchResponse.body);
              if (branchData['success'] && branchData['data'] != null) {
                final branchInfo = branchData['data'];
                final branchId = branchInfo['branch_id'] ?? branchInfo['id'];

                if (branchId != null) {
                  // Update user with company and branch IDs
                  final updatePayload = {
                    'company_id': companyId,
                    'branch_id': branchId,
                  };

                  final updateResponse = await http.put(
                    Uri.parse('${Config.baseNodeApiUrl}/users/update-user/$userId'),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(updatePayload),
                  ).timeout(const Duration(seconds: 15));

                  print('📡 User update response: ${updateResponse.statusCode}');
                  print('📡 User update body: ${updateResponse.body}');

                  if (updateResponse.statusCode == 200) {
                    print('✅ Admin company auto-registration completed successfully');
                    return true;
                  }
                }
              }
            }
          }
        }
      }

      print('❌ Admin auto-registration failed');
      return false;
    } catch (e) {
      print('❌ Auto-registration error: $e');
      return false;
    }
  }

  Future<void> _addNewColor() async {
    print('🔍 DEBUG: _addNewColor called in AddProductPriceMoqScreen');
    // Check if user has company registered
    final hasCompany = await _checkUserCompany();
    print('🔍 DEBUG: hasCompany result in AddProductPriceMoqScreen: $hasCompany');
    
    if (!hasCompany) {
      print('🔍 DEBUG: No company found in PriceMoqScreen, showing registration dialog');
      // Show company registration dialog first
      final registered = await _showCompanyRegistrationDialog();
      print('🔍 DEBUG: Registration dialog result in PriceMoqScreen: $registered');
      
      if (!registered) {
        // User cancelled registration, don't proceed
        return;
      }
      
      // Check again after registration
      final hasCompanyAfter = await _checkUserCompany();
      if (!hasCompanyAfter) {
        // Registration failed or was incomplete
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company registration is required to add product colors'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    
    // Company is registered, proceed with camera
    final result = await Navigator.push<List<File>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const CameraInterfaceScreen(returnImagesDirectly: true),
      ),
    );
    File? picked;
    if (result != null && result.isNotEmpty) {
      picked = result.first;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.card(context),
          title: Text(
            'Add Color',
            style: TextStyle(color: AppColors.textPrimary(context)),
          ),
          content: TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: AppColors.textPrimary(context)),
            decoration: InputDecoration(
              hintText: 'Enter color name',
              hintStyle: TextStyle(color: AppColors.textHint(context)),
              filled: true,
              fillColor: AppColors.surface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF25D366),
                  width: 2,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text(
                'Add',
                style: TextStyle(color: Color(0xFF25D366)),
              ),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      // Check for duplicate colors (case-insensitive)
      final isDuplicate = _colorItems.any((item) =>
      item['name'].toString().toLowerCase() == name.toLowerCase());

      if (!isDuplicate) {
        setState(() {
          _colors.add(name);
          _colorItems.add({'name': name, 'image': picked});
        });
        _saveRecentColor(name); // Save to recent colors
      } else {
        // Show error message for duplicate color
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Color "$name" already exists!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Product Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildImageStrip(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Basic Info',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.name ?? 'No name',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _pill(
                        widget.category ?? 'Category',
                        color: Colors.grey.shade100,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (widget.varSize)
                        _pill('Size', color: Colors.blue.shade100),
                      if (widget.varSize && widget.varColor)
                        const SizedBox(width: 4),
                      if (widget.varColor)
                        _pill('Color', color: Colors.purple.shade100),
                      const SizedBox(width: 4),
                      _pill(
                        '${widget.sellingUnit}',
                        color: Colors.green.shade100,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Quantity',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Text('Total Available'),
                              const Spacer(),
                              Text(
                                '$_availableQty PCS',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _pill('Auto'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _autoCalc,
                        onChanged: (v) => setState(() => _autoCalc = v ?? true),
                        activeColor: const Color(0xFF25D366),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Auto calculate from variations',
                          style: TextStyle(color: AppColors.textSecondary(context)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Price & MOQ',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _priceSlabs
                        .map(
                          (slab) => Container(
                        width: 150,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.orange.shade50,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹ ${slab['price']}/pc',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Min. order: ${slab['moq']} pcs',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: _addPriceSlab,
                      child: _pill(
                        '+ Add More Price Slab',
                        color: Colors.orange.shade100,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AddProductMoqSetScreen(images: widget.images),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.orange.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Minimum Order Quantity (PCS/SET)'),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Variations',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.orange(context).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Color',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Size',
                          style: TextStyle(color: AppColors.textPrimary(context)),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.keyboard_arrow_up, color: AppColors.textSecondary(context)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._colorItems.map((item) {
                          final File? f = item['image'] as File?;
                          return Container(
                            width: 90,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border(context)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                ClipOval(
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey.shade200,
                                    child: f != null
                                        ? Image.file(f, fit: BoxFit.cover)
                                        : const SizedBox(),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(item['name'] as String),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addNewColor,
                      icon: const Icon(Icons.add, color: Colors.orange),
                      label: const Text('Add New Color'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.orange.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
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
                      const Text(
                        'Attributes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showAddAttributeModal(),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._attributes.entries
                      .map(
                        (e) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(e.key)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(e.value),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .toList(),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Description',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter description',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _saveToFile('draft');
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save as Draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _saveToFile('publish');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Publish Product'),
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

  Future<void> _showAddAttributeModal() async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    final List<String> valueOptions = [];

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add Attribute',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.grey,
                              size: 18,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Show existing attributes
                      ..._attributes.entries.map((e) {
                        final selectedValue = e.value.toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      selectedValue,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 14,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      // Add Custom Attribute section
                      const Text(
                        '+ Add Custom Attribute',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // + button above Name and Value
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final value = valueController.text.trim();
                              if (value.isNotEmpty) {
                                setModalState(() {
                                  valueOptions.add(value);
                                  valueController.clear();
                                });
                              }
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Name and Value in same line
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nameController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Name',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: valueController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Value',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                suffixIcon: valueOptions.isEmpty
                                    ? Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey.shade400,
                                  size: 16,
                                )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Show added value options
                      if (valueOptions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: valueOptions.map((value) {
                            return Chip(
                              label: Text(
                                value,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onDeleted: () {
                                setModalState(() {
                                  valueOptions.remove(value);
                                });
                              },
                              deleteIcon: const Icon(Icons.close, size: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final value = valueOptions.isNotEmpty
                                ? valueOptions.join(', ')
                                : valueController.text.trim();
                            if (name.isNotEmpty && value.isNotEmpty) {
                              setState(() {
                                _attributes[name] = value;
                              });
                              Navigator.pop(ctx);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AddProductMoqSetScreen extends StatefulWidget {
  final List<File> images;
  const AddProductMoqSetScreen({super.key, required this.images});
  @override
  State<AddProductMoqSetScreen> createState() => _AddProductMoqSetScreenState();
}

class _AddProductMoqSetScreenState extends State<AddProductMoqSetScreen> {
  String _mode = 'PCS';
  final List<String> _sizes = ['S', 'M', 'L', 'XL', 'XXL'];
  final Set<String> _selectedSizes = {'M', 'L'};
  final TextEditingController _pcsController = TextEditingController(text: '3');
  final TextEditingController _setCountController = TextEditingController(
    text: '1',
  );

  @override
  void dispose() {
    _pcsController.dispose();
    _setCountController.dispose();
    super.dispose();
  }

  Widget _buildImageStrip() {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 70,
              height: 70,
              color: Colors.grey.shade200,
              child: Image.file(widget.images[index], fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Minimum Order Quantity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildImageStrip(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Type',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _mode = 'PCS'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _mode == 'PCS'
                                    ? const Color(0xFF25D366)
                                    : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              color: _mode == 'PCS'
                                  ? const Color(0xFF25D366).withOpacity(0.08)
                                  : Colors.white,
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF25D366),
                                ),
                                SizedBox(width: 8),
                                Text('PCS'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _mode = 'SET'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _mode == 'SET'
                                    ? const Color(0xFF25D366)
                                    : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              color: _mode == 'SET'
                                  ? const Color(0xFF25D366).withOpacity(0.08)
                                  : Colors.white,
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Color(0xFF25D366),
                                ),
                                SizedBox(width: 8),
                                Text('SET'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_mode == 'PCS') ...[
                    const Text(
                      'Minimum Order (PCS)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pcsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        suffixText: 'PCS',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Define Set',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sizes.map((s) {
                        final selected = _selectedSizes.contains(s);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedSizes.remove(s);
                              } else {
                                _selectedSizes.add(s);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF25D366)
                                    : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: selected
                                  ? const Color(0xFF25D366).withOpacity(0.08)
                                  : Colors.white,
                            ),
                            child: Text(s),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _setCountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Pieces per set',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final result = {
                          'mode': _mode,
                          'pcs': int.tryParse(_pcsController.text) ?? 3,
                          'selectedSizes': _selectedSizes.toList(),
                          'setCount':
                          int.tryParse(_setCountController.text) ?? 1,
                        };
                        Navigator.pop(context, result);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save'),
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
}
