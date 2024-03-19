/*
--Creating all the tables needed for this database
CREATE TABLE orders (
	order_no INTEGER NOT NULL PRIMARY KEY,
	order_date datetime NOT NULL,
	customer_id varchar(10) NOT NULL,
	share_id varchar(10) NOT NULL,
	share_count INTEGER NOT NULL,
	per_share_price MONEY NOT NULL,
	buy_or_sell char NOT NULL
)

CREATE TABLE buyers (
	order_no INTEGER NOT NULL PRIMARY KEY,
	order_date datetime2 NOT NULL,
	customer_id varchar(10) NOT NULL,
	share_id varchar(10) NOT NULL,
	share_count INTEGER NOT NULL,
	per_share_price MONEY NOT NULL
)

CREATE TABLE sellers (
	order_no INTEGER NOT NULL PRIMARY KEY,
	order_date datetime2 NOT NULL,
	customer_id varchar(10) NOT NULL,
	share_id varchar(10) NOT NULL,
	share_count INTEGER NOT NULL,
	per_share_price MONEY NOT NULL
)

CREATE TABLE finished_orders (
	order_no INTEGER NOT NULL,
	order_date datetime NOT NULL,
	customer_id varchar(10) NOT NULL,
	share_id varchar(10) NOT NULL,
	share_count INTEGER NOT NULL,
	buy_or_sell char NOT NULL
)

CREATE TABLE deleted_orders (
	order_no INTEGER NOT NULL PRIMARY KEY,
	order_date datetime NOT NULL,
	customer_id varchar(10) NOT NULL,
	share_id varchar(10) NOT NULL,
	share_count INTEGER NOT NULL,
	buy_or_sell char NOT NULL
)
*/

--Procedure new_order will be executed evey time either a new buy or sell order is placed by a customer
/*CREATE PROCEDURE new_order(@customer_id_n varchar 10, @share_id_n varchar(10), @share_count_n INTEGER, @per_share_price_n MONEY, @buy_or_sell_n char)
AS
BEGIN
	DECLARE @new_order_no INTEGER; --declaring a  varible to hold anew order number
	SELECT @new_order_no = MAX(order_no)+1 FROM orders; --generate a new order number as 1 more than the maximum order number in orders table
	DECLARE @curr_date_time datetime2;
	SELECT @curr_date_time=SYSDATETIME()
	INSERT INTO dbo.orders (order_no,order_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
		VALUES(@new_order_no,@curr_date_time,@customer_id_n, @share_id_n, @share_count_n, @per_share_price_n, @buy_or_sell_n);
	IF @buy_or_sell_n = 'b' THEN
		INSERT INTO dbo.buyers(order_no, order_date,customer_id,share_id,share_count,per_share_price)
			VALUES(@new_order_no,@curr_date_time,@customer_id_n, @share_id_n, @share_count_n, @per_share_price_n);
		EXEC PROCEDURE exe_buy_sell(@new_order_no,@curr_date_time,@customer_id_n, @share_id_n, @share_count_n, @per_share_price_n);
	ELSE IF buy_or_sell_n = 's' THEN
		INSERT INTO dbo.sellers(order_no,order_date,customer_id,share_id,share_count,per_share_price)
			VALUES(@new_order_no,@curr_date_time,@customer_id_n, @share_id_n, @share_count_n, @per_share_price_n);
		EXEC PROCEDURE exe_buy_sell(@new_order_no,@curr_date_time,@customer_id_n, @share_id_n, @share_count_n, @per_share_price_n);
	END IF;
END;*/


--This procedure gets called from within buy_or_sell procedure to finish the execution of possible orders that are present in the buyer and seller tables
CREATE PROCEDURE exe_buy_sell(@new_order_no INTEGER,@curr_date_time datetime2,@customer_id_n varchar(10), @share_id_n varchar(10), @share_count_n INTEGER, @per_share_price_n money)	 
AS
BEGIN	
	DECLARE @available_options INTEGER;
	IF buy_or_sell_n = 'b' THEN		
		CREATE table #temp_sel AS 
			SELECT *, SUM(share_count) OVER (ORDER BY per_share_price,order_date) AS TOT_SHARES --Create a cumulative sum of the number of shares available for the buyer
			FROM dbo.sellers WHERE share_id=@share_id_n AND per_share_price<=@per_share_price_n 
			ORDER BY per_share_price,order_date;

		IF (SELECT record_num=COUNT(*) FROM #temp_sel) >0 THEN:
			--CREATE VIEW matched_sellers AS SELECT *,ROW_NUMBER() FROM dbo.sellers WHERE share_id=@share_id_n and per_share_price<=@per_share_price_n ORDER BY per_share_price, order_date; --SORT SELLERS TABLE BY PER SHARE PRICE ASCENDING, and then by TIME ASCENDING
			WHILE @share_count=0
						--
			END;
		END IF;
		DROP #temp_sel;
	ELSE IF buy_or_sell_n = 's' THEN	
		SELECT @available_options=COUNT(*) FROM dbo.buyers WHERE share_id=@share_id_n and per_share_price>=@per_share_price_n;
		IF @available_options>0 THEN
			--SORT BUYERS TABLE BY PER SHARE PRICE DESCENDING, and then by TIME ASCENDING
			--
		END IF;
	END IF;
END;

CREATE PROCEDURE DEL_ORDER(@order_no_n INTEGER)
BEGIN
-- Check if order number exists in executed orders

	-- if yes, can't be deleted, display messages "Order has beed fulfilled. Order can not be deleted."

	--if no, look up order in buy table and sell table
		-- copy that record from that table and delete record from the table

		--Add the record to deleted_orders and set the buy_or_sell column to b or s based upon where the order was located
		--Message "Order number -- was successfully cancled
END
