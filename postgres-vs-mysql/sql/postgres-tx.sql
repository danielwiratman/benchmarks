BEGIN;

-- 1. Fetch user
SELECT * FROM users WHERE id = $1;

-- 2. Update user name
UPDATE users SET full_name = $2 WHERE id = $1;

-- 3. Insert audit log
INSERT INTO audit_logs (user_id, action)
VALUES ($1, 'updated_profile');

-- 4. Fetch last 5 orders
SELECT * FROM orders 
WHERE user_id = $1
ORDER BY id DESC
LIMIT 5;

-- 5. Fetch items for those orders (join)
SELECT oi.*, p.name, p.price
FROM order_items oi
JOIN products p ON oi.product_id = p.id
WHERE oi.order_id IN (
    SELECT id FROM orders WHERE user_id = $1 ORDER BY id DESC LIMIT 5
);

-- 6. Decrement product stock
UPDATE products SET stock = stock - 1 WHERE id = $3;

-- 7. Insert new order
INSERT INTO orders (user_id, total) 
VALUES ($1, $4) RETURNING id;

-- 8. Insert order items
INSERT INTO order_items (order_id, product_id, quantity, price_each)
VALUES (currval('orders_id_seq'), $3, 1, (SELECT price FROM products WHERE id=$3));

COMMIT;

