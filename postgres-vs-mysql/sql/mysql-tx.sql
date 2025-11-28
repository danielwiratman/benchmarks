START TRANSACTION;

-- 1. Fetch user
SELECT * FROM users WHERE id = ?;

-- 2. Update user name
UPDATE users SET full_name = ? WHERE id = ?;

-- 3. Insert audit log
INSERT INTO audit_logs (user_id, action)
VALUES (?, 'updated_profile');

-- 4. Fetch last 5 orders
SELECT * FROM orders 
WHERE user_id = ?
ORDER BY id DESC
LIMIT 5;

-- 5. Fetch items for those orders
SELECT oi.*, p.name, p.price
FROM order_items oi
JOIN products p ON oi.product_id = p.id
WHERE oi.order_id IN (
    SELECT id FROM orders WHERE user_id = ? ORDER BY id DESC LIMIT 5
);

-- 6. Decrement product stock
UPDATE products SET stock = stock - 1 WHERE id = ?;

-- 7. Insert order
INSERT INTO orders (user_id, total)
VALUES (?, ?);

SET @order_id = LAST_INSERT_ID();

-- 8. Insert order item
INSERT INTO order_items (order_id, product_id, quantity, price_each)
VALUES (@order_id, ?, 1, (SELECT price FROM products WHERE id=?));

COMMIT;
