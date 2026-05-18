const express = require('express');
const router = express.Router();
const mysql = require('mysql2/promise');

// DB Connection
const pool = mysql.createPool({
  host: "localhost",
  user: "chatuser",
  password: "chat1234#db",
  database: "chat_db"
});

// Create new order
router.post('/create', async (req, res) => {
  const connection = await pool.getConnection();
  
  try {
    await connection.beginTransaction();
    
    const {
      user_id,
      total_amount,
      shipping_street,
      shipping_city,
      shipping_state,
      shipping_pincode,
      shipping_phone,
      payment_method,
      items
    } = req.body;

    console.log(`Creating order for user_id: ${user_id}`); // Debug log
    console.log('Order data:', { user_id, total_amount, items }); // Debug log

    // Get product info to determine company and branch routing
    let productCompanyId = null;
    let productBranchId = null;
    let assignedAdminId = null;
    
    if (items && items.length > 0) {
      const firstProductId = items[0].product_id;
      const [productInfo] = await connection.execute(
        `SELECT company_id, branch_id, published_by 
         FROM products WHERE id = ?`,
        [firstProductId]
      );
      
      if (productInfo.length > 0) {
        productCompanyId = productInfo[0].company_id;
        productBranchId = productInfo[0].branch_id;
        assignedAdminId = productInfo[0].published_by;
      }
    }

    // Create order with company and branch routing
    const [orderResult] = await connection.execute(
      `INSERT INTO orders (
        user_id, total_amount, shipping_street, shipping_city, 
        shipping_state, shipping_pincode, shipping_phone, 
        payment_method, order_status, payment_status, order_date,
        company_id, branch_id, assigned_admin_id, payment_waiting_since
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?)`,
      [
        user_id,
        total_amount,
        shipping_street,
        shipping_city,
        shipping_state,
        shipping_pincode,
        shipping_phone,
        payment_method,
        'Pending',
        'Pending',
        productCompanyId,
        productBranchId,
        assignedAdminId,
        null
      ]
    );

    const orderId = orderResult.insertId;

    // Insert order items with proper color and size names
    for (const item of items) {
      console.log('Processing item:', item); // Debug log
      
      // Get all sizes for this product
      const [sizes] = await connection.execute(
        `SELECT size FROM product_sizes WHERE product_id = ?`,
        [item.product_id]
      );
      console.log('Available sizes:', sizes); // Debug log
      
      // Get all colors for this product
      const [colors] = await connection.execute(
        `SELECT color_name FROM product_colors WHERE product_id = ?`,
        [item.product_id]
      );
      console.log('Available colors:', colors); // Debug log
      
      // Find matching size from frontend (case-insensitive)
      let sizeName = item.size || '';
      if (item.size && item.size !== '' && sizes.length > 0) {
        const foundSize = sizes.find(s => s.size && s.size.toLowerCase() === item.size.toLowerCase());
        if (foundSize) {
          sizeName = foundSize.size;
          console.log('Found size:', sizeName); // Debug log
        } else {
          console.log('Size not found:', item.size); // Debug log
        }
      }
      
      // Find matching color from frontend (case-insensitive)
      let colorName = item.color || '';
      if (item.color && item.color !== '' && colors.length > 0) {
        const foundColor = colors.find(c => c.color_name && c.color_name.toLowerCase() === item.color.toLowerCase());
        if (foundColor) {
          colorName = foundColor.color_name;
          console.log('Found color:', colorName); // Debug log
        } else {
          console.log('Color not found:', item.color); // Debug log
        }
      }

      console.log('Final values - Size:', sizeName, 'Color:', colorName); // Debug log

      // Get product details to save with order
      const [productDetails] = await connection.execute(
        `SELECT name, price, description FROM products WHERE id = ?`,
        [item.product_id]
      );

      const product = productDetails.length > 0 ? productDetails[0] : null;
      
      console.log('Product details for ID', item.product_id, ':', product); // Debug log

      // Get color-specific image for this item from product_colors table
      let colorImageUrl = null;
      if (item.color && item.color !== '') {
        const [colorImages] = await connection.execute(
          `SELECT image_url FROM product_colors 
           WHERE product_id = ? AND color_name = ?
           LIMIT 1`,
          [item.product_id, item.color]
        );
        if (colorImages.length > 0 && colorImages[0].image_url) {
          colorImageUrl = colorImages[0].image_url;
          console.log('Found color-specific image for', item.color, ':', colorImageUrl);
        }
      }
      
      // If no color-specific image, get product's first image from product_images
      if (!colorImageUrl) {
        const [productImages] = await connection.execute(
          `SELECT image_url FROM product_images WHERE product_id = ? LIMIT 1`,
          [item.product_id]
        );
        if (productImages.length > 0) {
          colorImageUrl = productImages[0].image_url;
        }
      }

      // Insert order item with product name and price from products table
      const finalPrice = product?.price || item?.price || 0;
      
      console.log('Price calculation - product.price:', product?.price, 'item.price:', item?.price, 'finalPrice:', finalPrice);
      
      await connection.execute(
        `INSERT INTO order_items (
          order_id, product_id, quantity, price, size, color, product_name, availability_status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          orderId,
          item.product_id,
          item.quantity,
          finalPrice,
          sizeName,
          colorName,
          product ? product.name : 'Unknown Product',
          0 // 0 = available by default
        ]
      );
    }

    await connection.commit();
    
    // Send notifications after successful order creation
    try {
      // Check if user is admin or regular user
      const [userRole] = await connection.execute(
        `SELECT uw.role FROM user_websites uw 
         WHERE uw.user_id = ? AND uw.status = 'Y' 
         ORDER BY uw.role DESC LIMIT 1`,
        [user_id]
      );
      
      const isAdmin = userRole.length > 0 && userRole[0].role === 'admin';
      console.log('User role check - userId:', user_id, 'isAdmin:', isAdmin);

      if (isAdmin) {
        // If admin placed order, only send order confirmation to admin
        console.log('Admin placed order, sending only order confirmation');
        await fetch('https://node-api.bangkokmart.in/api/notifications/order-confirmation', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            userId: user_id,
            orderId: orderId,
            orderDetails: {
              total_amount: total_amount,
              items: items
            }
          })
        });
      } else {
        // If regular user placed order, send all notifications
        console.log('Regular user placed order, sending all notifications');
        
        // Send order confirmation to user
        await fetch('https://node-api.bangkokmart.in/api/notifications/order-confirmation', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            userId: user_id,
            orderId: orderId,
            orderDetails: {
              total_amount: total_amount,
              items: items
            }
          })
        });

        // Send new order notification to admin
        await fetch('https://node-api.bangkokmart.in/api/notifications/new-order-admin', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            orderId: orderId
          })
        });

        // Send new order notification to sellers
        try {
          console.log('Sending seller notifications for order:', orderId);
          const sellerNotificationResponse = await fetch('https://node-api.bangkokmart.in/api/notifications/new-order-seller', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              orderId: orderId
            })
          });
          
          if (sellerNotificationResponse.ok) {
            const sellerResult = await sellerNotificationResponse.json();
            console.log('Seller notifications sent successfully:', sellerResult);
          } else {
            console.log('Failed to send seller notifications:', sellerNotificationResponse.status);
          }
        } catch (sellerError) {
          console.error('Error sending seller notifications:', sellerError);
        }
      }

      // Send notification to assigned branch admin if exists
      if (assignedAdminId) {
        try {
          const notificationData = {
            order_id: orderId,
            assigned_admin_id: assignedAdminId,
            company_id: productCompanyId,
            branch_id: productBranchId
          };
          
          const axios = require('axios');
          await axios.post(`${req.protocol}://${req.get('host')}/api/notifications/order-placed`, notificationData);
          console.log('📱 Branch admin notification sent:', assignedAdminId);
        } catch (branchNotificationError) {
          console.error('❌ Failed to send branch admin notification:', branchNotificationError.message);
        }
      }

      console.log('Notifications sent successfully for order:', orderId);
    } catch (notificationError) {
      console.error('Error sending notifications:', notificationError);
      // Don't fail the order creation if notifications fail
    }
    
    res.json({
      success: true,
      message: 'Order created successfully',
      order_id: orderId,
      total_amount: total_amount,
      assigned_admin_id: assignedAdminId
    });

  } catch (error) {
    await connection.rollback();
    console.error('Error creating order:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create order'
    });
  } finally {
    connection.release();
  }
});

// Get order details by ID
router.get('/:orderId', async (req, res) => {
  try {
    const { orderId } = req.params;

    // Get order details with product images and customer name (simplified)
    const [orderRows] = await pool.execute(`
      SELECT 
        o.*,
        u.name as customer_name,
        u.normalized_phone as customer_phone,
        COALESCE(o.delivery_fee, 250.00) as delivery_fee,
        pi.image_url,
        p.name as product_name,
        p.description as product_description,
        ready_user.name as ready_for_shipment_by_name,
        shipped_user.name as shipped_by_name,
        delivered_user.name as delivered_by_name
      FROM orders o
      LEFT JOIN users u ON o.user_id = u.user_id
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN products p ON oi.product_id = p.id
      LEFT JOIN product_images pi ON p.id = pi.product_id
      LEFT JOIN users ready_user ON o.ready_for_shipment_by = ready_user.user_id
      LEFT JOIN users shipped_user ON o.shipped_by = shipped_user.user_id
      LEFT JOIN users delivered_user ON o.delivered_by = delivered_user.user_id
      WHERE o.id = ?
      ORDER BY oi.id DESC
    `, [orderId]);

    if (orderRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }

    // Get order items with product images (color-specific from product_colors, fallback to product_images)
    const [itemRows] = await pool.execute(`
      SELECT 
        oi.*,
        oi.product_id,
        oi.quantity,
        oi.price,
        oi.size,
        oi.color,
        oi.availability_status,
        oi.available_quantity,
        oi.stock_status,
        oi.manual_stock_quantity,
        oi.use_manual_stock,
        p.name as product_name,
        p.stock,
        p.stock_mode,
        p.stock_by_color_size,
        COALESCE(pc.image_url, pi.image_url) as image_url
      FROM order_items oi
      LEFT JOIN products p ON oi.product_id = p.id
      LEFT JOIN product_colors pc ON oi.product_id = pc.product_id AND oi.color = pc.color_name
      LEFT JOIN product_images pi ON p.id = pi.product_id
      WHERE oi.order_id = ?
      ORDER BY oi.id DESC
    `, [orderId]);

    // Calculate real-time stock status for each item
    for (let item of itemRows) {
      const requestedQuantity = parseInt(item.quantity) || 1;
      let availableQuantity = requestedQuantity;
      let stockStatus = 'full';
      
      // Skip if availability_status is manually set to unavailable
      if (item.availability_status === 1) {
        item.available_quantity = 0;
        item.stock_status = 'out_of_stock';
        continue;
      }
      
      // Check if manual stock is enabled
      if (item.use_manual_stock && item.manual_stock_quantity !== null) {
        // Use manually set quantity
        availableQuantity = Math.min(item.manual_stock_quantity, requestedQuantity);
        if (item.manual_stock_quantity >= requestedQuantity) {
          stockStatus = 'full';
        } else if (item.manual_stock_quantity > 0) {
          stockStatus = 'partial';
        } else {
          stockStatus = 'out_of_stock';
        }
        console.log(`[OrderAPI] Using manual stock for ${item.product_name}: ${item.manual_stock_quantity} available, ${requestedQuantity} requested`);
      } else {
        // Check real-time stock from database
        if (item.stock_mode === 'color_size' && item.stock_by_color_size) {
          try {
            const stockData = JSON.parse(item.stock_by_color_size || '{}');
            const colorStock = stockData[item.color] || {};
            const sizeStock = colorStock[item.size] || 0;
            
            if (sizeStock >= requestedQuantity) {
              availableQuantity = requestedQuantity;
              stockStatus = 'full';
            } else if (sizeStock > 0) {
              availableQuantity = sizeStock;
              stockStatus = 'partial';
            } else {
              availableQuantity = 0;
              stockStatus = 'out_of_stock';
            }
          } catch (e) {
            // Fallback to simple stock
            if (item.stock >= requestedQuantity) {
              availableQuantity = requestedQuantity;
              stockStatus = 'full';
            } else if (item.stock > 0) {
              availableQuantity = item.stock;
              stockStatus = 'partial';
            } else {
              availableQuantity = 0;
              stockStatus = 'out_of_stock';
            }
          }
        } else {
          // Simple stock mode
          if (item.stock >= requestedQuantity) {
            availableQuantity = requestedQuantity;
            stockStatus = 'full';
          } else if (item.stock > 0) {
            availableQuantity = item.stock;
            stockStatus = 'partial';
          } else {
            availableQuantity = 0;
            stockStatus = 'out_of_stock';
          }
        }
      }
      
      // Update item with calculated values
      item.available_quantity = availableQuantity;
      item.stock_status = stockStatus;
    }

    res.json({
      success: true,
      order: orderRows[0],
      items: itemRows
    });

  } catch (error) {
    console.error('Error fetching order details:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get user orders
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    console.log(`Fetching orders for user_id: ${userId}`); // Debug log

    const [orders] = await pool.execute(
      'SELECT * FROM orders WHERE user_id = ? ORDER BY order_date DESC',
      [userId]
    );

    console.log(`Found ${orders.length} orders for user ${userId}`); // Debug log
    console.log('Orders data:', orders); // Debug log

    res.json({
      success: true,
      orders
    });

  } catch (error) {
    console.error('Error fetching user orders:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get order status counts for dashboard
router.get('/status-counts', async (req, res) => {
  try {
    const statuses = [
      'Pending',
      'Waiting for Payment', 
      'Ready for Shipment',
      'Shipped',
      'Delivered',
      'Cancelled'
    ];

    const counts = {};

    for (const status of statuses) {
      const [countResult] = await pool.execute(
        'SELECT COUNT(*) as count FROM orders WHERE order_status = ?',
        [status]
      );
      counts[status] = countResult[0].count;
    }

    res.json({
      success: true,
      counts
    });

  } catch (error) {
    console.error('Error fetching status counts:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get dashboard statistics
router.get('/dashboard/stats', async (req, res) => {
  try {
    // Get today's orders
    const [todayOrders] = await pool.execute(
      'SELECT COUNT(*) as count FROM orders WHERE DATE(order_date) = CURDATE()'
    );
    
    // Get yesterday's orders
    const [yesterdayOrders] = await pool.execute(
      'SELECT COUNT(*) as count FROM orders WHERE DATE(order_date) = DATE_SUB(CURDATE(), INTERVAL 1 DAY)'
    );
    
    // Get total orders
    const [totalOrders] = await pool.execute(
      'SELECT COUNT(*) as count FROM orders'
    );
    
    // Get cancelled orders
    const [cancelledOrders] = await pool.execute(
      'SELECT COUNT(*) as count FROM orders WHERE order_status = "Cancelled"'
    );
    
    // Get total revenue
    const [totalRevenue] = await pool.execute(
      'SELECT SUM(total_amount) as revenue FROM orders WHERE order_status != "Cancelled"'
    );
    
    // Get this week revenue
    const [weekRevenue] = await pool.execute(
      'SELECT SUM(total_amount) as revenue FROM orders WHERE order_status != "Cancelled" AND YEARWEEK(order_date) = YEARWEEK(CURDATE())'
    );
    
    // Get this month revenue
    const [monthRevenue] = await pool.execute(
      'SELECT SUM(total_amount) as revenue FROM orders WHERE order_status != "Cancelled" AND MONTH(order_date) = MONTH(CURDATE()) AND YEAR(order_date) = YEAR(CURDATE())'
    );

    res.json({
      success: true,
      stats: {
        todayOrders: todayOrders[0].count,
        yesterdayOrders: yesterdayOrders[0].count,
        totalOrders: totalOrders[0].count,
        cancelledOrders: cancelledOrders[0].count,
        totalRevenue: totalRevenue[0].revenue || 0,
        weekRevenue: weekRevenue[0].revenue || 0,
        monthRevenue: monthRevenue[0].revenue || 0
      }
    });

  } catch (error) {
    console.error('Error fetching dashboard stats:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get orders by status (for status-specific screens)
router.get('/', async (req, res) => {
  try {
    const { status, count } = req.query;
    
    if (status) {
      // Get orders by specific status
      if (count === 'true') {
        // Return only count for dashboard
        const [countResult] = await pool.execute(
          'SELECT COUNT(*) as count FROM orders WHERE order_status = ?',
          [status]
        );
        return res.json({
          success: true,
          count: countResult[0].count
        });
      } else {
        // Return orders for status screen
        const [orders] = await pool.execute(`
          SELECT 
            o.*,
            u.name as customer_name,
            u.normalized_phone as customer_phone,
            COUNT(oi.id) as item_count,
            ready_user.name as ready_for_shipment_by_name,
            shipped_user.name as shipped_by_name,
            delivered_user.name as delivered_by_name
          FROM orders o
          LEFT JOIN users u ON o.user_id = u.user_id
          LEFT JOIN order_items oi ON o.id = oi.order_id
          LEFT JOIN users ready_user ON o.ready_for_shipment_by = ready_user.user_id
          LEFT JOIN users shipped_user ON o.shipped_by = shipped_user.user_id
          LEFT JOIN users delivered_user ON o.delivered_by = delivered_user.user_id
          WHERE o.order_status = ?
          GROUP BY o.id
          ORDER BY o.order_date DESC
        `, [status]);

        return res.json({
          success: true,
          orders
        });
      }
    } else {
      // Get all orders if no status specified
      const [orders] = await pool.execute(`
        SELECT 
          o.*,
          u.name as customer_name,
          u.normalized_phone as customer_phone,
          COUNT(oi.id) as item_count,
          ready_user.name as ready_for_shipment_by_name,
          shipped_user.name as shipped_by_name,
          delivered_user.name as delivered_by_name
        FROM orders o
        LEFT JOIN users u ON o.user_id = u.user_id
        LEFT JOIN order_items oi ON o.id = oi.order_id
        LEFT JOIN users ready_user ON o.ready_for_shipment_by = ready_user.user_id
        LEFT JOIN users shipped_user ON o.shipped_by = shipped_user.user_id
        LEFT JOIN users delivered_user ON o.delivered_by = delivered_user.user_id
        GROUP BY o.id
        ORDER BY o.order_date DESC
      `);

      return res.json({
        success: true,
        orders
      });
    }
  } catch (error) {
    console.error('Error fetching orders:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get all orders for dashboard
router.get('/dashboard/all', async (req, res) => {
  try {
    const [orders] = await pool.execute(`
      SELECT 
        o.*,
        oi.product_name,
        pi.image_url,
        COUNT(oi.id) as item_count
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN product_images pi ON oi.product_id = pi.product_id
      GROUP BY o.id
      ORDER BY o.order_date DESC
    `);

    res.json({
      success: true,
      orders
    });

  } catch (error) {
    console.error('Error fetching all orders:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Update order status (PUT method for frontend compatibility)
router.put('/:orderId/status', async (req, res) => {
  try {
    const { orderId } = req.params;
    const { order_status, payment_status } = req.body;

    if (!order_status) {
      return res.status(400).json({
        success: false,
        message: 'Order status is required'
      });
    }

    let query, params;

    if (payment_status) {
      // Update both order_status and payment_status
      query = 'UPDATE orders SET order_status = ?, payment_status = ? WHERE id = ?';
      params = [order_status, payment_status, orderId];
    } else {
      // Update only order_status
      query = 'UPDATE orders SET order_status = ? WHERE id = ?';
      params = [order_status, orderId];
    }

    // Add payment_waiting_since timestamp when status changes to 'Waiting for Payment'
    if (order_status === 'Waiting for Payment') {
      query = query.replace('WHERE id = ?', ', payment_waiting_since = NOW() WHERE id = ?');
    }
    
    // Reset payment_waiting_since when payment is approved
    if (payment_status === 'paid') {
      query = query.replace('WHERE id = ?', ', payment_waiting_since = NULL WHERE id = ?');
    }
    
    // Track who performed status changes (only essential columns)
    const userId = req.user ? req.user.user_id : null;
    if (order_status === 'Ready for Shipment') {
      query = query.replace('WHERE id = ?', ', ready_for_shipment_by = ? WHERE id = ?');
      params.splice(params.length - 1, 0, userId);
    } else if (order_status === 'Shipped') {
      query = query.replace('WHERE id = ?', ', shipped_by = ? WHERE id = ?');
      params.splice(params.length - 1, 0, userId);
    } else if (order_status === 'Delivered') {
      query = query.replace('WHERE id = ?', ', delivered_by = ? WHERE id = ?');
      params.splice(params.length - 1, 0, userId);
    }

    const [result] = await pool.execute(query, params);

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }

    // Send notification based on status change
    try {
      await sendStatusNotification(orderId, order_status, payment_status);
      
      // Log payment status changes with user name
      await logPaymentAction(orderId, order_status, payment_status, req.user || null);
    } catch (notificationError) {
      console.error('Error sending status notification:', notificationError);
      // Don't fail the update if notification fails
    }

    res.json({
      success: true,
      message: `Order status updated to ${order_status} successfully`
    });

  } catch (error) {
    console.error('Error updating order status:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Helper function to log payment actions
async function logPaymentAction(orderId, orderStatus, paymentStatus, user) {
  try {
    const connection = await pool.getConnection();
    
    // Get order details for logging
    const [orderDetails] = await connection.execute(
      'SELECT o.*, u.name as customer_name FROM orders o LEFT JOIN users u ON o.user_id = u.user_id WHERE o.id = ?',
      [orderId]
    );

    if (orderDetails.length === 0) {
      connection.release();
      return;
    }

    const order = orderDetails[0];
    const actionBy = user ? user.name : 'System';
    const actionType = paymentStatus === 'paid' ? 'PAYMENT_APPROVED' : 
                      paymentStatus === 'failed' ? 'PAYMENT_FAILED' :
                      orderStatus === 'Cancelled' ? 'ORDER_CANCELLED' :
                      orderStatus === 'Waiting for Payment' ? 'WAITING_FOR_PAYMENT' :
                      orderStatus === 'Ready for Shipment' ? 'READY_FOR_SHIPMENT' :
                      orderStatus === 'Shipped' ? 'ORDER_SHIPPED' :
                      orderStatus === 'Delivered' ? 'ORDER_DELIVERED' :
                      'STATUS_UPDATE';

    // Log the action
    await connection.execute(
      `INSERT INTO payment_logs (
        order_id, customer_name, action_type, action_by, 
        order_status, payment_status, action_timestamp, details
      ) VALUES (?, ?, ?, ?, ?, ?, NOW(), ?)`,
      [
        orderId,
        order.customer_name || 'Unknown Customer',
        actionType,
        actionBy,
        orderStatus,
        paymentStatus,
        JSON.stringify({
          total_amount: order.total_amount,
          payment_method: order.payment_method,
          order_date: order.order_date,
          user_id: order.user_id
        })
      ]
    );

    console.log(`[PaymentLog] ${actionType} for order #${orderId} by ${actionBy} - Customer: ${order.customer_name}`);
    connection.release();
  } catch (error) {
    console.error('Error logging payment action:', error);
  }
}

// Helper function to send status notifications
async function sendStatusNotification(orderId, newStatus, paymentStatus) {
  try {
    // Get order details for notification
    const [orderDetails] = await pool.execute(
      'SELECT o.*, u.name as customer_name, u.normalized_phone as customer_phone FROM orders o LEFT JOIN users u ON o.user_id = u.user_id WHERE o.id = ?',
      [orderId]
    );

    if (orderDetails.length === 0) return;

    const order = orderDetails[0];

    // Send different notifications based on status
    switch (newStatus) {
      case 'Waiting for Payment':
        await fetch('https://node-api.bangkokmart.in/api/notifications/order-status-change', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            orderId,
            status: newStatus,
            customerName: order.customer_name,
            customerPhone: order.customer_phone,
            message: 'Your order is now waiting for payment confirmation.'
          })
        });
        break;

      case 'Ready for Shipment':
        await fetch('https://node-api.bangkokmart.in/api/notifications/order-status-change', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            orderId,
            status: newStatus,
            customerName: order.customer_name,
            customerPhone: order.customer_phone,
            message: 'Payment confirmed! Your order is ready for shipment.'
          })
        });
        break;

      case 'Shipped':
        await fetch('https://node-api.bangkokmart.in/api/notifications/order-status-change', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            orderId,
            status: newStatus,
            customerName: order.customer_name,
            customerPhone: order.customer_phone,
            message: 'Your order has been shipped and is on its way!'
          })
        });
        break;

      case 'Delivered':
        await fetch('https://node-api.bangkokmart.in/api/notifications/order-status-change', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            orderId,
            status: newStatus,
            customerName: order.customer_name,
            customerPhone: order.customer_phone,
            message: 'Your order has been successfully delivered!'
          })
        });
        break;

      case 'Cancelled':
        await fetch('https://node-api.bangkokmart.in/api/notifications/order-status-change', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            orderId,
            status: newStatus,
            customerName: order.customer_name,
            customerPhone: order.customer_phone,
            message: 'Your order has been cancelled.'
          })
        });
        break;
    }
  } catch (error) {
    console.error('Error in sendStatusNotification:', error);
    throw error;
  }
}

// Update order status (PATCH method - keep for backward compatibility)
router.patch('/:orderId/status', async (req, res) => {
  try {
    const { orderId } = req.params;
    const { order_status } = req.body;

    if (!order_status) {
      return res.status(400).json({
        success: false,
        message: 'Order status is required'
      });
    }

    const [result] = await pool.execute(
      'UPDATE orders SET order_status = ? WHERE id = ?',
      [order_status, orderId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }

    res.json({
      success: true,
      message: 'Order status updated successfully'
    });

  } catch (error) {
    console.error('Error updating order status:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Update payment status (automatic for 5-minute window)
router.patch('/:orderId/payment-status', async (req, res) => {
  try {
    const { orderId } = req.params;
    const { payment_status, payment_method } = req.body;

    if (!payment_status) {
      return res.status(400).json({
        success: false,
        message: 'Payment status is required'
      });
    }

    // Get order details to check timing
    const [orderDetails] = await pool.execute(
      'SELECT order_date, payment_status FROM orders WHERE id = ?',
      [orderId]
    );

    if (orderDetails.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }

    const order = orderDetails[0];
    const orderDate = new Date(order.order_date);
    const currentTime = new Date();
    const timeDiff = (currentTime - orderDate) / (1000 * 60); // Difference in minutes

    // Check if payment is being updated within 5 minutes (automatic update)
    const isAutomaticUpdate = timeDiff <= 5 && payment_status === 'paid';

    if (isAutomaticUpdate) {
      // Automatic payment status update within 5 minutes
      const [result] = await pool.execute(
        'UPDATE orders SET payment_status = ?, order_status = ?, payment_method = ? WHERE id = ?',
        [payment_status, 'Ready for Shipment', payment_method || 'UPI', orderId]
      );

      if (result.affectedRows === 0) {
        return res.status(404).json({
          success: false,
          message: 'Order not found'
        });
      }

      res.json({
        success: true,
        message: 'Payment status updated automatically within 5 minutes',
        automatic_update: true
      });
    } else {
      // Manual payment status update (after 5 minutes)
      const [result] = await pool.execute(
        'UPDATE orders SET payment_status = ?, order_status = ? WHERE id = ?',
        [payment_status, payment_status === 'paid' ? 'Ready for Shipment' : 'pending', orderId]
      );

      if (result.affectedRows === 0) {
        return res.status(404).json({
          success: false,
          message: 'Order not found'
        });
      }

      res.json({
        success: true,
        message: 'Payment status updated manually',
        automatic_update: false
      });
    }

  } catch (error) {
    console.error('Error updating payment status:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get payment status for an order
router.get('/:orderId/payment-status', async (req, res) => {
  try {
    const { orderId } = req.params;

    const [orderDetails] = await pool.execute(
      'SELECT payment_status, order_status, order_date FROM orders WHERE id = ?',
      [orderId]
    );

    if (orderDetails.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }

    const order = orderDetails[0];
    const orderDate = new Date(order.order_date);
    const currentTime = new Date();
    const timeDiff = (currentTime - orderDate) / (1000 * 60); // Difference in minutes

    res.json({
      success: true,
      payment_status: order.payment_status,
      order_status: order.order_status,
      time_elapsed_minutes: Math.round(timeDiff),
      is_within_5_minutes: timeDiff <= 5
    });

  } catch (error) {
    console.error('Error fetching payment status:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Manual payment confirmation with screenshot upload
router.post('/:orderId/confirm-payment', async (req, res) => {
  try {
    const { orderId } = req.params;
    const { payment_method, transaction_id, notes } = req.body;

    // Get order details
    const [orderDetails] = await pool.execute(
      'SELECT order_date FROM orders WHERE id = ?',
      [orderId]
    );

    if (orderDetails.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }

    const order = orderDetails[0];
    const orderDate = new Date(order.order_date);
    const currentTime = new Date();
    const timeDiff = (currentTime - orderDate) / (1000 * 60); // Difference in minutes

    // Update payment status manually
    const [result] = await pool.execute(
      `UPDATE orders SET 
        payment_status = ?, 
        order_status = ?, 
        payment_method = ?,
        transaction_id = ?,
        payment_notes = ?,
        updated_at = NOW()
       WHERE id = ?`,
      ['paid', 'Ready for Shipment', payment_method || 'Manual', transaction_id || null, notes || null, orderId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }

    res.json({
      success: true,
      message: timeDiff <= 5 ? 
        'Payment confirmed automatically within 5 minutes' : 
        'Payment confirmed manually',
      automatic_update: timeDiff <= 5,
      time_elapsed_minutes: Math.round(timeDiff)
    });

  } catch (error) {
    console.error('Error confirming payment:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Create test order
router.post('/create-test', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    await connection.beginTransaction();
    
    const {
      user_id,
      total_amount,
      shipping_street,
      shipping_city,
      shipping_state,
      shipping_pincode,
      shipping_phone,
      payment_method,
      items
    } = req.body;

    // Create order
    const [orderResult] = await connection.execute(
      `INSERT INTO orders (
        user_id, total_amount, shipping_street, shipping_city, 
        shipping_state, shipping_pincode, shipping_phone, 
        payment_method, order_status, payment_status, order_date
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        user_id,
        total_amount,
        shipping_street,
        shipping_city,
        shipping_state,
        shipping_pincode,
        shipping_phone,
        payment_method,
        'Pending',
        'Pending'
      ]
    );

    const orderId = orderResult.insertId;

    // Insert order item
    await connection.execute(
      `INSERT INTO order_items (
        order_id, product_id, quantity, price, size, color, product_name, availability_status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        orderId,
        items[0].product_id,
        items[0].quantity,
        items[0].price,
        items[0].size,
        items[0].color,
        'Test Product',
        0 // 0 = available by default
      ]
    );

    await connection.commit();
    
    res.json({
      success: true,
      message: 'Test order created successfully',
      orderId: orderId
    });

  } catch (error) {
    await connection.rollback();
    console.error('Error creating test order:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create test order'
    });
  } finally {
    connection.release();
  }
});

// Get orders for a specific website (admin only)
router.get('/website/:websiteId', async (req, res) => {
  try {
    const { websiteId } = req.params;
    
    const [orders] = await pool.execute(`
      SELECT DISTINCT o.*, u.name as customer_name, u.normalized_phone as customer_phone, w.website_name
      FROM orders o
      INNER JOIN users u ON o.user_id = u.user_id
      INNER JOIN user_websites uw ON u.user_id = uw.user_id
      INNER JOIN websites w ON uw.website_id = w.website_id
      WHERE uw.website_id = ? AND uw.status = 'Y'
      ORDER BY o.order_date DESC
    `, [websiteId]);

    res.json({
      success: true,
      orders
    });

  } catch (error) {
    console.error('Error fetching website orders:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get admin dashboard statistics (for admin users)
router.get('/admin/dashboard', async (req, res) => {
  try {
    const { userId } = req.query;
    
    if (!userId) {
      return res.status(400).json({
        success: false,
        message: 'User ID is required'
      });
    }

    // Check if user is admin for any website
    const [adminWebsites] = await pool.execute(`
      SELECT DISTINCT w.website_id, w.website_name, w.domain
      FROM websites w
      INNER JOIN user_websites uw ON w.website_id = uw.website_id
      WHERE uw.user_id = ? AND uw.role = 'admin' AND uw.status = 'Y'
    `, [userId]);

    if (adminWebsites.length === 0) {
      return res.status(403).json({
        success: false,
        message: 'User is not an admin for any website'
      });
    }

    // Get website IDs for admin
    const websiteIds = adminWebsites.map(w => w.website_id);
    
    // Get all orders for these websites (using user_websites table)
    const [orders] = await pool.execute(`
      SELECT DISTINCT o.*, u.name as customer_name, u.normalized_phone as customer_phone, w.website_name
      FROM orders o
      INNER JOIN users u ON o.user_id = u.user_id
      INNER JOIN user_websites uw ON u.user_id = uw.user_id
      INNER JOIN websites w ON uw.website_id = w.website_id
      WHERE uw.website_id IN (${websiteIds.map(() => '?').join(',')}) AND uw.status = 'Y'
      ORDER BY o.order_date DESC
    `, websiteIds);

    // Get all products for these websites (using product_domain_visibility table)
    const [products] = await pool.execute(`
      SELECT DISTINCT p.*, pi.image_url, pdv.domain_id as website_id
      FROM products p
      LEFT JOIN product_images pi ON p.id = pi.product_id
      LEFT JOIN product_domain_visibility pdv ON p.id = pdv.product_id
      WHERE pdv.domain_id IN (${websiteIds.map(() => '?').join(',')}) AND pdv.is_visible = 1
      ORDER BY p.created_at DESC
    `, websiteIds);

    // Calculate statistics
    const today = new Date();
    const todayOrders = orders.filter(order => {
      const orderDate = new Date(order.order_date);
      return orderDate.toDateString() === today.toDateString();
    });

    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayOrders = orders.filter(order => {
      const orderDate = new Date(order.order_date);
      return orderDate.toDateString() === yesterday.toDateString();
    });

    const cancelledOrders = orders.filter(order => 
      order.order_status?.toLowerCase() === 'cancelled'
    );

    const totalRevenue = orders
      .filter(order => order.order_status?.toLowerCase() !== 'cancelled')
      .reduce((sum, order) => sum + parseFloat(order.total_amount || 0), 0);

    const weekRevenue = orders
      .filter(order => {
        const orderDate = new Date(order.order_date);
        const weekStart = new Date(today);
        weekStart.setDate(today.getDate() - today.getDay());
        return orderDate >= weekStart && order.order_status?.toLowerCase() !== 'cancelled';
      })
      .reduce((sum, order) => sum + parseFloat(order.total_amount || 0), 0);

    const monthRevenue = orders
      .filter(order => {
        const orderDate = new Date(order.order_date);
        return orderDate.getMonth() === today.getMonth() && 
               orderDate.getFullYear() === today.getFullYear() &&
               order.order_status?.toLowerCase() !== 'cancelled';
      })
      .reduce((sum, order) => sum + parseFloat(order.total_amount || 0), 0);

    res.json({
      success: true,
      data: {
        websites: adminWebsites,
        stats: {
          todayOrders: todayOrders.length,
          yesterdayOrders: yesterdayOrders.length,
          totalOrders: orders.length,
          cancelledOrders: cancelledOrders.length,
          totalRevenue: totalRevenue,
          weekRevenue: weekRevenue,
          monthRevenue: monthRevenue
        },
        orders: orders,
        products: products
      }
    });

  } catch (error) {
    console.error('Error fetching admin dashboard:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Route: Update Manual Stock Quantity
router.post('/update-manual-stock', async (req, res) => {
  try {
    const { orderId, itemId, manualStockQuantity, useManualStock } = req.body;
    console.log(`[UpdateManualStock] Request: orderId=${orderId}, itemId=${itemId}, manualStockQuantity=${manualStockQuantity}, useManualStock=${useManualStock} (type: ${typeof useManualStock})`);

    if (!orderId || !itemId) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: orderId, itemId'
      });
    }

    // Validate manualStockQuantity
    if (manualStockQuantity !== null && manualStockQuantity !== undefined) {
      if (isNaN(manualStockQuantity) || manualStockQuantity < 0) {
        return res.status(400).json({
          success: false,
          message: 'manualStockQuantity must be a non-negative number'
        });
      }
    }

    // Update the manual stock quantity in order_items table
    const useManualStockValue = useManualStock === true ? 1 : 0;
    console.log(`[UpdateManualStock] SQL: UPDATE order_items SET manual_stock_quantity = ?, use_manual_stock = ? WHERE id = ? AND order_id = ?`);
    console.log(`[UpdateManualStock] Values: ${manualStockQuantity}, ${useManualStockValue}, ${itemId}, ${orderId}`);
    
    const [result] = await pool.execute(
      'UPDATE order_items SET manual_stock_quantity = ?, use_manual_stock = ? WHERE id = ? AND order_id = ?',
      [manualStockQuantity, useManualStockValue, itemId, orderId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Order item not found'
      });
    }

    console.log(`[UpdateManualStock] Updated item ${itemId} in order ${orderId} - Manual Stock: ${manualStockQuantity}, Use Manual: ${useManualStock}`);

    // Verify the update was successful
    const [verifyResult] = await pool.execute(
      'SELECT manual_stock_quantity, use_manual_stock FROM order_items WHERE id = ? AND order_id = ?',
      [itemId, orderId]
    );
    
    if (verifyResult.length > 0) {
      console.log(`[UpdateManualStock] Verification - manual_stock_quantity: ${verifyResult[0].manual_stock_quantity}, use_manual_stock: ${verifyResult[0].use_manual_stock} (type: ${typeof verifyResult[0].use_manual_stock})`);
    }

    res.json({
      success: true,
      message: 'Manual stock updated successfully',
      data: {
        orderId: orderId,
        itemId: itemId,
        manualStockQuantity: manualStockQuantity,
        useManualStock: useManualStock
      }
    });

  } catch (error) {
    console.error('Error updating manual stock:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

// Route: Update Item Availability Status
router.post('/update-availability', async (req, res) => {
  const connection = await pool.getConnection();
  
  try {
    await connection.beginTransaction();
    
    const { orderId, itemId, availabilityStatus } = req.body;

    if (!orderId || !itemId || availabilityStatus === undefined) {
      await connection.rollback();
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: orderId, itemId, availabilityStatus'
      });
    }

    // Get order details and item details before updating
    const [orderDetails] = await connection.execute(
      'SELECT * FROM orders WHERE id = ?',
      [orderId]
    );

    if (orderDetails.length === 0) {
      await connection.rollback();
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }

    const order = orderDetails[0];
    
    // Only proceed with deletion if order is in 'Pending' status
    if (order.order_status !== 'Pending') {
      await connection.rollback();
      return res.status(400).json({
        success: false,
        message: 'Product variants can only be deleted from pending orders'
      });
    }

    // Get item details to identify product variants
    const [itemDetails] = await connection.execute(
      'SELECT * FROM order_items WHERE id = ? AND order_id = ?',
      [itemId, orderId]
    );

    if (itemDetails.length === 0) {
      await connection.rollback();
      return res.status(404).json({
        success: false,
        message: 'Order item not found'
      });
    }

    const item = itemDetails[0];
    const productId = item.product_id;
    const color = item.color;
    const size = item.size;

    // Update availability status in order_items table
    const [result] = await connection.execute(
      'UPDATE order_items SET availability_status = ? WHERE id = ? AND order_id = ?',
      [availabilityStatus, itemId, orderId]
    );

    if (result.affectedRows === 0) {
      await connection.rollback();
      return res.status(404).json({
        success: false,
        message: 'Order item not found'
      });
    }

    console.log(`[UpdateAvailability] Updated item ${itemId} in order ${orderId} - Availability: ${availabilityStatus === 1 ? 'Not Available' : 'Available'}`);

    // If availability status is set to "Not Available" (1), delete the product variants
    if (availabilityStatus === 1) {
      console.log(`[DeleteVariants] Deleting variants for product ${productId}, color: ${color}, size: ${size}`);
      
      let deletedVariants = [];

      // Delete from product_variants table (color+size combinations)
      if (color && size) {
        const [variantResult] = await connection.execute(
          'DELETE FROM product_variants WHERE product_id = ? AND color_name = ? AND size = ?',
          [productId, color, size]
        );
        
        if (variantResult.affectedRows > 0) {
          deletedVariants.push(`product_variants: ${variantResult.affectedRows} deleted`);
          console.log(`[DeleteVariants] Deleted ${variantResult.affectedRows} variants from product_variants table`);
        }
      }

      // Delete from product_colors table if only color is specified
      if (color && !size) {
        const [colorResult] = await connection.execute(
          'DELETE FROM product_colors WHERE product_id = ? AND color_name = ?',
          [productId, color]
        );
        
        if (colorResult.affectedRows > 0) {
          deletedVariants.push(`product_colors: ${colorResult.affectedRows} deleted`);
          console.log(`[DeleteVariants] Deleted ${colorResult.affectedRows} variants from product_colors table`);
        }
      }

      // Delete from product_sizes table if only size is specified
      if (size && !color) {
        const [sizeResult] = await connection.execute(
          'DELETE FROM product_sizes WHERE product_id = ? AND size = ?',
          [productId, size]
        );
        
        if (sizeResult.affectedRows > 0) {
          deletedVariants.push(`product_sizes: ${sizeResult.affectedRows} deleted`);
          console.log(`[DeleteVariants] Deleted ${sizeResult.affectedRows} variants from product_sizes table`);
        }
      }

      // NOW ALSO DELETE FROM PRODUCTS TABLE JSON COLUMNS
      console.log(`[DeleteVariants] Updating products table JSON columns for product ${productId}`);
      
      // Get current product data
      const [productData] = await connection.execute(
        'SELECT variations, sizes, stock_by_color_size FROM products WHERE id = ?',
        [productId]
      );

      if (productData.length > 0) {
        const product = productData[0];
        let updatedVariations = [];
        let updatedSizes = [];
        let updatedStockByColorSize = {};

        // Parse existing JSON data
        try {
          updatedVariations = JSON.parse(product.variations || '[]');
        } catch (e) {
          updatedVariations = [];
        }

        try {
          updatedSizes = JSON.parse(product.sizes || '[]');
        } catch (e) {
          updatedSizes = [];
        }

        try {
          updatedStockByColorSize = JSON.parse(product.stock_by_color_size || '{}');
        } catch (e) {
          updatedStockByColorSize = {};
        }

        // Update variations array - ONLY remove size from stock, NEVER delete entire variation
        // Color variations should remain even if sizes become unavailable
        if (color) {
          const colorVariantIndex = updatedVariations.findIndex(v => v.name === color);
          
          if (colorVariantIndex !== -1) {
            const colorVariant = updatedVariations[colorVariantIndex];
            
            // Remove the specific size from stock ONLY
            if (size && colorVariant.stock && typeof colorVariant.stock === 'object') {
              delete colorVariant.stock[size];
              deletedVariants.push(`variations: removed size "${size}" from color "${color}"`);
              console.log(`[DeleteVariants] Removed size "${size}" from color "${color}" stock`);
              console.log(`[DeleteVariants] Kept color "${color}" variation with remaining sizes`);
            } else if (!size) {
              // If no size specified, remove entire color (this is for color-only products)
              updatedVariations.splice(colorVariantIndex, 1);
              deletedVariants.push(`variations: removed color "${color}" (no size specified)`);
              console.log(`[DeleteVariants] Removed color "${color}" from variations (no size specified)`);
            }
          } else {
            console.log(`[DeleteVariants] Color "${color}" not found in variations array`);
          }
        }

        // Remove size from sizes array ONLY if not used by other colors
        if (size) {
          // Check if this size is used by other colors in stock_by_color_size
          let sizeUsedByOtherColors = false;
          for (const colorName in updatedStockByColorSize) {
            if (colorName !== color && updatedStockByColorSize[colorName][size] !== undefined) {
              sizeUsedByOtherColors = true;
              break;
            }
          }
          
          // Also check if this size is used by other variations
          if (!sizeUsedByOtherColors && updatedVariations.length > 0) {
            for (const variant of updatedVariations) {
              if (variant.name !== color && variant.stock && typeof variant.stock === 'object' && variant.stock[size] !== undefined) {
                sizeUsedByOtherColors = true;
                break;
              }
            }
          }
          
          // Only remove size if not used by any other color
          if (!sizeUsedByOtherColors) {
            const originalLength = updatedSizes.length;
            updatedSizes = updatedSizes.filter(s => s !== size);
            if (updatedSizes.length < originalLength) {
              deletedVariants.push(`sizes: removed size "${size}" (not used by other colors)`);
              console.log(`[DeleteVariants] Removed size "${size}" from sizes array (not used by other colors)`);
            }
          } else {
            console.log(`[DeleteVariants] Kept size "${size}" in sizes array (used by other colors)`);
          }
        }

        // Remove from stock_by_color_size JSON
        if (color && size && updatedStockByColorSize[color]) {
          if (updatedStockByColorSize[color][size] !== undefined) {
            delete updatedStockByColorSize[color][size];
            deletedVariants.push(`stock_by_color_size: removed ${color}-${size}`);
            console.log(`[DeleteVariants] Removed ${color}-${size} from stock_by_color_size`);
            
            // If no more sizes left for this color, remove the color entirely
            if (Object.keys(updatedStockByColorSize[color]).length === 0) {
              delete updatedStockByColorSize[color];
              deletedVariants.push(`stock_by_color_size: removed color "${color}" (no sizes left)`);
              console.log(`[DeleteVariants] Removed color "${color}" from stock_by_color_size (no sizes left)`);
            }
          }
        } else if (color && updatedStockByColorSize[color]) {
          // If only color specified, remove entire color from stock_by_color_size
          delete updatedStockByColorSize[color];
          deletedVariants.push(`stock_by_color_size: removed color "${color}" (all sizes)`);
          console.log(`[DeleteVariants] Removed color "${color}" from stock_by_color_size (all sizes)`);
        }

        // Update products table with modified JSON data
        const [updateResult] = await connection.execute(
          'UPDATE products SET variations = ?, sizes = ?, stock_by_color_size = ? WHERE id = ?',
          [
            JSON.stringify(updatedVariations),
            JSON.stringify(updatedSizes),
            JSON.stringify(updatedStockByColorSize),
            productId
          ]
        );

        if (updateResult.affectedRows > 0) {
          deletedVariants.push('products table: JSON columns updated');
          console.log(`[DeleteVariants] Updated products table JSON columns`);
        }
      }

      await connection.commit();

      console.log(`[DeleteVariants] Successfully deleted variants: ${deletedVariants.join(', ')}`);

      res.json({
        success: true,
        message: 'Availability status updated and product variants deleted successfully',
        data: {
          orderId: orderId,
          itemId: itemId,
          availabilityStatus: availabilityStatus,
          deletedVariants: deletedVariants
        }
      });

    } else {
      // If availability is set to "Available" (0), just update the status
      await connection.commit();

      res.json({
        success: true,
        message: 'Availability status updated successfully',
        data: {
          orderId: orderId,
          itemId: itemId,
          availabilityStatus: availabilityStatus
        }
      });
    }

  } catch (error) {
    await connection.rollback();
    console.error('Error updating availability status:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  } finally {
    connection.release();
  }
});

// Check and cancel expired payment orders (30-minute timeout)
router.post('/check-expired-payments', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    
    // Find orders that have been waiting for payment for more than 30 minutes
    const [expiredOrders] = await connection.execute(`
      SELECT o.*, u.name as customer_name, u.normalized_phone as customer_phone
      FROM orders o
      LEFT JOIN users u ON o.user_id = u.user_id
      WHERE o.order_status = 'Waiting for Payment'
      AND o.payment_waiting_since IS NOT NULL
      AND TIMESTAMPDIFF(MINUTE, o.payment_waiting_since, NOW()) > 30
    `);

    console.log(`[PaymentTimeout] Found ${expiredOrders.length} expired payment orders`);

    const cancelledOrders = [];
    
    for (const order of expiredOrders) {
      try {
        // Update order status to Cancelled
        await connection.execute(
          'UPDATE orders SET order_status = ?, payment_status = ?, payment_waiting_since = NULL WHERE id = ?',
          ['Cancelled', 'expired', order.id]
        );
        
        // Log the automatic cancellation
        await logPaymentAction(order.id, 'Cancelled', 'expired', null);
        
        // Send notification to customer about automatic cancellation
        try {
          await fetch('https://node-api.bangkokmart.in/api/notifications/order-status-change', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              orderId: order.id,
              status: 'Cancelled',
              customerName: order.customer_name,
              customerPhone: order.customer_phone,
              message: 'Your order was automatically cancelled due to payment timeout. Please place a new order on BangkokMart.'
            })
          });
        } catch (notificationError) {
          console.error('Failed to send cancellation notification:', notificationError);
        }
        
        cancelledOrders.push({
          orderId: order.id,
          customerName: order.customer_name,
          totalAmount: order.total_amount,
          waitingMinutes: Math.floor((new Date() - new Date(order.payment_waiting_since)) / (1000 * 60))
        });
        
        console.log(`[PaymentTimeout] Auto-cancelled order #${order.id} for customer ${order.customer_name}`);
      } catch (error) {
        console.error(`[PaymentTimeout] Failed to cancel order #${order.id}:`, error);
      }
    }
    
    connection.release();
    
    res.json({
      success: true,
      message: `Checked expired payments. Cancelled ${cancelledOrders.length} orders.`,
      cancelled_orders: cancelledOrders
    });
    
  } catch (error) {
    console.error('Error checking expired payments:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to check expired payments'
    });
  }
});

// Get payment logs for admin dashboard
router.get('/payment-logs', async (req, res) => {
  try {
    const { limit = 50, offset = 0, order_id } = req.query;
    
    let query = `
      SELECT * FROM payment_logs 
      ORDER BY action_timestamp DESC 
      LIMIT ? OFFSET ?
    `;
    let params = [parseInt(limit), parseInt(offset)];
    
    if (order_id) {
      query = `
        SELECT * FROM payment_logs 
        WHERE order_id = ?
        ORDER BY action_timestamp DESC 
        LIMIT ? OFFSET ?
      `;
      params = [order_id, parseInt(limit), parseInt(offset)];
    }
    
    const [logs] = await pool.execute(query, params);
    
    res.json({
      success: true,
      logs
    });
    
  } catch (error) {
    console.error('Error fetching payment logs:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch payment logs'
    });
  }
});

module.exports = router;
