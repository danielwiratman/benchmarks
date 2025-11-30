DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS audit_logs;

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL DEFAULT 0
);

CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price_each DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE audit_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_logs_user_id ON audit_logs(user_id);

SET SESSION cte_max_recursion_depth = 60000;

WITH RECURSIVE seq AS (SELECT 1 AS i UNION ALL SELECT i+1 FROM seq WHERE i < 50000)
INSERT INTO users (email, full_name)
SELECT CONCAT('user', i, '@test.com'), CONCAT('User ', i)
FROM seq;

WITH RECURSIVE seq AS (SELECT 1 AS i UNION ALL SELECT i+1 FROM seq WHERE i < 2000)
INSERT INTO products (name, price, stock)
SELECT CONCAT('Product ', i), CAST(RAND()*100 AS DECIMAL(10,2)), FLOOR(RAND()*200)
FROM seq;

WITH RECURSIVE seq AS (SELECT 1 AS i UNION ALL SELECT i+1 FROM seq WHERE i < 50000)
INSERT INTO orders (user_id, total)
SELECT FLOOR(RAND()*50000)+1, CAST(RAND()*300 AS DECIMAL(10,2))
FROM seq;
