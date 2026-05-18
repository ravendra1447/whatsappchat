-- Add only essential columns for payment timeout functionality
ALTER TABLE orders ADD COLUMN payment_waiting_since TIMESTAMP NULL DEFAULT NULL;

-- Add only essential tracking columns for status changes
ALTER TABLE orders ADD COLUMN ready_for_shipment_by INT NULL DEFAULT NULL;
ALTER TABLE orders ADD COLUMN shipped_by INT NULL DEFAULT NULL;
ALTER TABLE orders ADD COLUMN delivered_by INT NULL DEFAULT NULL;

-- Create simple payment_logs table
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
);

-- Add index for performance
ALTER TABLE orders ADD INDEX idx_payment_waiting_since (payment_waiting_since);
