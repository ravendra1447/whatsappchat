-- Add payment_waiting_since field to orders table
ALTER TABLE orders ADD COLUMN payment_waiting_since TIMESTAMP NULL DEFAULT NULL;

-- Add fields to track who performed status changes
ALTER TABLE orders ADD COLUMN ready_for_shipment_by INT NULL DEFAULT NULL;
ALTER TABLE orders ADD COLUMN ready_for_shipment_at TIMESTAMP NULL DEFAULT NULL;
ALTER TABLE orders ADD COLUMN shipped_by INT NULL DEFAULT NULL;
ALTER TABLE orders ADD COLUMN shipped_at TIMESTAMP NULL DEFAULT NULL;
ALTER TABLE orders ADD COLUMN delivered_by INT NULL DEFAULT NULL;
ALTER TABLE orders ADD COLUMN delivered_at TIMESTAMP NULL DEFAULT NULL;

-- Create payment_logs table for tracking payment actions
CREATE TABLE IF NOT EXISTS payment_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  customer_name VARCHAR(255) NOT NULL,
  action_type ENUM('PAYMENT_APPROVED', 'PAYMENT_FAILED', 'ORDER_CANCELLED', 'WAITING_FOR_PAYMENT', 'READY_FOR_SHIPMENT', 'ORDER_SHIPPED', 'ORDER_DELIVERED', 'STATUS_UPDATE') NOT NULL,
  action_by VARCHAR(255) NOT NULL DEFAULT 'System',
  order_status VARCHAR(50) NOT NULL,
  payment_status VARCHAR(50) NOT NULL,
  action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  details JSON NULL,
  INDEX idx_order_id (order_id),
  INDEX idx_action_timestamp (action_timestamp),
  INDEX idx_action_type (action_type)
);

-- Add index for better performance on payment_waiting_since queries
ALTER TABLE orders ADD INDEX idx_payment_waiting_since (payment_waiting_since);

-- Insert sample data for testing (optional)
-- INSERT INTO payment_logs (order_id, customer_name, action_type, action_by, order_status, payment_status, details) 
-- VALUES (1, 'Test Customer', 'WAITING_FOR_PAYMENT', 'Admin', 'Waiting for Payment', 'pending', '{"test": true}');
