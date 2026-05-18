import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config.dart';

class PaymentLogsScreen extends StatefulWidget {
  const PaymentLogsScreen({super.key});

  @override
  State<PaymentLogsScreen> createState() => _PaymentLogsScreenState();
}

class _PaymentLogsScreenState extends State<PaymentLogsScreen> {
  List<dynamic> logs = [];
  bool isLoading = true;
  String? errorMessage;
  int _currentPage = 1;
  final int _limit = 20;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchPaymentLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMore) {
        _fetchPaymentLogs(loadMore: true);
      }
    }
  }

  Future<void> _fetchPaymentLogs({bool loadMore = false}) async {
    if (_isLoading) return;

    try {
      setState(() {
        if (!loadMore) {
          isLoading = true;
          _currentPage = 1;
          logs.clear();
        }
        errorMessage = null;
      });

      final offset = loadMore ? (_currentPage - 1) * _limit : 0;
      final response = await http.get(
        Uri.parse('${Config.baseNodeApiUrl}/orders/payment-logs?limit=$_limit&offset=$offset'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final newLogs = data['logs'] ?? [];
          
          setState(() {
            if (loadMore) {
              logs.addAll(newLogs);
            } else {
              logs = newLogs;
            }
            
            _hasMore = newLogs.length == _limit;
            if (loadMore) {
              _currentPage++;
            }
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load payment logs';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Color _getActionTypeColor(String actionType) {
    switch (actionType) {
      case 'PAYMENT_APPROVED':
        return Colors.green;
      case 'PAYMENT_FAILED':
        return Colors.red;
      case 'ORDER_CANCELLED':
        return Colors.red[700]!;
      case 'WAITING_FOR_PAYMENT':
        return Colors.orange;
      case 'READY_FOR_SHIPMENT':
        return Colors.blue;
      case 'ORDER_SHIPPED':
        return Colors.purple;
      case 'ORDER_DELIVERED':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionTypeIcon(String actionType) {
    switch (actionType) {
      case 'PAYMENT_APPROVED':
        return Icons.check_circle;
      case 'PAYMENT_FAILED':
        return Icons.error;
      case 'ORDER_CANCELLED':
        return Icons.cancel;
      case 'WAITING_FOR_PAYMENT':
        return Icons.payment;
      case 'READY_FOR_SHIPMENT':
        return Icons.inventory;
      case 'ORDER_SHIPPED':
        return Icons.local_shipping;
      case 'ORDER_DELIVERED':
        return Icons.home_delivery;
      default:
        return Icons.info;
    }
  }

  String _formatActionType(String actionType) {
    return actionType
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Widget _buildLogCard(dynamic log) {
    final orderId = log['order_id'];
    final customerName = log['customer_name'] ?? 'Unknown';
    final actionType = log['action_type'] ?? 'Unknown';
    final actionBy = log['action_by'] ?? 'System';
    final orderStatus = log['order_status'] ?? 'Unknown';
    final paymentStatus = log['payment_status'] ?? 'Unknown';
    final actionTimestamp = log['action_timestamp'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border.all(
          color: _getActionTypeColor(actionType).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with action type
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getActionTypeColor(actionType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getActionTypeIcon(actionType),
                    color: _getActionTypeColor(actionType),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatActionType(actionType),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getActionTypeColor(actionType),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Order #$orderId',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTimestamp(actionTimestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Customer and action by
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer: $customerName',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By: $actionBy',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    paymentStatus,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment Logs',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[400]!, Colors.blue[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchPaymentLogs(),
        child: isLoading && logs.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? _buildErrorView()
            : logs.isEmpty
            ? _buildEmptyView()
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: logs.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == logs.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return _buildLogCard(logs[index]);
                },
              ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
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
            onPressed: _fetchPaymentLogs,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.blue[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No payment logs found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Payment actions will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
