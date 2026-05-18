
## Base URL
```
https://node-api.bangkokmart.in/api/orders
```

## Order Status Flow
The order management system follows this status progression:
1. **Pending** → **Waiting for Payment** → **Ready for Shipment** → **Shipped** → **Delivered**
2. **Pending** → **Cancelled** (at any stage)

## API Endpoints

#### Get Order Status Counts
```http
GET /orders/status-counts
```

**Response:**
```json
{
  "success": true,
  "counts": {
    "Pending": 5,
    "Waiting for Payment": 3,
    "Ready for Shipment": 8,
    "Shipped": 12,
    "Delivered": 45,
    "Cancelled": 2
  }
}
```

#### Get Dashboard Statistics
```http
GET /orders/dashboard/stats
```

**Response:**
```json
{
  "success": true,
  "stats": {
    "todayOrders": 8,
    "yesterdayOrders": 12,
    "totalOrders": 156,
    "cancelledOrders": 5,
    "totalRevenue": 45678.90,
    "weekRevenue": 2345.67,
    "monthRevenue": 12345.67
  }
}
```

### 2. Order Retrieval

#### Get All Orders (Dashboard)
```http
GET /orders/dashboard/all
```

**Response:**
```json
{
  "success": true,
  "orders": [
    {
      "id": 123,
      "user_id": 456,
      "total_amount": 1299.00,
      "order_status": "Pending",
      "payment_status": "Pending",
      "order_date": "2024-01-15T10:30:00.000Z",
      "customer_name": "John Doe",
      "customer_phone": "+1234567890",
      "product_name": "Product Name",
      "image_url": "https://example.com/image.jpg",
      "item_count": 2
    }
  ]
}
```

#### Get Orders by Status
```http
GET /orders?status={status}
```

**Parameters:**
- `status`: Order status (Pending, Waiting for Payment, Ready for Shipment, Shipped, Delivered, Cancelled)

**Response:**
```json
{
  "success": true,
  "orders": [
    {
      "id": 123,
      "user_id": 456,
      "total_amount": 1299.00,
      "order_status": "Pending",
      "payment_status": "Pending",
      "order_date": "2024-01-15T10:30:00.000Z",
      "customer_name": "John Doe",
      "customer_phone": "+1234567890",
      "item_count": 2
    }
  ]
}
```

#### Get Order Count by Status
```http
GET /orders?status={status}&count=true


**Response:**json
{
  "success": true,
  "count": 5
}


#### Get Order Details by ID
http
GET /orders/{orderId}


**Response:**
```json
{
  "success": true,
  "order": {
    "id": 123,
    "user_id": 456,
    "total_amount": 1299.00,
    "shipping_street": "123 Main St",
    "shipping_city": "New York",
    "shipping_state": "NY",
    "shipping_pincode": "10001",
    "shipping_phone": "+1234567890",
    "payment_method": "UPI",
    "order_status": "Pending",
    "payment_status": "Pending",
    "order_date": "2024-01-15T10:30:00.000Z",
    "delivery_fee": 250.00,
    "customer_name": "John Doe",
    "customer_phone": "+1234567890"
  },
  "items": [
    {
      "id": 1,
      "order_id": 123,
      "product_id": 789,
      "quantity": 2,
      "price": 524.50,
      "size": "L",
      "color": "Blue",
      "product_name": "Product Name",
      "availability_status": 0,
      "available_quantity": 2,
      "stock_status": "full",
      "image_url": "https://example.com/image.jpg"
    }
  ]
}



#### Update Order Status
http
PUT /orders/{orderId}/status


**Request Body:**json
{
  "order_status": "Ready for Shipment",
  "payment_status": "paid"  // Optional
}


**Response:**
json
{
  "success": true,
  "message": "Order status updated to Ready for Shipment successfully"
}


#### Update Payment Status
http
PATCH /orders/{orderId}/payment-status


**Request Body:**
json
{
  "payment_status": "paid",
  "payment_method": "UPI"
}


**Response:**
json
{
  "success": true,
  "message": "Payment status updated automatically within 5 minutes",
  "automatic_update": true
}


#### Get Payment Status
http
GET /orders/{orderId}/payment-status


**Response:**
json
{
  "success": true,
  "payment_status": "paid",
  "order_status": "Ready for Shipment",
  "time_elapsed_minutes": 3,
  "is_within_5_minutes": true
}




#### Create New Order
http
POST /orders/create


**Request Body:**
```json
{
  "user_id": 456,
  "total_amount": 1299.00,
  "shipping_street": "123 Main St",
  "shipping_city": "New York",
  "shipping_state": "NY",
  "shipping_pincode": "10001",
  "shipping_phone": "+1234567890",
  "payment_method": "UPI",
  "items": [
    {
      "product_id": 789,
      "quantity": 2,
      "price": 524.50,
      "size": "L",
      "color": "Blue"
    }
  ]
}


**Response:**
```json
{
  "success": true,
  "message": "Order created successfully",
  "order_id": 123,
  "total_amount": 1299.00,
  "assigned_admin_id": 789
}




#### Get Admin Dashboard Data
http
GET /orders/admin/dashboard?userId={userId}


**Response:**
```json
{
  "success": true,
  "data": {
    "websites": [
      {
        "website_id": 1,
        "website_name": "My Store",
        "domain": "mystore.com"
      }
    ],
    "stats": {
      "todayOrders": 5,
      "yesterdayOrders": 8,
      "totalOrders": 125,
      "cancelledOrders": 3,
      "totalRevenue": 34567.89,
      "weekRevenue": 1234.56,
      "monthRevenue": 6789.01
    },
    "orders": [...],
    "products": [...]
  }
}


#### Get Website Orders
http
GET /orders/website/{websiteId}


**Response:**
json
{
  "success": true,
  "orders": [
    {
      "id": 123,
      "user_id": 456,
      "total_amount": 1299.00,
      "order_status": "Pending",
      "customer_name": "John Doe",
      "customer_phone": "+1234567890",
      "website_name": "My Store"
    }
  ]
}


#### Update Manual Stock Quantity
http
POST /orders/update-manual-stock


**Request Body:**
json
{
  "orderId": 123,
  "itemId": 1,
  "manualStockQuantity": 5,
  "useManualStock": true
  }


**Response:**
json
{
  "success": true,
  "message": "Manual stock updated successfully",
  "data": {
    "orderId": 123,
    "itemId": 1,
    "manualStockQuantity": 5,
    "useManualStock": true
  }
}


#### Update Item Availability Status
http
POST /orders/update-availability


**Request Body:**
json
{
  "orderId": 123,
  "itemId": 1,
  "availabilityStatus": 0  // 0 = Available, 1 = Not Available
}

**Response:**
json
{
  "success": true,
  "message": "Availability status updated successfully",
  "data": {
    "orderId": 123,
    "itemId": 1,
    "availabilityStatus": 0
  }
}




#### Manual Payment Confirmation
http
POST /orders/{orderId}/confirm-payment


**Request Body:**
json
{
  "payment_method": "Manual",
  "transaction_id": "TXN123456",
  "notes": "Payment confirmed via bank transfer"
}


**Response:**
json
{
  "success": true,
  "message": "Payment confirmed manually",
  "automatic_update": false,
  "time_elapsed_minutes": 15
}
```

#### Create Test Order
http
POST /orders/create-test


**Request Body:**
```json
{
  "user_id": 456,
  "total_amount": 1299.00,
  "shipping_street": "123 Main St",
  "shipping_city": "New York",
  "shipping_state": "NY",
  "shipping_pincode": "10001",
  "shipping_phone": "+1234567890",
  "payment_method": "UPI",
  "items": [
    {
      "product_id": 789,
      "quantity": 2,
      "price": 524.50,
      "size": "L",
      "color": "Blue"
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Test order created successfully",
  "orderId": 124
}


All APIs return consistent error responses:
json
{
  "success": false,
  "message": "Error description"
}

Common HTTP Status Codes:
- `200`: Success
- `400`: Bad Request (missing parameters)
- `403`: Forbidden (not authorized)
- `404`: Not Found (order doesn't exist)
- `500`: Internal Server Error

## Testin
Use the `/orders/create-test` endpoint to create test orders for development and testing purposes.

.
