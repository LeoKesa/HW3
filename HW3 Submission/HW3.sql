-- Adding primary keys, foreign keys and constraints specified in problem requirments 
ALTER TABLE merchants ADD CONSTRAINT pk_merchants PRIMARY KEY (mid); -- merchants primary key
ALTER TABLE customers ADD CONSTRAINT pk_customers PRIMARY KEY (cid); -- customers primary key 

ALTER TABLE sell 
	ADD CONSTRAINT pk_sell PRIMARY KEY (mid, pid), -- Composite primary key for sell
	ADD CONSTRAINT fk_sell_merchant FOREIGN KEY (mid) REFERENCES merchants(mid), -- Foreign Key to merchants
	ADD CONSTRAINT fk_sell_product FOREIGN KEY (pid) REFERENCES products(pid), -- Foreign Key to products
	ADD CONSTRAINT CHECK (price BETWEEN 0 AND 100000), -- Sell price constraint: between 0 and 100,000
	ADD CONSTRAINT CHECK (quantity_available BETWEEN 0 AND 1000); --  quantity_available constraint: between 0 and 1,000

ALTER TABLE contain 
	ADD CONSTRAINT pk_contain PRIMARY KEY (oid, pid), -- Composite primary key for contain
	ADD CONSTRAINT fk_contain_order FOREIGN KEY (oid) REFERENCES orders(oid), -- Foreign Key to orders
	ADD CONSTRAINT fk_contain_product FOREIGN KEY (pid) REFERENCES products(pid); -- Foreign Key to products

ALTER TABLE place 
	ADD CONSTRAINT pk_place PRIMARY KEY (cid, oid),  -- Composite primary key for place
	ADD CONSTRAINT fk_place_customer FOREIGN KEY (cid) REFERENCES customers(cid), -- Foreign Key to customers
	ADD CONSTRAINT fk_place_order FOREIGN KEY (oid) REFERENCES orders(oid), -- Foreign Key to orders
	ADD CONSTRAINT CHECK (order_date <= CURDATE()); -- Valid dates requirement, less than current date 

ALTER TABLE products
	ADD CONSTRAINT pk_products PRIMARY KEY (pid), -- primary key for products
    ADD CONSTRAINT CHECK (name IN ('Printer', 'Ethernet Adapter', 'Desktop', 'Hard Drive', 'Laptop', 'Router', 'Network Card', 'Super Drive', 'Monitor')), -- name constraint
    ADD CONSTRAINT CHECK (category IN ('Peripheral', 'Networking', 'Computer')); -- category constraint: Peripheral, Networking, Computer
    
ALTER TABLE orders
	ADD CONSTRAINT pk_orders PRIMARY KEY (oid), -- primary key for orders 
    ADD CONSTRAINT CHECK (shipping_cost BETWEEN 0 AND 500), -- shipping_cost constraint: between 0 and 500
    ADD CONSTRAINT CHECK (shipping_method IN ('UPS', 'FedEx', 'USPS')); -- shipping_method constraint: UPS, FedEx, USPS
    
-- ///////////// Problem 1 ///////////// --
select merchants.name, products.name
from merchants
join sell on merchants.mid = sell.mid
join products on sell.pid = products.pid
where sell.quantity_available = 0; -- checks products quantity available attribute

-- ///////////////Problem 2////////////////// --
select products.name,products.description
from products
left join sell on products.pid = sell.pid 
where sell.pid IS NULL; -- checks if a product has not been sold if pid is not returned by left join

-- ///////////////Problem 3////////////////// --
select count(distinct customers.cid) AS customer_count_Super_no_Router -- will display customer ID and name where customers have ordered Super Drive and not a Router
from customers
join place on customers.cid = place.cid
join contain on place.oid = contain.oid
join products on contain.pid = products.pid
where products.name = 'Super Drive' -- selects all products with the name Super Drive (SATA?) 
AND customers.cid NOT IN (
	SELECT customers.cid
    From customers
    JOIN place on customers.cid = place.cid
    join contain on place.oid = contain.oid
    join products on contain.pid = products.pid
    where products.name = 'Router' -- Filters all products with the name Router from results
);

-- //////////////////////////////////////////////// Problem 4 ///////////////////////////////////////////////
SET SQL_SAFE_UPDATES = 0;
UPDATE sell
SET price = price * 0.8 -- 20% sale
WHERE pid IN(
SELECT products.pid
FROM products 
Where products.category = 'Networking' -- Checks the products name 
)
AND mid = (
select mid from merchants where merchants.name = 'HP'
);

-- /////////////////////////////////////////////// problem 5 ///////////////////////////////////////////////////////////
select products.name, sell.price, customers.fullname -- displays product name price and the customer name as well to ensure results are Uriel Whitney
from customers
join place on customers.cid = place.cid
join contain on place.oid = contain.oid
join products on contain.pid = products.pid
join sell on products.pid = sell.pid
join merchants on sell.mid = merchants.mid
where customers.fullname = 'Uriel Whitney' -- checks customer name
and merchants.name = 'Acer'; -- checks merchant name for correct value 

-- ////////////////////////////////// problem 6 ////////////////////////////////////////////
SELECT merchants.name AS Merchant, YEAR(place.order_date) AS Year, SUM(sell.price) AS Annual_Total_Sales -- Displays sum of all products sold by a Merchant per year
FROM merchants
JOIN sell ON merchants.mid = sell.mid
JOIN contain ON sell.pid = contain.pid
JOIN place ON contain.oid = place.oid
GROUP BY Merchant, YEAR(place.order_date) -- Groups by Merchant and year to aggregate the sales per company per year
ORDER BY Merchant, Year; 

-- ////////////////////////////////// problem 7 ////////////////////////////////////////////
SELECT merchants.name AS Merchant,YEAR(place.order_date) AS Year, 
SUM(sell.price) AS Annual_Total_Sales -- displays merchant name, the year and the annual sales per year for each company 
FROM merchants
JOIN sell ON merchants.mid = sell.mid
JOIN contain ON sell.pid = contain.pid
JOIN place ON contain.oid = place.oid -- assumes every product which has been ordered is considered a sale: 
GROUP BY Merchant, YEAR(place.order_date) -- ensures that the sum of sell price is for each company per year
ORDER BY Annual_Total_Sales DESC 
LIMIT 1;

-- ////////////////////////////////// problem 8 ////////////////////////////////////////////
select orders.shipping_method, AVG(orders.shipping_cost) AS AVG_shipping_cost -- displays shipping method with average cost
from orders 
group by orders.shipping_method
ORDER BY AVG_shipping_cost ASC -- displays smallest value first and limits 1 to show min value for shipping cost
LIMIT 1;

-- ////////////////////////////////// problem 9 ////////////////////////////////////////
WITH CategorySales AS ( -- CTE CategorySales calculates total sales for category and groups the result by merchant name and product category
SELECT merchants.name AS Merchant, products.category AS Category, SUM(sell.price) AS Total_Sales
from merchants 
JOIN sell on merchants.mid = sell.mid 
JOIN contain on sell.pid = contain.pid
JOIN orders on contain.oid = orders.oid
join products on contain.pid = products.pid
group by merchants.name, products.category
),
MaxCat AS ( -- CTE Finds maximum Total_Sales (MAXSales) for each merchant 
SELECT Merchant,
MAX(Total_Sales) AS MAXSales -- Maximum value of the total sales 
FROM CategorySales
GROUP BY Merchant
)
SELECT CategorySales.Merchant,CategorySales.Category,CategorySales.Total_Sales -- joins the two CTEs to filter each category with maximum sales per merchant 
FROM CategorySales
JOIN Maxcat on CategorySales.Merchant = MaxCat.Merchant AND CategorySales.Total_Sales = MaxCat.MAXSales;

-- ////////////////////////// Problem 10 /////////////////////////////////--
WITH CustomerSpending AS ( -- Calculates total spending for each customer per Merchant by summing price
SELECT 
	merchants.name AS Merchant,
    customers.cid AS custID, -- Alias for customer ID 
    customers.fullname AS CNAME, -- Alias for customer name 
    SUM(sell.price) AS TotalSpent -- alias for sales per merchant
    
FROM merchants

JOIN sell on merchants.mid = sell.mid
join contain on sell.pid = contain.pid
join orders on contain.oid = orders.oid
join place on orders.oid = place.oid
join customers on place.cid = customers.cid
GROUP BY merchants.name, customers.cid
),
MinMaxSpending AS ( -- Calculates maximium ( MaxSpent ) and ( MinSpent ) for each merchant based on total spending via Customer Spending CTE 
	SELECT Merchant, MAX(TotalSpent) AS MaxSpent, MIN(TotalSpent) AS MinSpent
	FROM CustomerSpending
	GROUP BY Merchant
)
SELECT 
	CustomerSpending.Merchant,
    CustomerSpending.custID,
    CustomerSpending.CName,
    CustomerSpending.TotalSpent,
    CASE	-- labels customer as Max Spender or Min Spender depending on what value is returned 
		WHEN CustomerSpending.TotalSpent = MinMaxSpending.MaxSpent THEN 'Max Spender'
        WHEN CustomerSpending.TotalSpent = MinMaxSpending.MinSpent THEN 'Min Spender'
        ELSE NULL
	END AS SpendingType
FROM CustomerSpending
JOIN MinMaxSpending ON CustomerSpending.Merchant = MinMaxSpending.Merchant

WHERE CustomerSpending.TotalSpent = MinMaxSpending.MaxSpent or CustomerSpending.TotalSpent = MinMaxSpending.MinSpent 
-- ensures only customers who have spent max or min are in results
ORDER BY CustomerSpending.Merchant, SpendingType DESC;

