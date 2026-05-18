#!/usr/bin/env node

/**
 * Setup script for Payment Timeout functionality
 * This script will:
 * 1. Run the database migration
 * 2. Show how to integrate the scheduler
 * 3. Test the functionality
 */

const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

// Database configuration
const dbConfig = {
  host: "localhost",
  user: "chatuser",
  password: "chat1234#db",
  database: "chat_db"
};

async function runMigration() {
  console.log('🔧 Running database migration...');
  
  try {
    const connection = await mysql.createConnection(dbConfig);
    
    // Read and execute migration file
    const migrationPath = path.join(__dirname, 'migrations/add_payment_timeout_functionality.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');
    
    // Split by semicolon and execute each statement
    const statements = migrationSQL
      .split(';')
      .map(stmt => stmt.trim())
      .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));
    
    for (const statement of statements) {
      try {
        await connection.execute(statement);
        console.log('✅ Executed:', statement.substring(0, 50) + '...');
      } catch (error) {
        if (error.code !== 'ER_DUP_FIELDNAME' && error.code !== 'ER_TABLE_EXISTS_ERROR') {
          console.error('❌ Error in statement:', statement);
          throw error;
        } else {
          console.log('ℹ️  Already exists:', statement.substring(0, 50) + '...');
        }
      }
    }
    
    await connection.end();
    console.log('✅ Database migration completed successfully!');
    
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    process.exit(1);
  }
}

function showIntegrationInstructions() {
  console.log('\n📋 Integration Instructions:');
  console.log('1. Add the scheduler to your main server file (server.js or app.js):');
  console.log('');
  console.log('```javascript');
  console.log('const PaymentTimeoutScheduler = require("./schedulers/paymentTimeoutScheduler");');
  console.log('');
  console.log('// Start the payment timeout scheduler');
  console.log('const paymentScheduler = new PaymentTimeoutScheduler("http://localhost:3000");');
  console.log('paymentScheduler.start();');
  console.log('```');
  console.log('');
  console.log('2. Install required dependencies:');
  console.log('```bash');
  console.log('npm install node-cron axios');
  console.log('```');
  console.log('');
  console.log('3. The scheduler will:');
  console.log('   - Check every 5 minutes for expired payment orders');
  console.log('   - Automatically cancel orders after 30 minutes of waiting');
  console.log('   - Send notifications to customers');
  console.log('   - Log all actions for audit trail');
  console.log('');
}

function showAPIEndpoints() {
  console.log('🔗 Available API Endpoints:');
  console.log('');
  console.log('POST /api/orders/check-expired-payments');
  console.log('  - Manually check and cancel expired payment orders');
  console.log('  - Can be called by scheduler or manually');
  console.log('');
  console.log('GET /api/orders/payment-logs');
  console.log('  - Get payment action logs for admin dashboard');
  console.log('  - Query params: limit, offset, order_id');
  console.log('');
  console.log('PUT /api/orders/:orderId/status');
  console.log('  - Update order status (now includes logging)');
  console.log('  - Automatically tracks payment waiting time');
  console.log('');
}

async function testDatabaseConnection() {
  console.log('🔍 Testing database connection...');
  
  try {
    const connection = await mysql.createConnection(dbConfig);
    await connection.execute('SELECT 1');
    await connection.end();
    console.log('✅ Database connection successful!');
    return true;
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    return false;
  }
}

async function main() {
  console.log('🚀 Payment Timeout Setup Script');
  console.log('================================');
  
  // Test database connection
  const dbConnected = await testDatabaseConnection();
  if (!dbConnected) {
    process.exit(1);
  }
  
  // Run migration
  await runMigration();
  
  // Show instructions
  showIntegrationInstructions();
  showAPIEndpoints();
  
  console.log('\n✅ Setup completed!');
  console.log('\n🎯 Next steps:');
  console.log('1. Install dependencies: npm install node-cron axios');
  console.log('2. Add scheduler to your main server file');
  console.log('3. Restart your server');
  console.log('4. Test by creating an order and setting status to "Waiting for Payment"');
  console.log('5. Check logs after 30+ minutes or call the manual endpoint');
  console.log('');
  console.log('📞 For testing, you can manually trigger the check:');
  console.log('curl -X POST http://localhost:3000/api/orders/check-expired-payments');
}

// Run the setup
if (require.main === module) {
  main().catch(console.error);
}

module.exports = { runMigration, testDatabaseConnection };
