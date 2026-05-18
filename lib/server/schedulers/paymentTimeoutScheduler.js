// Payment Timeout Scheduler - Simple version without node-cron
const axios = require('axios');

/**
 * Payment Timeout Scheduler
 * Runs every 5 minutes to check for orders that have been waiting for payment
 * for more than 30 minutes and automatically cancels them.
 */

class PaymentTimeoutScheduler {
  constructor(app) {
    // Use the existing Express app
    this.app = app;
    this.isRunning = false;
    this.schedulerInterval = null;
    // Get server URL from existing app configuration
    this.baseUrl = this.getServerUrl();
  }

  // Get server URL from existing Express app
  getServerUrl() {
    // Check if app is listening to get the actual URL
    const port = this.app.get('port') || process.env.PORT || 3000;
    const host = this.app.get('host') || 'localhost';
    
    // Use the same configuration as your main server
    if (process.env.NODE_ENV === 'production') {
      return 'https://node-api.bangkokmart.in';
    } else {
      // Use local development URL
      return `http://${host}:${port}`;
    }
  }

  // Start the scheduler
  start() {
    console.log(`[PaymentTimeoutScheduler] Starting payment timeout scheduler on ${this.baseUrl}...`);
    
    // Use simple setInterval instead of node-cron
    this.schedulerInterval = setInterval(async () => {
      if (this.isRunning) {
        console.log('[PaymentTimeoutScheduler] Previous check still running, skipping...');
        return;
      }
      await this.checkExpiredPayments();
    }, 5 * 60 * 1000); // 5 minutes in milliseconds

    // Run once immediately on start
    setTimeout(() => this.checkExpiredPayments(), 5000);

    console.log('[PaymentTimeoutScheduler] Scheduler started - will check every 5 minutes');
  }

  // Check for expired payments
  async checkExpiredPayments() {
    this.isRunning = true;
    
    try {
      console.log('[PaymentTimeoutScheduler] Checking for expired payment orders...');
      
      const response = await axios.post(`${this.baseUrl}/api/orders/check-expired-payments`, {}, {
        timeout: 30000 // 30 second timeout
      });

      if (response.data.success) {
        const { cancelled_orders } = response.data;
        
        if (cancelled_orders && cancelled_orders.length > 0) {
          console.log(`[PaymentTimeoutScheduler] Auto-cancelled ${cancelled_orders.length} orders:`);
          cancelled_orders.forEach(order => {
            console.log(`  - Order #${order.orderId} (${order.customerName}) - ${order.waitingMinutes} minutes waiting, ₹${order.totalAmount}`);
          });
        } else {
          console.log('[PaymentTimeoutScheduler] No expired payment orders found');
        }
      } else {
        console.error('[PaymentTimeoutScheduler] Failed to check expired payments:', response.data.message);
      }
      
    } catch (error) {
      console.error('[PaymentTimeoutScheduler] Error checking expired payments:', error.message);
      
      if (error.code === 'ECONNREFUSED') {
        console.error('[PaymentTimeoutScheduler] Cannot connect to server. Is the server running?');
      }
    } finally {
      this.isRunning = false;
    }
  }

  // Stop the scheduler
  stop() {
    console.log('[PaymentTimeoutScheduler] Stopping payment timeout scheduler...');
    if (this.schedulerInterval) {
      clearInterval(this.schedulerInterval);
      this.schedulerInterval = null;
    }
  }

  // Manual check for testing
  async manualCheck() {
    console.log('[PaymentTimeoutScheduler] Running manual check...');
    await this.checkExpiredPayments();
  }
}

// If run directly, start the scheduler
if (require.main === module) {
  console.log('[PaymentTimeoutScheduler] Cannot run directly - must be initialized with Express app');
  console.log('Please use: const scheduler = new PaymentTimeoutScheduler(app);');
  console.log('Then: scheduler.start();');
}

// Export for use in other files
module.exports = PaymentTimeoutScheduler;
