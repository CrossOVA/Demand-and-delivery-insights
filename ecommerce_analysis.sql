-- Аналитические запросы для сервиса заказов и доставки
-- MySQL 8+. Требуются таблицы нормализованной схемы:
-- customers, orders, orders_product, products, info, app_sess.

-- 1. Чаще всего встречающийся в заказах товар
SELECT p.product_id, p.product_name,
       COUNT(DISTINCT op.order_id) AS orders_count
FROM orders_product op
JOIN products p ON p.product_id = op.product_id
GROUP BY p.product_id, p.product_name
ORDER BY orders_count DESC
LIMIT 1;

-- 2. День с максимальным количеством завершенных доставок
SELECT delivery_dt, COUNT(*) AS completed_deliveries
FROM info
WHERE is_completed_flg = 'True'
GROUP BY delivery_dt
ORDER BY completed_deliveries DESC
LIMIT 1;

-- 3. День с минимальным числом завершенных доставок среди дней с доставками
SELECT delivery_dt, COUNT(*) AS completed_deliveries
FROM info
WHERE is_completed_flg = 'True'
GROUP BY delivery_dt
ORDER BY completed_deliveries ASC
LIMIT 1;

-- 4. Средняя длительность сессии в минутах
SELECT device_name,
  ROUND(AVG(TIMESTAMPDIFF(SECOND,
       STR_TO_DATE(start_dttm, '%d.%m.%y %H:%i'),
       STR_TO_DATE(finish_dttm, '%d.%m.%y %H:%i')))/60, 2) AS avg_minutes
FROM app_sess
GROUP BY device_name;

-- 5. Заказ с максимальным числом РАЗНЫХ товаров
SELECT order_id, COUNT(DISTINCT product_id) AS different_products
FROM orders_product
GROUP BY order_id
ORDER BY different_products DESC
LIMIT 1;

-- 6. Незавершенные доставки с 2022 года помесячно
SELECT YEAR(STR_TO_DATE(delivery_dt, '%d-%m-%Y')) AS order_year,
       MONTH(STR_TO_DATE(delivery_dt, '%d-%m-%Y')) AS order_month,
       COUNT(*) AS failed_deliveries
FROM info
WHERE is_completed_flg = 'False'
  AND YEAR(STR_TO_DATE(delivery_dt, '%d-%m-%Y')) >= 2022
GROUP BY order_year, order_month
ORDER BY order_year, order_month;

-- 7. Заказы по способу оплаты и году
SELECT YEAR(order_dt) AS order_year, payment_method, COUNT(*) AS orders_count
FROM orders
GROUP BY order_year, payment_method
ORDER BY order_year, payment_method;

-- 8. Топ-10 клиентов по количеству заказов
SELECT c.customer_id, c.first_name, c.middle_name, c.last_name,
       COUNT(o.order_id) AS orders_count
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.middle_name, c.last_name
ORDER BY orders_count DESC
LIMIT 10;

-- 9. Самая частая товарная группа в возрастных сегментах
-- Полуоткрытые интервалы: 18-29, 30-44, 45-59, 60+ лет.
WITH counts AS (
 SELECT CASE
    WHEN TIMESTAMPDIFF(YEAR, STR_TO_DATE(c.birth_dt,'%d.%m.%Y'), CURDATE()) BETWEEN 18 AND 29 THEN '18-29'
    WHEN TIMESTAMPDIFF(YEAR, STR_TO_DATE(c.birth_dt,'%d.%m.%Y'), CURDATE()) BETWEEN 30 AND 44 THEN '30-44'
    WHEN TIMESTAMPDIFF(YEAR, STR_TO_DATE(c.birth_dt,'%d.%m.%Y'), CURDATE()) BETWEEN 45 AND 59 THEN '45-59'
    ELSE '60+'
  END AS age_group,
  p.product_group_name, COUNT(*) AS sales_count
 FROM customers c
 JOIN orders o ON o.customer_id=c.customer_id
 JOIN orders_product op ON op.order_id=o.order_id
 JOIN products p ON p.product_id=op.product_id
 WHERE TIMESTAMPDIFF(YEAR, STR_TO_DATE(c.birth_dt,'%d.%m.%Y'), CURDATE()) >= 18
 GROUP BY age_group, p.product_group_name
), ranked AS (
 SELECT *, ROW_NUMBER() OVER (PARTITION BY age_group ORDER BY sales_count DESC, product_group_name) AS r
 FROM counts
)
SELECT age_group, product_group_name, sales_count
FROM ranked WHERE r=1 ORDER BY age_group;

-- 10. Какой товар чаще всего встречается в чеке со «Штанами»
SELECT related.product_name, COUNT(DISTINCT second.order_id) AS joint_orders
FROM orders_product source_line
JOIN products source_prod ON source_prod.product_id=source_line.product_id
JOIN orders_product second ON second.order_id=source_line.order_id
JOIN products related ON related.product_id=second.product_id
WHERE source_prod.product_name='Штаны'
  AND second.product_id<>source_line.product_id
GROUP BY related.product_id, related.product_name
ORDER BY joint_orders DESC LIMIT 1;
