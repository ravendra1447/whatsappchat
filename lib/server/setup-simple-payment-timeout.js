#!/usr/bin/env node

/**
 * Simple Payment Timeout Setup
 * Only essential columns and tables
 */

const mysql = require('mysql2/promise');

const dbConfig = {
  host: "localhost",
  user: "chatuser",
  password: "chat1234#db",
  database: "chat_db"
};

async function runSimpleSetup() {
  console.log('🚀 Simple Payment Timeout Setup');
  console.log('================================');
  
  try {
    const connection = await mysql.createConnection(dbConfig);
    
    console.log('📋 Adding essential columns to orders table...');
    
    // Add only essential columns
    const columns = [
      'ALTER TABLE orders ADD COLUMN payment_waiting_since TIMESTAMP NULL DEFAULT NULL',
      'ALTER TABLE orders ADD COLUMN ready_for_shipment_by INT NULL DEFAULT NULL',
      'ALTER TABLE orders ADD COLUMN shipped_by INT NULL DEFAULT NULL', 
      'ALTER TABLE orders ADD COLUMN delivered_by INT NULL DEFAULT NULL',
      'ALTER TABLE orders ADD INDEX idx_payment_waiting_since (payment_waiting_since)'
    ];
    
    for (const column of columns) {
      try {
        await connection.execute(column);
        console.log('✅ Added:', column.split('ADD COLUMN')[1]?.trim() || column);
      } catch (error) {
        if (error.code === 'ER_DUP_FIELDNAME') {
          console.log('ℹ️  Already exists:', column.split('ADD COLUMN')[1]?.trim() || column);
        } else {
          console.error('❌ Error:', error.message);
        }
      }
    }
    
    console.log('\n📊 Creating payment_logs table...');
    
    // Create simple payment_logs table
    const createTable = `
      CREATE TABLE IF NOT EXISTS payment_logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        order_id INT NOT NULL,
        customer_name VARCHAR(255) NOT NULL,
        action_type ENUM('PAYMENT_APPROVED', 'PAYMENT_FAILED', 'ORDER_CANCELLED', 'WAITING_FOR_PAYMENT', 'READY_FOR_SHIPMENT', 'ORDER_SHIPPED', 'ORDER_DELIVERED') NOT NULL,
        action_by VARCHAR(255) NOT NULL DEFAULT 'System',
        order_status VARCHAR(50) NOT NULL,
        payment_status VARCHAR(50) NOT NULL,
        action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_order_id (order_id),
        INDEX idx_action_timestamp (action_timestamp)
      )
    `;
    
    await connection.execute(createTable);
    console.log('✅ payment_logs table created');
    
    await connection.end();
    
    console.log('\n✅ Simple setup completed!');
    console.log('\n🎯 What was added:');
    console.log('- payment_waiting_since: Tracks when payment waiting started');
    console.log('- ready_for_shipment_by: Who marked as Ready for Shipment');
    console.log('- shipped_by: Who marked as Shipped');
    console.log('- delivered_by: Who marked as Delivered');
    console.log('- payment_logs: Audit trail for all actions');
    console.log('\n🔗 API Usage:');
    console.log('PUT /api/orders/:orderId/status - Update status (tracks user)');
    console.log('GET /api/orders/payment-logs - View logs');
    console.log('POST /api/orders/check-expired-payments - Check timeouts');
    
    console.log('\n📋 Integration Instructions:');
    console.log('✅ Scheduler already integrated in server.js!');
    console.log('');
    console.log('What was added to server.js:');
    console.log('```javascript');
    console.log('const PaymentTimeoutScheduler = require("./schedulers/paymentTimeoutScheduler");');
    console.log('const paymentScheduler = new PaymentTimeoutScheduler(app);');
    console.log('```');
    console.log('');
    console.log('🎯 Features:');
    console.log('✅ Auto-detects server URL from existing app');
    console.log('✅ No environment variables needed');
    console.log('✅ Starts automatically with server');
    console.log('✅ Uses same configuration as your main server');
    console.log('✅ No external dependencies needed (uses built-in setInterval)');
    console.log('');
    console.log('🔗 Available APIs:');
    console.log('PUT /api/orders/:orderId/status - Update status (tracks user)');
    console.log('GET /api/orders/payment-logs - View logs');
    console.log('POST /api/orders/check-expired-payments - Manual timeout check');
    console.log('');
    console.log('📦 Dependencies:');
    console.log('- axios (usually already installed)');
    console.log('- No node-cron required (uses setInterval)');
    console.log('');
    
  } catch (error) {
    console.error('❌ Setup failed:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  runSimpleSetup();
}

module.exports = { runSimpleSetup };
