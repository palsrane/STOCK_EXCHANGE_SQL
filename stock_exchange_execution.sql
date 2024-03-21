CREATE OR ALTER PROCEDURE exe_buy_sell
	@order_no_n INTEGER,
	@order_date_n DATETIME2,
	@customer_id_n varchar(10),
	@share_id_n varchar(10),
	@share_count_n INTEGER,
	@per_share_price_n money,
	@buy_or_sell_n char
AS
BEGIN	
	DECLARE @cnt INT = 1;
	DECLARE @cnt_total INT;
	DECLARE @order_no_per_row INTEGER;
	DECLARE @order_date_per_row DATETIME2;
	DECLARE @share_nums_per_row INTEGER;
	DECLARE @per_share_price_per_row MONEY;
	DECLARE @customer_id_per_row varchar(10);
	DECLARE @execution_time DATETIME2;
	DECLARE @opp_of_buy_or_sell CHAR;

	CREATE TABLE #tmp_buy_sell(
		row_num INTEGER NOT NULL,
		order_no INTEGER NOT NULL,
		order_date DATETIME2 NOT NULL,
		customer_id varchar(10) NOT NULL,
		share_id varchar(10) NOT NULL,
		share_count INTEGER NOT NULL,
		per_share_price MONEY NOT NULL
	)
	
	IF @buy_or_sell_n = 'b'	
		INSERT INTO #tmp_buy_sell 			--temporary table share_id=@share_id_n and per_share_price<=@per_share_price_n ORDER BY per_share_price, order_date; cheapest seller on top
			SELECT ROW_NUMBER() OVER (ORDER BY per_share_price,order_date),order_no,	order_date,customer_id,share_id,	share_count,	per_share_price FROM dbo.orders WHERE share_id=@share_id_n AND per_share_price<=@per_share_price_n AND buy_or_sell = 'b'
			ORDER BY per_share_price,order_date;
		 SET @opp_of_buy_or_sell='s';
	IF @buy_or_sell_n = 's'
		INSERT INTO #tmp_buy_sell			--temporary table with share_id=@share_id_n and per_share_price>=@per_share_price_n ORDER BY per_share_price desc, order_date; highest buyer on top
			SELECT ROW_NUMBER() OVER (ORDER BY per_share_price DESC,order_date),order_no,order_date,customer_id,share_id,share_count,per_share_price FROM dbo.orders WHERE share_id=@share_id_n AND per_share_price>=@per_share_price_n 
			ORDER BY per_share_price DESC,order_date;
		 SET @opp_of_buy_or_sell='b';
		
	SELECT @cnt_total = COUNT(*) FROM #tmp_buy_sell; --total number of buyers
	IF @cnt_total <=0 
		PRINT CASE WHEN @buy_or_sell_n = 'b' THEN 'No matching purchase options available at this time' ELSE 'No buyers available at this time' END
	IF @cnt_total >0 --buyers are ready to buy at or more than your asking price
		WHILE @cnt<=@cnt_total
			SELECT @order_no_per_row=order_no, @order_date_per_row=order_date, @customer_id_per_row=customer_id, 
				@share_nums_per_row=share_count, @per_share_price_per_row=per_share_price
				FROM #tmp_buy_sell WHERE row_num=@cnt;
			IF @share_nums_per_row>= @share_count_n
				SELECT @execution_time=SYSDATETIME();
				--Insert executed seller record
				INSERT INTO dbo.executed_orders(order_no,order_date,execution_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
					VALUES(@order_no_n,@order_date_n,@execution_time,@customer_id_n,@share_id_n,@share_count_n,@per_share_price_per_row,@buy_or_sell_n);
				DELETE FROM dbo.orders WHERE order_no=@order_no_n; --Since sold all shares, deleting record from orders table
				--Insert executed buyer record
				INSERT INTO dbo.executed_orders(order_no, order_date, execution_date, customer_id,share_id,share_count,per_share_price,buy_or_sell)
					VALUES(@order_no_per_row, @order_date_per_row, @execution_time, @customer_id_per_row, @share_id_n, @share_count_n, @per_share_price_per_row, @opp_of_buy_or_sell);
				SET @share_nums_per_row = @share_nums_per_row-@share_count_n; --shares buyer could not buy yet
				UPDATE dbo.orders SET share_count=@share_nums_per_row WHERE order_no=@order_no_per_row; --Update the orders table to reflect how many shares are remaining					SET @cnt=@cnt_total+1; --coming out of while loop
					--ACID transaction regarding buyer's funds needs to happen.
				IF @share_nums_per_row < @share_count_n
				SELECT @execution_time=SYSDATETIME();
				--Insert excuted seller record with howmanyever shares that they have sold so far
				INSERT INTO dbo.executed_orders(order_no,order_date,execution_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
					VALUES(@order_no_n,@order_date_n,@execution_time,@customer_id_n,@share_id_n,@share_nums_per_row,@per_share_price_per_row,@buy_or_sell_n);
				SET @share_count_n = @share_count_n - @share_nums_per_row; --shares remaining to be sold
				UPDATE dbo.orders SET share_count=@share_count_n WHERE order_no=@order_no_n; --Update the orders table to reflect how many shares are remaining with the seller
				--Insert executed buyer record
				INSERT INTO dbo.executed_orders(order_no,order_date,execution_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
					VALUES(@order_no_per_row,@order_date_per_row,@execution_time,@customer_id_per_row,@share_id_n,@share_nums_per_row,@per_share_price_per_row,@opp_of_buy_or_sell);
				DELETE FROM dbo.orders WHERE order_no=@order_no_per_row; --Since buyer bought all shares they wanted, deleting record from orders table
				SET @cnt=@cnt+1; --basically increasing row count
				--ACID transaction regarding buyer's funds needs to happen.
	DROP TABLE #tmp_buy_sell; --dropping temporary table before the end of the procedure
	
END
GO

--Procedure new_order will be executed evey time either a new buy or sell order is placed by a customer
CREATE OR ALTER PROCEDURE new_order
	@customer_id_n varchar (10), 
	@share_id_n varchar(10), 
	@share_count_n INTEGER, 
	@per_share_price_n MONEY, 
	@buy_or_sell_n char
AS
BEGIN
	DECLARE @new_order_no INTEGER = 0; --declaring a  varible to hold a new order number
	SELECT @new_order_no = MAX(order_no) FROM dbo.orders; --generate a new order number as 1 more than the maximum order number in orders table
	SET @new_order_no= @new_order_no+1;
	DECLARE @curr_date_time DATETIME2;
	SELECT @curr_date_time=SYSDATETIME();
	INSERT INTO dbo.orders(order_no,order_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
		VALUES(@new_order_no,@curr_date_time,@customer_id_n, @share_id_n, @share_count_n, @per_share_price_n, @buy_or_sell_n);
	EXEC exe_buy_sell @new_order_no,@curr_date_time,@customer_id_n, @share_id_n, @share_count_n, @per_share_price_n,@buy_or_sell_n;
END
GO


CREATE OR ALTER PROCEDURE DEL_ORDER 
@order_no_n INTEGER 
AS
BEGIN
	DECLARE @deletion_time DATETIME2;
	CREATE TABLE #tmp_del(
		order_no INTEGER NOT NULL,
		order_date DATETIME2 NOT NULL,
		customer_id varchar(10) NOT NULL,
		share_id varchar(10) NOT NULL,
		share_count INTEGER NOT NULL,
		per_share_price MONEY NOT NULL,
		buy_or_sell CHAR NOT NULL
	)
	IF EXISTS (SELECT order_no FROM dbo.orders WHERE order_no=@order_no_n)
		INSERT INTO #tmp_del SELECT * FROM dbo.orders WHERE order_no=@order_no_n; --to save time before delete, holding record in a temporary table
		SET @deletion_time=SYSDATETIME();
		DELETE FROM dbo.orders WHERE order_no=@order_no_n;
		INSERT INTO dbo.deleted_orders(order_no,order_date,customer_id,share_id,share_count,per_share_price,buy_or_sell,deletion_date) 
			SELECT order_no,order_date,customer_id,share_id,share_count,per_share_price,buy_or_sell,@deletion_time FROM #tmp_del;	
	DROP TABLE #tmp_del
END
Go
