DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS audit_logs;

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    stock INT NOT NULL DEFAULT 0
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id),
    total NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id),
    product_id INT NOT NULL REFERENCES products(id),
    quantity INT NOT NULL,
    price_each NUMERIC(10,2) NOT NULL
);

CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INT,
    action TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_logs_user_id ON audit_logs(user_id);

INSERT INTO users (email, full_name)
SELECT CONCAT('user', i, '@test.com'), CONCAT('User ', i)
FROM generate_series(1, 50000) AS s(i);

INSERT INTO products (name, price, stock)
SELECT CONCAT('Product ', i), (random()*100)::numeric(10,2), floor(random()*200)
FROM generate_series(1, 2000) AS s(i);

INSERT INTO orders (user_id, total)
SELECT floor(random()*50000)+1, (random()*300)::numeric(10,2)
FROM generate_series(1, 50000);
