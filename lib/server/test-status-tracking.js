#!/usr/bin/env node

/**
 * Test script for Order Status Tracking with User Names
 * This script demonstrates how the status tracking works with user names
 */

const mysql = require('mysql2/promise');

// Database configuration
const dbConfig = {
  host: "localhost",
  user: "chatuser",
  password: "chat1234#db",
  database: "chat_db"
};

async function testStatusTracking() {
  console.log('🧪 Testing Order Status Tracking with User Names');
  console.log('===============================================');
  
  try {
    const connection = await mysql.createConnection(dbConfig);
    
    // Test 1: Check if new columns exist
    console.log('\n📋 Checking database structure...');
    
    const [columns] = await connection.execute(`
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = 'chat_db' 
      AND TABLE_NAME = 'orders' 
      AND COLUMN_NAME IN ('ready_for_shipment_by', 'ready_for_shipment_at', 'shipped_by', 'shipped_at', 'delivered_by', 'delivered_at', 'payment_waiting_since')
    `);
    
    console.log('✅ Found columns:', columns.map(c => c.COLUMN_NAME).join(', '));
    
    // Test 2: Check if payment_logs table exists with correct structure
    console.log('\n📋 Checking payment_logs table structure...');
    
    const [logColumns] = await connection.execute(`
      SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = 'chat_db' 
      AND TABLE_NAME = 'payment_logs'
      ORDER BY ORDINAL_POSITION
    `);
    
    console.log('✅ payment_logs table columns:');
    logColumns.forEach(col => {
      console.log(`  - ${col.COLUMN_NAME}: ${col.COLUMN_TYPE}`);
    });
    
    // Test 3: Create a sample order status update test
    console.log('\n🔄 Testing status update logic...');
    
    // Find a sample order to test with
    const [sampleOrders] = await connection.execute(
      'SELECT id, order_status FROM orders LIMIT 1'
    );
    
    if (sampleOrders.length > 0) {
      const orderId = sampleOrders[0].id;
      const currentStatus = sampleOrders[0].order_status;
      
      console.log(`📦 Testing with order #${orderId} (current status: ${currentStatus})`);
      
      // Simulate updating to Ready for Shipment
      const testUserId = 1; // Assuming user ID 1 exists
      await connection.execute(
        `UPDATE orders SET 
         order_status = ?, 
         ready_for_shipment_by = ?, 
         ready_for_shipment_at = NOW() 
         WHERE id = ?`,
        ['Ready for Shipment', testUserId, orderId]
      );
      
      // Verify the update
      const [updatedOrder] = await connection.execute(`
        SELECT 
          o.*,
          u.name as ready_for_shipment_by_name
        FROM orders o
        LEFT JOIN users u ON o.ready_for_shipment_by = u.user_id
        WHERE o.id = ?
      `, [orderId]);
      
      if (updatedOrder.length > 0) {
        console.log('✅ Status update successful:');
        console.log(`  - Order Status: ${updatedOrder[0].order_status}`);
        console.log(`  - Ready for Shipment By: ${updatedOrder[0].ready_for_shipment_by_name || 'Unknown'}`);
        console.log(`  - Ready for Shipment At: ${updatedOrder[0].ready_for_shipment_at}`);
      }
      
      // Restore original status
      await connection.execute(
        'UPDATE orders SET order_status = ? WHERE id = ?',
        [currentStatus, orderId]
      );
      
    } else {
      console.log('ℹ️  No orders found to test with');
    }
    
    // Test 4: Check payment logs structure
    console.log('\n📊 Checking payment_logs data...');
    
    const [logEntries] = await connection.execute(
      'SELECT * FROM payment_logs ORDER BY action_timestamp DESC LIMIT 5'
    );
    
    if (logEntries.length > 0) {
      console.log('✅ Recent payment log entries:');
      logEntries.forEach(log => {
        console.log(`  - ${log.action_timestamp}: ${log.action_type} by ${log.action_by} for order #${log.order_id}`);
      });
    } else {
      console.log('ℹ️  No payment log entries found');
    }
    
    await connection.end();
    
    console.log('\n✅ Status tracking test completed successfully!');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    process.exit(1);
  }
}

function showUsageInstructions() {
  console.log('\n📖 Usage Instructions:');
  console.log('=====================');
  console.log('');
  console.log('1. Run the database migration first:');
  console.log('   node setup-payment-timeout.js');
  console.log('');
  console.log('2. Test the status tracking:');
  console.log('   node test-status-tracking.js');
  console.log('');
  console.log('3. Update order status via API:');
  console.log('   PUT /api/orders/:orderId/status');
  console.log('   Body: { "order_status": "Ready for Shipment" }');
  console.log('');
  console.log('4. View order details with user names:');
  console.log('   GET /api/orders/:orderId');
  console.log('');
  console.log('5. View payment logs:');
  console.log('   GET /api/orders/payment-logs');
  console.log('');
  console.log('🔍 What you will see:');
  console.log('- ready_for_shipment_by_name: Name of user who marked as Ready for Shipment');
  console.log('- shipped_by_name: Name of user who marked as Shipped');
  console.log('- delivered_by_name: Name of user who marked as Delivered');
  console.log('- ready_for_shipment_at: Timestamp when marked as Ready for Shipment');
  console.log('- shipped_at: Timestamp when marked as Shipped');
  console.log('- delivered_at: Timestamp when marked as Delivered');
  console.log('');
}

// Run the test
if (require.main === module) {
  testStatusTracking()
    .then(() => showUsageInstructions())
    .catch(console.error);
}

module.exports = { testStatusTracking };
