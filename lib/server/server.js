// server.js
require('dotenv').config();
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const axios = require('axios');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');

const { setupMarketplaceSocket } = require("./routes/marketplace/chatHelpers");

const app = express();
app.use(express.json());
const router = express.Router();


// ----------------- DB CONNECTION -----------------
const mysql = require("mysql2/promise");

const pool = mysql.createPool({
  host: "localhost",
  user: "chatuser",
  password: "chat1234#db",
  database: "chat_db"
});


// Set pool in app for routes to access
app.set('pool', pool);
// ✅ Body parsers

app.use(express.urlencoded({ extended: true }));

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const uploadMediaRouter = require('./media/uploadMedia.js');

const productRoutes = require('./routes/productRoutes');
app.use("/api/products", productRoutes);

const adminProductRoutes = require('./routes/adminProductRoutes');
app.use("/api", adminProductRoutes);

app.use("/api", uploadMediaRouter);

const { router: backupRoutes, sendFcmNotification } = require("./routes/backup");
app.use("/api", backupRoutes);

// Order routes
const orderRoutes = require("./routes/order/orderRoutes");
app.use("/api/orders", orderRoutes);

// Order delivery fee update routes
const updateDeliveryFeeRoutes = require("./routes/order/updateDeliveryFee");
app.use("/api/orders", updateDeliveryFeeRoutes);
console.log('✅ Delivery fee update routes loaded successfully');

// Test route immediately
app.get('/api/test-routes', (req, res) => {
  res.json({
    message: 'Server is running and routes are loaded',
    timestamp: new Date().toISOString(),
    routes: {
      deliveryFee: '/api/orders/update-delivery-fee/:orderId',
      testDeliveryFee: '/api/orders/test-delivery-fee'
    }
  });
});

// Seller order routes
const sellerOrderRoutes = require("./routes/order/sellerOrderRoutes");
app.use("/api/seller-orders", sellerOrderRoutes);

// Address routes
const addressRoutes = require("./routes/address/addressRoutes");
app.use("/api/addresses", addressRoutes);

// Website routes
const websiteRoutes = require("./routes/linkwebsite/websiteRoutes");
app.use("/api/websites", websiteRoutes);

// Website verification routes
const websiteVerificationRoutes = require("./routes/website/websiteVerificationRoutes");
app.use("/api", websiteVerificationRoutes);

// Company management routes
const companyRoutes = require("./routes/company/companyRoutes");
app.use("/api/companies", companyRoutes);

// User company/branch assignment routes
const userCompanyBranchRoutes = require("./routes/user/userCompanyBranchRoutes");
app.use("/api/users", userCompanyBranchRoutes);

// Flutter user routes for company registration
const flutterUserRoutes = require("./routes/user/flutterUserRoutes");
app.use("/api/flutter/users", flutterUserRoutes);

// Branch notification routes
const branchNotificationRoutes = require("./routes/notification/branchNotificationRoutes");
app.use("/api/notifications", branchNotificationRoutes);

// Branch filter routes
const branchFilterRoutes = require("./routes/filter/branchFilterRoutes");
app.use("/api/filter", branchFilterRoutes);

// Product image routes
const productImageRoutes = require("./routes/product/productImageRoutes");
app.use("/api/product", productImageRoutes);

// Profile image routes
const profileImageRoutes = require("./routes/profile/profileImageRoutes");
app.use("/api/profile", profileImageRoutes);

// Profile product routes
const profileProductRoutes = require("./routes/profile/profileProductRoutes");
app.use("/api/profile", profileProductRoutes);

// Test endpoint to verify server restart
app.get("/api/profile/test", (req, res) => {
  res.json({
    success: true,
    message: 'Server is working and profile routes are loaded!',
    timestamp: new Date().toISOString()
  });
});

// Product domain visibility routes
const productDomainVisibilityRoutes = require("./routes/productDomainVisibility/index");
app.use("/api/product-domain-visibility", productDomainVisibilityRoutes);

// Notification routes
const notificationRoutes = require("./routes/notification/notificationRoutes");
app.use("/api/notifications", notificationRoutes);

// Cart routes
const cartRoutes = require("./routes/cart/cartRoutes");
app.use("/api/cart", cartRoutes);

// WhatsApp routes
const whatsappRoutes = require("./routes/whatsapp/whatsappRoutes");
app.use("/api/whatsapp", whatsappRoutes);

// WhatsApp Direct routes (QR Code Sharing)
const whatsappDirectRoutes = require("./routes/whatsapp/whatsappDirectRoutes");
app.use("/api/whatsapp", whatsappDirectRoutes); 

const whatsappPaymentRoutes = require("./routes/whatsapp/whatsappDirectRoutes");
app.use("/api/whatsapp-payment", whatsappPaymentRoutes);

// Role routes
const roleRoutes = require("./routes/role/roleRoutes");
app.use("/api/roles", roleRoutes);

// Banner routes
const bannerRoutes = require("./routes/banner/bannerRoutes");
app.use("/banners", bannerRoutes);
console.log('✅ Banner routes loaded successfully');

// Marketplace chat routes
const chatMarketplaceRoutes = require("./routes/marketplace/chatRoutes");
app.use("/api", chatMarketplaceRoutes);

// Shipping routes
const shippingRoutes = require("./routes/shipping/shippingRoutes");
app.use("/api/shipping", shippingRoutes);

// Advanced shipping routes with product/user linkage
const advancedShippingRoutes = require("./routes/shipping/advancedShippingRoutes");
app.use("/api/shipping", advancedShippingRoutes);

// Marketplace product routes (filters inactive variants)
const marketplaceProductRoutes = require("./routes/marketplace/marketplaceProductRoutes");
app.use("/api", marketplaceProductRoutes);

// Website product routes (filters inactive variants)
const websiteProductRoutes = require("./routes/website/websiteProductRoutes");
app.use("/api", websiteProductRoutes);

const MarketplaceNotificationService = require("./routes/marketplace/notifications/marketplaceNotificationService");
//app.use("/api/marketplace", marketplaceNotificationRoutes);

const PORT = process.env.PORT || 3000;
const UPLOAD_BASE_URL = process.env.UPLOAD_BASE_URL || `http://127.0.0.1:${PORT}/uploads`;

const PHP_API_BASE = process.env.PHP_API_BASE || "http://184.168.126.71/api";
const UPLOAD_DIR = path.join(__dirname, 'uploads');

// Create upload directory if it doesn't exist
console.log(`📂 Checking for upload directory at: ${UPLOAD_DIR}`);
if (!fs.existsSync(UPLOAD_DIR)) {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
    console.log(`✅ Upload directory created.`);
}

app.use('/uploads', express.static(UPLOAD_DIR));
app.use('/api/uploads', express.static(path.join(__dirname, 'uploads')));


const server = http.createServer(app);
// server.js

// const io = new Server(server, { ... }); // आपकी पुरानी लाइन

const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    },
    // ✅ इन सेटिंग्स को जोड़ें
    pingInterval: 25000, // सर्वर हर 10 सेकंड में पिंग भेजेगा
    pingTimeout: 60000,   // अगर 5 सेकंड में जवाब नहीं मिला तो डिस्कनेक्ट
    allowEIO3: true
});

const uploads = new Map();
const memStorage = multer.memoryStorage();
const uploadChunk = multer({
    storage: memStorage,
    limits: {
        fileSize: 5 * 1024 * 1024
    }
});

const connectedUsers = new Map();
const socketToUserMap = new Map();
const HEARTBEAT_INTERVAL = 60000;

// ---------------- Helper Functions ----------------
async function axiosRetry(url, payload, attempts = 3) {
    console.log(`🔄 Attempting POST to ${url} with payload:`, JSON.stringify(payload));
    for (let i = 0; i < attempts; i++) {
        try {
            await axios.post(url, payload, {
                headers: {
                    "Content-Type": "application/json"
                }
            });
            console.log(`✅ Request to ${url} succeeded on attempt ${i + 1}.`);
            return true;
        } catch (e) {
            console.error(`❌ Attempt ${i + 1} failed for ${url}:`, e.message);
            await new Promise(r => setTimeout(r, 150));
        }
    }
    console.error(`❌ All ${attempts} attempts to ${url} failed.`);
    return false;
}

async function getUserDetails(userId) {
    console.log(`🔍 Fetching user details for userId: ${userId}`);
    try {
        const res = await axios.get(`${PHP_API_BASE}/get_user_by_id.php`, {
            params: {
                user_id: userId
            }
        });
        if (res.data && res.data.success) {
            console.log(`✅ User details found for userId: ${userId}`);
            return res.data.user;
        }
        console.warn(`⚠️ User details not found or failed for userId: ${userId}`);
        return null;
    } catch (e) {
        console.error("❌ getUserDetails error:", e.message);
        return null;
    }
}

async function markDeliveredBulk(messageIds = []) {
    if (!messageIds.length) {
        console.log("ℹ️ No message IDs to mark as delivered.");
        return;
    }
    console.log(`📝 Marking messages as delivered:`, messageIds);
    await axiosRetry(`${PHP_API_BASE}/mark_delivered_bulk.php`, {
        message_ids: [...new Set(messageIds)]
    });
}

async function markReadBulk(messageIds = []) {
    if (!messageIds.length) {
        console.log("ℹ️ No message IDs to mark as read.");
        return;
    }
    console.log(`📝 Marking messages as read:`, messageIds);
    await axiosRetry(`${PHP_API_BASE}/mark_read.php`, {
        message_ids: [...new Set(messageIds)]
    });
}

async function fetchPendingForReceiver(receiverId) {
    console.log(`📨 Fetching pending messages for receiverId: ${receiverId}`);
    try {
        const r = await axios.get(`${PHP_API_BASE}/get_pending_messages.php`, {
            params: {
                receiver_id: receiverId
            }
        });
        if (r.data && r.data.success && Array.isArray(r.data.messages)) {
            console.log(`✅ Found ${r.data.messages.length} pending messages.`);
            return r.data.messages;
        }
    } catch (e) {
        console.error("❌ fetchPendingForReceiver error:", e.message);
    }
    console.log("ℹ️ No pending messages found.");
    return [];
}

// ---------------- Media Endpoints ----------------
app.post('/media/init', async (req, res) => {
    console.log("🔗 POST /media/init request received.");
    try {
        const {
            chat_id,
            sender_id,
            original_name,
            total_size
        } = req.body;
        if (!chat_id || !sender_id || !original_name) {
            console.error("❌ /media/init: Missing required fields.");
            return res.status(400).json({
                success: false,
                message: 'missing fields'
            });
        }
        const upload_id = uuidv4();
        const tempPath = path.join(UPLOAD_DIR, `${upload_id}.part`);
        uploads.set(upload_id, {
            tempPath,
            chat_id,
            sender_id,
            original_name,
            total_size: Number(total_size || 0),
            received: 0,
            chunks: 0,
            createdAt: Date.now()
        });
        await fsp.writeFile(tempPath, Buffer.alloc(0));
        console.log(`✅ Initialized new upload with upload_id: ${upload_id}`);
        res.json({
            success: true,
            upload_id
        });
    } catch (e) {
        console.error("❌ /media/init error:", e.message);
        res.status(500).json({
            success: false,
            message: e.message
        });
    }
});

app.post('/media/chunk', uploadChunk.single('chunk'), async (req, res) => {
    console.log("🔗 POST /media/chunk request received.");
    try {
        const {
            upload_id
        } = req.body;
        const sess = uploads.get(upload_id);
        if (!sess) {
            console.error(`❌ /media/chunk: Invalid upload_id: ${upload_id}`);
            return res.status(400).json({
                success: false,
                message: 'invalid upload_id'
            });
        }
        if (!req.file?.buffer) {
            console.error("❌ /media/chunk: Missing chunk data.");
            return res.status(400).json({
                success: false,
                message: 'missing chunk'
            });
        }
        await fsp.appendFile(sess.tempPath, req.file.buffer);
        sess.received += req.file.buffer.length;
        sess.chunks += 1;
        console.log(`📦 Chunk for ${upload_id} received. Total received: ${sess.received} bytes`);
        res.json({
            success: true,
            received: sess.received
        });
    } catch (e) {
        console.error("❌ /media/chunk error:", e.message);
        res.status(500).json({
            success: false,
            message: e.message
        });
    }
});

app.post('/media/chunks_batch', uploadChunk.array('chunks'), async (req, res) => {
    console.log("🔗 POST /media/chunks_batch request received.");
    try {
        const {
            upload_id
        } = req.body;
        const sess = uploads.get(upload_id);
        if (!sess) {
            console.error(`❌ /media/chunks_batch: Invalid upload_id: ${upload_id}`);
            return res.status(400).json({
                success: false,
                message: 'invalid upload_id'
            });
        }
        if (!req.files || !req.files.length) {
            console.error("❌ /media/chunks_batch: No chunks received.");
            return res.status(400).json({
                success: false,
                message: 'no chunks'
            });
        }
        console.log(`📦 Receiving batch of ${req.files.length} chunks for ${upload_id}.`);
        for (const f of req.files) {
            await fsp.appendFile(sess.tempPath, f.buffer);
            sess.received += f.buffer.length;
            sess.chunks += 1;
        }
        console.log(`✅ Batch for ${upload_id} processed. Total received: ${sess.received} bytes`);
        res.json({
            success: true,
            received: sess.received,
            chunks: sess.chunks
        });
    } catch (e) {
        console.error("❌ /media/chunks_batch error:", e.message);
        res.status(500).json({
            success: false,
            message: e.message
        });
    }
});

app.post('/media/chunk_offset', uploadChunk.single('chunk'), async (req, res) => {
    console.log("🔗 POST /media/chunk_offset request received.");
    try {
        const {
            upload_id,
            start
        } = req.body;
        const sess = uploads.get(upload_id);
        if (!sess) {
            console.error(`❌ /media/chunk_offset: Invalid upload_id: ${upload_id}`);
            return res.status(400).json({
                success: false,
                message: 'invalid upload_id'
            });
        }
        if (!req.file?.buffer) {
            console.error("❌ /media/chunk_offset: Missing chunk data.");
            return res.status(400).json({
                success: false,
                message: 'missing chunk'
            });
        }
        const startPos = Number(start || 0);
        console.log(`📦 Receiving chunk for ${upload_id} at offset: ${startPos}`);
        const fd = await fsp.open(sess.tempPath, 'r+');
        await fd.write(req.file.buffer, 0, req.file.buffer.length, startPos);
        await fd.close();
        sess.received += req.file.buffer.length;
        sess.chunks += 1;
        console.log(`✅ Chunk at offset ${startPos} processed. Total received: ${sess.received} bytes`);
        res.json({
            success: true,
            received: sess.received
        });
    } catch (e) {
        console.error("❌ /media/chunk_offset error:", e.message);
        res.status(500).json({
            success: false,
            message: e.message
        });
    }
});

app.post('/media/finalize', async (req, res) => {
    console.log("🔗 POST /media/finalize request received.");
    try {
        const {
            upload_id
        } = req.body;
        const sess = uploads.get(upload_id);
        if (!sess) {
            console.error(`❌ /media/finalize: Invalid upload_id: ${upload_id}`);
            return res.status(400).json({
                success: false,
                message: 'invalid upload_id'
            });
        }

        const finalName = `${Date.now()}_${sess.original_name}.enc`;
        const finalPath = path.join(UPLOAD_DIR, finalName);
        console.log(`✅ Finalizing upload ${upload_id}. Renaming to: ${finalName}`);
        await fsp.rename(sess.tempPath, finalPath);
        //const mediaUrl = `/uploads/${finalName}`;
const mediaUrl = `${UPLOAD_BASE_URL}/${finalName}`;

        const payload = {
            chat_id: sess.chat_id,
            sender_id: sess.sender_id,
            message_type: 'media',
            media_url: mediaUrl
        };
        console.log("📝 Sending media message to PHP API.");
        const resp = await axios.post(`${PHP_API_BASE}/send_message.php`, payload);
        if (!resp.data || !resp.data.success) {
            console.error("❌ PHP API failed to save message:", resp.data?.error);
            throw new Error(resp.data?.error || "PHP save failed");
        }
        console.log("✅ PHP API confirmed message saved. Fetching user details.");
        const messageData = resp.data.data;
        const [sender, receiver] = await Promise.all([
            getUserDetails(messageData.sender_id),
            getUserDetails(messageData.receiver_id)
        ]);
        const broadcastPayload = {
            message_id: messageData.message_id,
            chat_id: messageData.chat_id,
            sender_id: messageData.sender_id,
            receiver_id: messageData.receiver_id,
            message_type: 'media',
            message_text: messageData.message_text || null,
            media_url: mediaUrl,
            is_read: false,
            is_delivered: 0,
            timestamp: messageData.timestamp || new Date().toISOString(),
            sender_phone: sender?.normalized_phone || null,
            receiver_phone: receiver?.normalized_phone || null,
            // ✅ CRITICAL FIX: Include group_id, image_index, total_images from messageData (PHP API response)
            group_id: messageData.group_id || null,
            image_index: messageData.image_index !== undefined ? messageData.image_index : null,
            total_images: messageData.total_images !== undefined ? messageData.total_images : null
        };

        uploads.delete(upload_id);
        console.log(`🚀 Broadcasting new media message to chat ID: ${sess.chat_id}`);
        io.to(String(sess.chat_id)).emit("new_message", broadcastPayload);

        if (broadcastPayload.receiver_id) {
            console.log(`🚀 Sending specific receive_message to user ID: ${broadcastPayload.receiver_id}`);
            io.to(`user:${broadcastPayload.receiver_id}`).emit("receive_message", broadcastPayload);
            if (connectedUsers.has(String(broadcastPayload.receiver_id))) {
                console.log(`✅ Receiver is online. Marking message as delivered.`);
                await markDeliveredBulk([broadcastPayload.message_id]);
                broadcastPayload.is_delivered = 1;
            } else {
                console.log(`ℹ️ Receiver is offline. Message will be delivered upon reconnection.`);
            }
        }
        res.json({
            success: true,
            data: broadcastPayload
        });
    } catch (e) {
        console.error("❌ /media/finalize error:", e.message);
        res.status(500).json({
            success: false,
            message: e.message
        });
    }
});

app.get('/media/file/:filename', (req, res) => {
    console.log(`🔗 GET /media/file/${req.params.filename} request received.`);
    try {
        const filePath = path.join(UPLOAD_DIR, req.params.filename);
        if (!fs.existsSync(filePath)) {
            console.error(`❌ File not found: ${filePath}`);
            return res.status(404).send('Not found');
        }
        const stat = fs.statSync(filePath);
        const fileSize = stat.size;
        const range = req.headers.range;
        if (range) {
            console.log(`ℹ️ Range request detected: ${range}`);
            const parts = range.replace(/bytes=/, "").split("-");
            const start = parseInt(parts[0], 10);
            const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
            const chunkSize = (end - start) + 1;
            const file = fs.createReadStream(filePath, {
                start,
                end
            });
            res.writeHead(206, {
                'Content-Range': `bytes ${start}-${end}/${fileSize}`,
                'Accept-Ranges': 'bytes',
                'Content-Length': chunkSize,
                'Content-Type': 'application/octet-stream'
            });
            file.pipe(res);
            console.log(`✅ Serving part of file from byte ${start} to ${end}.`);
        } else {
            res.sendFile(filePath);
            console.log("✅ Serving full file.");
        }
    } catch (e) {
        console.error("❌ /media/file error:", e.message);
        res.status(500).send("Server error");
    }
});

// ---------------- Socket.IO ----------------
// Heartbeat mechanism to detect inactive clients
setInterval(() => {
    console.log("❤️ Sending 'ping' to all connected clients.");
    io.sockets.sockets.forEach(socket => {
        const uid = socketToUserMap.get(socket.id);
        if (!uid) return;
        const userRecord = connectedUsers.get(uid);
        if (!userRecord) return;

        if (!userRecord.alive) {
            userRecord.missed = (userRecord.missed || 0) + 1;
            if (userRecord.missed >= 2) {
                console.log(`💔 User ${uid} missed 2 pings. Disconnecting socket: ${socket.id}`);
                socket.disconnect(true);
                userRecord.socketIds.delete(socket.id);
            }
        } else {
            userRecord.missed = 0;
        }

        userRecord.alive = false;
        connectedUsers.set(uid, userRecord);
        socket.emit("ping");
    });
}, HEARTBEAT_INTERVAL);

io.on("connection", (socket) => {
    console.log("🔌 Socket connected:", socket.id);

    // 🆕 नया इवेंट हैंडलर
    socket.on("user_status", (data) => {
        console.log(`🌐 User ${data.userId} status updated to: ${data.status}`);
        const userId = String(data.userId);

        let userRecord = connectedUsers.get(userId) || {
            socketIds: new Set(),
            alive: true,
            rooms: new Set(),
            missed: 0
        };

        if(data.status === "online") {
            userRecord.alive = true;
            userRecord.socketIds.add(socket.id);
            userRecord.missed = 0;
            connectedUsers.set(userId, userRecord);
        } else if (data.status === "offline") {
            userRecord.socketIds.delete(socket.id);
            if (userRecord.socketIds.size === 0) {
                connectedUsers.delete(userId);
            }
        }
        
        io.emit("user_status", {
            userId: userId,
            status: data.status
        });
    });

    socket.on("register", async (userId) => {
    console.log(`📝 Registering user: ${userId} for socket: ${socket.id}`);

    if (!userId) {
        console.warn("⚠️ Registration failed: userId is null or undefined.");
        return;
    }

    const uid = String(userId);
    socket.data.userId = uid;
    socketToUserMap.set(socket.id, uid);

    let record = connectedUsers.get(uid) || {
        socketIds: new Set(),
        alive: true,
        rooms: new Set(),
        missed: 0
    };
    record.socketIds.add(socket.id);
    record.alive = true;
    connectedUsers.set(uid, record);

    console.log(`✅ User ${uid} is now online. Total sockets: ${record.socketIds.size}`);

    // ⚠️ यहां से पुराना "user_status" ब्रॉडकास्ट हटा दिया गया है
    // अब यह `user_status` इवेंट हैंडलर में होगा

    // Join user-specific room
    const userRoom = `user:${uid}`;
    if (!socket.rooms.has(userRoom)) {
        socket.join(userRoom);
        console.log(`✅ Socket ${socket.id} joined user room: ${userRoom}`);
    }

    // Handle pending messages
    console.log("⏳ Checking for pending messages on registration.");
    const pending = await fetchPendingForReceiver(uid);

    if (pending.length) {
        const userIds = [...new Set(pending.flatMap(m => [m.sender_id, m.receiver_id]))];
        const userMap = {};

        await Promise.all(
            userIds.map(async (id) => {
                userMap[id] = await getUserDetails(id);
            })
        );

        const idsToMark = [];

        for (const m of pending) {
            const payload = {
                message_id: m.message_id,
                chat_id: m.chat_id,
                sender_id: m.sender_id,
                receiver_id: m.receiver_id,
                message_type: m.message_type,
                message_text: m.message_text,
                media_url: m.media_url,
                is_read: m.is_read == 1,
                is_delivered: m.is_delivered == 1,
                timestamp: m.timestamp,
                sender_phone: userMap[m.sender_id]?.normalized_phone || null,
                receiver_phone: userMap[m.receiver_id]?.normalized_phone || null,
                // ✅ CRITICAL FIX: Include group_id, image_index, total_images from database message
                group_id: m.group_id || null,
                image_index: m.image_index !== undefined && m.image_index !== null ? m.image_index : null,
                total_images: m.total_images !== undefined && m.total_images !== null ? m.total_images : null
            };

            console.log(`📩 Delivering pending message ID ${m.message_id} to user ${uid}.`);

            socket.emit("receive_message", payload);

            const senderRecord = connectedUsers.get(String(m.sender_id));
            if (senderRecord) {
                for (const sId of senderRecord.socketIds) {
                    const senderSocket = io.sockets.sockets.get(sId);
                    if (senderSocket) {
                        senderSocket.emit("message_delivered", {
                            message_id: m.message_id,
                            chat_id: m.chat_id,
                            receiver_id: m.receiver_id
                        });
                        console.log(`✅ Notified sender ${m.sender_id} about delivery of message ${m.message_id}`);
                    }
                }
            }

            idsToMark.push(m.message_id);
        }

        if (idsToMark.length) {
            await markDeliveredBulk(idsToMark);
            console.log(`✅ Marked ${idsToMark.length} messages as delivered in DB.`);
        }
    }
});

    socket.on("pong", () => {
        const userId = socketToUserMap.get(socket.id);
        if (!userId) return;
        const u = connectedUsers.get(userId);
        if (!u) return;
        u.alive = true;
        connectedUsers.set(userId, u);
        console.log(`❤️ Pong received from user ${userId}. Socket ${socket.id} is alive.`);
    });

    socket.on("join_chat", (data) => {
        const userId = socket.data.userId || socketToUserMap.get(socket.id);
        const room = (typeof data === 'object' && data.chatId) ? String(data.chatId) : String(data);
        if (!room) {
            console.warn("⚠️ join_chat failed: invalid room ID.");
            return;
        }
        if (!socket.rooms.has(room)) {
            socket.join(room);
            console.log(`✅ Socket ${socket.id} joined chat room: ${room}`);
        }
        if (userId) {
            const rec = connectedUsers.get(userId) || {
                socketIds: new Set(),
                alive: true,
                rooms: new Set(),
                missed: 0
            };
            rec.rooms.add(room);
            connectedUsers.set(userId, rec);
        }
    });

socket.on("send_message", async (data) => {
  console.log("💬 send_message event received:", data);

  // Skip marketplace chat messages (they have chatRoomId, not chat_id)
    if (data.chatRoomId) {
      console.log("🔄 Skipping marketplace chat message - handled by marketplace handlers");
      return;
    }
    
  try {
    // 1️⃣ Message PHP API में save
    const resp = await axios.post(`${PHP_API_BASE}/send_message.php`, data, {
      headers: { "Content-Type": "application/json" }
    });

    if (!resp.data || !resp.data.success) {
      throw new Error(resp.data?.error || "PHP save failed");
    }

    const messageData = resp.data.data;

    // 2️⃣ Sender और Receiver details
    const [sender, receiver] = await Promise.all([
      getUserDetails(messageData.sender_id),
      getUserDetails(data.receiver_id)
    ]);

    // 3️⃣ Final payload
    const payload = {
      message_id: messageData.message_id,
      chat_id: messageData.chat_id,
      sender_id: messageData.sender_id,
      receiver_id: data.receiver_id,
      message_type: messageData.message_type,
      message_text: messageData.message_text,
      media_url: messageData.media_url || data.media_url || null,
      is_read: false,
      is_delivered: 0,
      timestamp: messageData.timestamp || new Date().toISOString(),
      sender_phone: sender?.normalized_phone || null,
      receiver_phone: receiver?.normalized_phone || null,
      // ✅ CRITICAL FIX: Include group_id, image_index, total_images from messageData (PHP API) or data (client request)
      group_id: messageData.group_id || data.group_id || null,
      image_index: messageData.image_index !== undefined ? messageData.image_index : (data.image_index !== undefined ? data.image_index : null),
      total_images: messageData.total_images !== undefined ? messageData.total_images : (data.total_images !== undefined ? data.total_images : null)
    };

    // 4️⃣ Sender को तुरंत response भेजना (temp_id resolve)
    socket.emit("new_message", { ...payload, temp_id: data.temp_id });

    // 5️⃣ Check receiver online/offline properly
    const receiverRecord = connectedUsers.get(String(data.receiver_id));
    const receiverOnline = receiverRecord && receiverRecord.socketIds.size > 0;

    if (receiverOnline) {
      // ✅ Receiver online → socket emit only
      io.to(`user:${data.receiver_id}`).emit("receive_message", payload);
      console.log(`📨 Message sent to receiver ${data.receiver_id} via socket`);

      // Sender को delivery receipt भेजना
      const senderRecord = connectedUsers.get(String(data.sender_id));
      if (senderRecord) {
        for (const sId of senderRecord.socketIds) {
          const senderSocket = io.sockets.sockets.get(sId);
          if (senderSocket) {
            senderSocket.emit("message_delivered", {
              message_id: messageData.message_id,
              chat_id: messageData.chat_id,
              receiver_id: data.receiver_id
            });
            console.log(`✅ Sender ${data.sender_id} notified about delivery`);
          }
        }
      }

      await markDeliveredBulk([messageData.message_id]);
    } else {
      // ❌ Receiver offline → send FCM
      console.log(`ℹ️ Receiver ${data.receiver_id} offline, sending FCM...`);
      try {
        // 🛑 FIX: 5 parameters pass kiye gaye hain
        await sendFcmNotification(
          data.receiver_id,
          messageData.message_text, // Encrypted Text
          messageData.chat_id,
          messageData.sender_id,
          sender?.name || "New message" // Sender's Name for notification title
        );
        console.log(`📲 FCM sent to offline user ${data.receiver_id}`);
      } catch (fcmErr) {
        console.error("❌ FCM send error:", fcmErr.message);
      }

      // Sender को pending message info
      socket.emit("message_pending", {
        message_id: messageData.message_id,
        chat_id: messageData.chat_id,
        receiver_id: data.receiver_id
      });
    }
  } catch (err) {
    console.error("❌ send_message error:", err.message);
    socket.emit("error", { source: "send_message", message: err.message });
  }
});




socket.on("mark_delivered", async (data) => {
    console.log("✅ mark_delivered received:", data);

    if (!data.message_id) return;

    await markDeliveredBulk([data.message_id]);

    io.to(`user:${data.sender_id}`).emit("message_delivered", {
        message_id: data.message_id,
        chat_id: data.chat_id,
        receiver_id: data.receiver_id
    });
});

socket.on("mark_delivered_bulk", async (data) => {
    try {
        const messageIds = data.message_ids || [];
        if (!messageIds.length) return;

        await markDeliveredBulk(messageIds);
        console.log(`✅ Bulk messages marked delivered: ${messageIds}`);

        for (const msgId of messageIds) {
            const messageData = await axios.get(`${PHP_API_BASE}/get_message_by_id.php`, { params: { message_id: msgId } });
            const senderId = messageData.data.sender_id;

            if (connectedUsers.has(String(senderId))) {
                for (const sId of connectedUsers.get(String(senderId)).socketIds) {
                    const senderSocket = io.sockets.sockets.get(sId);
                    if (senderSocket) {
                        senderSocket.emit("message_delivered", {
                            message_id: msgId
                        });
                    }
                }
            }
        }
    } catch (err) {
        console.error("❌ mark_delivered_bulk error:", err);
    }
});

socket.on("forward_messages", async (data) => {
  try {
    if (!data.original_message_id || !data.to_chat_id || !data.forwarded_by_id) {
      return socket.emit("error", {
        source: "forward_messages",
        message: "Missing required fields",
      });
    }

    const [origRows] = await pool.query(
      "SELECT * FROM messages WHERE message_id = ?",
      [data.original_message_id]
    );

    if (origRows.length === 0) {
      return socket.emit("error", {
        source: "forward_messages",
        message: "Original message not found",
      });
    }

    const orig = origRows[0];

    const now = new Date();
    const forwardedAt = new Date(
      now.toLocaleString("en-US", { timeZone: "Asia/Kolkata" })
    )
      .toISOString()
      .slice(0, 19)
      .replace("T", " ");

    const [result] = await pool.query(
      `INSERT INTO forwards (original_message_id, forwarded_by_id, to_chat_id, to_user_id, forwarded_at) 
       VALUES (?, ?, ?, ?, ?)`,
      [
        data.original_message_id,
        data.forwarded_by_id,
        data.to_chat_id,
        data.to_user_id || null,
        forwardedAt,
      ]
    );

    const forwardPayload = {
      ...orig,
      chat_id: data.to_chat_id,
      receiver_id: data.to_user_id || null,
      forwarded_from_id: orig.message_id,
      is_forwarded: true,
      // ✅ CRITICAL FIX: Preserve group_id, image_index, total_images when forwarding (if present in orig)
      group_id: orig.group_id || null,
      image_index: orig.image_index !== undefined ? orig.image_index : null,
      total_images: orig.total_images !== undefined ? orig.total_images : null
    };

    io.to(`chat:${data.to_chat_id}`).emit("receive_message", forwardPayload);

    socket.emit("forward_success", {
      forward_id: result.insertId,
      forwarded: forwardPayload,
    });

    console.log(
      `✅ Message ${data.original_message_id} forwarded to chat ${data.to_chat_id}`
    );

  } catch (err) {
    console.error("❌ forward_messages error", err);
    socket.emit("error", {
      source: "forward_messages",
      message: err.message,
    });
  }
});

socket.on("mark_read_bulk", async (data) => {
    try {
        console.log("👀 mark_read_bulk event received:", data);

        if (!Array.isArray(data.message_ids) || data.message_ids.length === 0) {
            console.warn("⚠️ mark_read_bulk failed: no message IDs provided.");
            return;
        }

        await markReadBulk(data.message_ids);

        console.log(`✅ Messages marked as read. Broadcasting to chat ID: ${data.chat_id}`);

        io.to(String(data.chat_id)).emit("message_read", {
            message_ids: data.message_ids,
            chat_id: data.chat_id,
            reader_id: data.reader_id
        });
    } catch (err) {
        console.error("❌ Error in mark_read_bulk:", err);
    }
});

    socket.on("typing_start", (data) => {
        console.log(`✍️ User ${data.user_id} is typing in chat ${data.chat_id}.`);
        socket.to(String(data.chat_id)).emit("user_typing", {
            chat_id: data.chat_id,
            user_id: data.user_id,
            isTyping: true
        });
    });

    socket.on("typing_stop", (data) => {
        console.log(`🛑 User ${data.user_id} stopped typing in chat ${data.chat_id}.`);
        socket.to(String(data.chat_id)).emit("user_typing", {
            chat_id: data.chat_id,
            user_id: data.user_id,
            isTyping: false
        });
    });

    socket.on("message_reaction", (data) => {
        console.log(`👍 New reaction from user ${data.user_id} on message ${data.message_id}.`);
        io.to(String(data.chat_id)).emit("message_reaction", data);
    });

    socket.on("delete_message", (data) => {
        console.log(`🗑️ Message ${data.message_id} requested for deletion.`);
        io.to(String(data.chat_id)).emit("delete_message", data);
    });

    socket.on("fetch_history", async (data) => {
        console.log(`📜 Fetching chat history for chat ID: ${data.chat_id}`);
        try {
            const r = await axios.get(`${PHP_API_BASE}/get_messages.php`, {
                params: {
                    chat_id: data.chat_id
                }
            });
            console.log(`✅ History fetched for chat ${data.chat_id}. Sending to socket.`);
            socket.emit("chat_history", r.data);
        } catch (err) {
            console.error("❌ fetch_history error:", err.message);
            socket.emit("error", {
                source: "fetch_history",
                message: err.message
            });
        }
    });

    socket.on("disconnect", () => {
        const uid = socketToUserMap.get(socket.id);
        console.log(`🔌 Socket disconnected: ${socket.id}. User ID: ${uid}`);
        socketToUserMap.delete(socket.id);
        if (!uid) return;
        const rec = connectedUsers.get(uid);
        if (!rec) return;
        rec.socketIds.delete(socket.id);
        if (!rec.socketIds.size) {
            console.log(`❌ User ${uid} has no more connected sockets. Marking as offline.`);
            connectedUsers.delete(uid);
            io.emit("user_status", {
                userId: uid,
                status: "offline"
            });
        } else {
            console.log(`ℹ️ User ${uid} still has ${rec.socketIds.size} sockets connected.`);
            connectedUsers.set(uid, rec);
        }
    });
});

// ----------------- INITIALIZE MARKETPLACE SOCKET -----------------
//const { setupMarketplaceSocket } = require("./routes/marketplace/chatHelpers");
setupMarketplaceSocket(io, pool);
console.log("✅ Marketplace socket events initialized");

// ----------------- INITIALIZE PAYMENT TIMEOUT SCHEDULER -----------------
const PaymentTimeoutScheduler = require("./schedulers/paymentTimeoutScheduler");
const paymentScheduler = new PaymentTimeoutScheduler(app);
paymentScheduler.start();
console.log("✅ Payment timeout scheduler initialized");

server.listen(PORT, () => console.log(`🚀 Socket server listening on port ${PORT}`));