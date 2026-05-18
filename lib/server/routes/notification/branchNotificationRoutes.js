const express = require('express');
const router = express.Router();
const mysql = require('mysql2/promise');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  try {
    const serviceAccount = require('../firebase-service-account.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
  } catch (error) {
    console.log('Firebase Admin already initialized or service account not found');
  }
}

// DB Connection
const pool = mysql.createPool({
  host: "localhost",
  user: "chatuser",
  password: "chat1234#db",
  database: "chat_db"
});

// Send notification to branch admin when order is placed
router.post('/order-placed', async (req, res) => {
  try {
    const { order_id, assigned_admin_id, company_id, branch_id } = req.body;
    
    if (!order_id || !assigned_admin_id) {
      return res.status(400).json({ 
        success: false, 
        message: 'order_id and assigned_admin_id are required' 
      });
    }

    // Get admin details
    const [adminInfo] = await pool.execute(
      'SELECT name, phone, email, fcm_token FROM users WHERE user_id = ?',
      [assigned_admin_id]
    );

    if (adminInfo.length === 0) {
      return res.status(404).json({ success: false, message: 'Admin not found' });
    }

    const admin = adminInfo[0];

    // Get order details
    const [orderInfo] = await pool.execute(`
      SELECT o.*, c.company_name, b.branch_name, u.name as customer_name
      FROM orders o
      LEFT JOIN companies c ON o.company_id = c.company_id
      LEFT JOIN branches b ON o.branch_id = b.branch_id
      LEFT JOIN users u ON o.user_id = u.user_id
      WHERE o.id = ?
    `, [order_id]);

    if (orderInfo.length === 0) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const order = orderInfo[0];

    // Send FCM notification if token exists
    let fcmResult = null;
    if (admin.fcm_token) {
      try {
        const message = {
          token: admin.fcm_token,
          notification: {
            title: '🛒 New Order Received',
            body: `New order #${order_id} from ${order.customer_name || 'Customer'} - ₹${order.total_amount}`
          },
          data: {
            type: 'new_order',
            order_id: order_id.toString(),
            company_id: company_id?.toString() || '',
            branch_id: branch_id?.toString() || '',
            total_amount: order.total_amount.toString(),
            customer_name: order.customer_name || 'Customer'
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              clickAction: 'FLUTTER_NOTIFICATION_CLICK'
            }
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1
              }
            }
          }
        };

        fcmResult = await admin.messaging().send(message);
        console.log('FCM notification sent successfully:', fcmResult);
      } catch (fcmError) {
        console.error('FCM notification failed:', fcmError);
        // Don't fail the request if FCM fails
      }
    }

    // Store notification in database
    await pool.execute(`
      INSERT INTO notifications (
        user_id, title, message, type, data, created_at
      ) VALUES (?, ?, ?, ?, ?, NOW())
    `, [
      assigned_admin_id,
      'New Order Received',
      `Order #${order_id} received from ${order.customer_name || 'Customer'} for ₹${order.total_amount}`,
      'new_order',
      JSON.stringify({
        order_id,
        company_id,
        branch_id,
        total_amount: order.total_amount,
        customer_name: order.customer_name
      })
    ]);

    res.json({ 
      success: true, 
      message: 'Notification sent successfully',
      fcm_sent: !!fcmResult,
      admin_name: admin.name
    });

  } catch (error) {
    console.error('Error sending order notification:', error);
    res.status(500).json({ success: false, message: 'Failed to send notification' });
  }
});

// Get notifications for a user
router.get('/user/:user_id', async (req, res) => {
  try {
    const { user_id } = req.params;
    const { limit = 20, offset = 0 } = req.query;
    
    const [notifications] = await pool.execute(`
      SELECT * FROM notifications 
      WHERE user_id = ? 
      ORDER BY created_at DESC 
      LIMIT ? OFFSET ?
    `, [user_id, parseInt(limit), parseInt(offset)]);
    
    res.json({ success: true, data: notifications });
  } catch (error) {
    console.error('Error fetching notifications:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch notifications' });
  }
});

// Mark notification as read
router.put('/:notification_id/read', async (req, res) => {
  try {
    const { notification_id } = req.params;
    
    const [result] = await pool.execute(
      'UPDATE notifications SET read_at = NOW() WHERE id = ?',
      [notification_id]
    );
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }
    
    res.json({ success: true, message: 'Notification marked as read' });
  } catch (error) {
    console.error('Error marking notification as read:', error);
    res.status(500).json({ success: false, message: 'Failed to mark notification as read' });
  }
});

// Send custom notification to branch admins
router.post('/branch-admins', async (req, res) => {
  try {
    const { company_id, branch_id, title, message, data } = req.body;
    
    if (!company_id || !branch_id || !title || !message) {
      return res.status(400).json({ 
        success: false, 
        message: 'company_id, branch_id, title, and message are required' 
      });
    }

    // Get all branch admins
    const [admins] = await pool.execute(`
      SELECT user_id, name, fcm_token 
      FROM users 
      WHERE company_id = ? AND branch_id = ? AND fcm_token IS NOT NULL
    `, [company_id, branch_id]);

    let successCount = 0;
    let failureCount = 0;

    for (const admin of admins) {
      try {
        const fcmMessage = {
          token: admin.fcm_token,
          notification: {
            title,
            body: message
          },
          data: data || {},
          android: {
            priority: 'high',
            notification: {
              sound: 'default'
            }
          },
          apns: {
            payload: {
              aps: {
                sound: 'default'
              }
            }
          }
        };

        await admin.messaging().send(fcmMessage);
        successCount++;

        // Store notification in database
        await pool.execute(`
          INSERT INTO notifications (
            user_id, title, message, type, data, created_at
          ) VALUES (?, ?, ?, ?, ?, NOW())
        `, [
          admin.user_id,
          title,
          message,
          'custom',
          JSON.stringify(data || {})
        ]);

      } catch (fcmError) {
        console.error(`FCM failed for admin ${admin.user_id}:`, fcmError);
        failureCount++;
      }
    }

    res.json({ 
      success: true, 
      message: `Notifications sent to ${successCount} admins, ${failureCount} failed`,
      success_count: successCount,
      failure_count: failureCount
    });

  } catch (error) {
    console.error('Error sending branch notifications:', error);
    res.status(500).json({ success: false, message: 'Failed to send notifications' });
  }
});

module.exports = router;
