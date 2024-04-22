
--Creating all the tables needed for this database
CREATE TABLE orders (
	order_no INTEGER NOT NULL PRIMARY KEY,
	order_date DATETIME2 NOT NULL,
	customer_id varchar(10) NOT NULL,
	share_id varchar(10) NOT NULL,
	share_count INTEGER NOT NULL,
	per_share_price MONEY NOT NULL,
	buy_or_sell char NOT NULL
	)

CREATE TABLE executed_orders (
	order_no INTEGER NOT NULL,
	order_date DATETIME2 NOT NULL,
	execution_date DATETIME2 NOT NULL,
	customer_id varchar(10) NOT NULL,
	share_id varchar(10) NOT NULL,
	share_count INTEGER NOT NULL,
	per_share_price MONEY NOT NULL,
	buy_or_sell CHAR NOT NULL,
	exec_or_del CHAR NOT NULL
	)
