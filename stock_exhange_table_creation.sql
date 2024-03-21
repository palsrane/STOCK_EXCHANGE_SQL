
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
	buy_or_sell char NOT NULL
)

CREATE TABLE deleted_orders (
	order_no INTEGER NOT NULL,
	order_date DATETIME2 NOT NULL,
	deletion_date DATETIME2 NOT NULL,
	customer_id varchar(10) NOT NULL,
	share_id varchar(10) NOT NULL,
	share_count INTEGER NOT NULL,
	per_share_price MONEY NOT NULL,
	buy_or_sell char NOT NULL
)





/* CREATE TABLE buyers (
	order_no INTEGER NOT NULL PRIMARY KEY,
	order_date DATETIME2 NOT NULL,
	customer_id varchar(10) NOT NULL,
	share_id varchar(10) NOT NULL,
	share_count INTEGER NOT NULL,
	per_share_price MONEY NOT NULL
)

CREATE TABLE sellers (
	order_no INTEGER NOT NULL PRIMARY KEY,
	order_date DATETIME2 NOT NULL,
	customer_id varchar(10) NOT NULL,
	share_id varchar(10) NOT NULL,
	share_count INTEGER NOT NULL,
	per_share_price MONEY NOT NULL
) 
--The following code was using three separate tables orders, buyers, and sellers. That was changed to just orders. No separate buyers/sellers records are maintained.
--This procedure gets called from within buy_or_sell procedure to finish the execution of possible orders that are present in the buyer and seller tables
CREATE PROCEDURE exe_buy_sell
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

	CREATE TABLE #tmp_buy_sell(
		row_num INTEGER NOT NULL,
		order_no INTEGER NOT NULL,
		order_date DATETIME2 NOT NULL,
		customer_id varchar(10) NOT NULL,
		share_id varchar(10) NOT NULL,
		share_count INTEGER NOT NULL,
		per_share_price MONEY NOT NULL
	)
	IF @buy_or_sell_n = 'b' THEN:	
		INSERT INTO #tmp_buy_sell 			--temporary table share_id=@share_id_n and per_share_price<=@per_share_price_n ORDER BY per_share_price, order_date; cheapest seller on top
			SELECT ROW_NUMBER() OVER (ORDER BY per_share_price,order_date),* FROM dbo.sellers WHERE share_id=@share_id_n AND per_share_price<=@per_share_price_n 
			ORDER BY per_share_price,order_date;
		SELECT @cnt_total = COUNT(*) FROM #tmp_buy_sell; --total number of sellers
		IF @cnt_total >0 THEN:
			WHILE @cnt<=@cnt_total
				SELECT @order_no_per_row=order_no, @order_date_per_row=order_date, @customer_id_per_row=customer_id, 
				@share_nums_per_row=share_count, @per_share_price_per_row=per_share_price
				FROM #tmp_buy_sell WHERE row_num=@cnt;
				IF @share_nums_per_row>= @share_count_n THEN:
					SELECT @execution_time=SYSDATETIME();
					--Insert executed buyer record
					INSERT INTO dbo.executed_orders(order_no,order_date,execution_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
						VALUES(@order_no_n,@order_date_n,@execution_time,@customer_id_n,@share_id_n,@share_count_n,@per_share_price_per_row,'b');
					DELETE FROM dbo.buyers WHERE order_no=@order_no_n; --Since bought all shares, deleting record from buys table
					--Insert executed seller record
					INSERT INTO dbo.executed_orders(order_no,order_date,execution_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
						VALUES(@order_no_per_row,@order_no_per_row,@execution_time,@customer_id_per_row,@share_id_n,@share_count_n,@per_share_price_per_row,'s');
					SET @share_nums_per_row = @share_nums_per_row-@share_count_n; --shares remaining with seller
					UPDATE dbo.sellers SET share_count=@share_nums_per_row WHERE order_no=@order_no_per_row; --Update the seller table to reflect how many shares are remaining
					SET @cnt=@cnt_total+1; --coming out of while loop
					--ACID transaction regarding buyer's funds needs to happen.
				ELSE: --@share_nums_per_row< @share_count_n
					SELECT @execution_time=SYSDATETIME();
					--Insert executed buyer record with howmanyever shares that they have bought so far
					INSERT INTO dbo.executed_orders(order_no,order_date,execution_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
						VALUES(@order_no_n,@order_date_n,@execution_time,@customer_id_n,@share_id_n,@share_nums_per_row,@per_share_price_per_row,'b');
					SET @share_count_n = @share_count_n - @share_nums_per_row; --shares remaining to be bought by the buyer
					UPDATE dbo.buyers SET share_count=@share_count_n WHERE order_no=@order_no_n; --Update the buyer table to reflect how many shares are remaining
					--Insert executed seller record
					INSERT INTO dbo.executed_orders (order_no,order_date,execution_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
						VALUES(@order_no_per_row,@order_no_per_row,@execution_time,@customer_id_per_row,@share_id_n,@share_nums_per_row,@per_share_price_per_row,'s');
					DELETE FROM dbo.sellers WHERE order_no=@order_no_per_row; --Since sold all shares, deleting record from sellers table
					SET @cnt=@cnt+1; --basically increasing row count
					--ACID transaction regarding buyer's funds needs to happen.
	ELSE: --@buy_or_sell_n = 's'	
		INSERT INTO #tmp_buy_sell			--temporary table with share_id=@share_id_n and per_share_price>=@per_share_price_n ORDER BY per_share_price desc, order_date; highest buyer on top
			VALUES(SELECT ROW_NUMBER() OVER (ORDER BY per_share_price DESC,order_date),* FROM dbo.buyers WHERE share_id=@share_id_n AND per_share_price>=@per_share_price_n 
			ORDER BY per_share_price DESC,order_date);
		SELECT @cnt_total = COUNT(*) FROM #tmp_buy_sell; --total number of buyers
		IF @cnt_total >0 THEN: --buyers are ready to buy at or more than your asking price
			WHILE @cnt<=@cnt_total
				SELECT @order_no_per_row=order_no, @order_date_per_row=order_date, @customer_id_per_row=customer_id, 
				@share_nums_per_row=share_count, @per_share_price_per_row=per_share_price
				FROM #tmp_buy_sell WHERE row_num=@cnt;
				IF @share_nums_per_row>= @share_count_n THEN:
					SELECT @execution_time=SYSDATETIME();
					--Insert executed seller record
					INSERT INTO dbo.executed_orders(order_no,order_date,execution_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
						VALUES(@order_no_n,@order_date_n,@execution_time,@customer_id_n,@share_id_n,@share_count_n,@per_share_price_per_row,'s');
					DELETE FROM dbo.sellers WHERE order_no=@order_no_n; --Since sold all shares, deleting record from seller table
					--Insert executed buyer record
					INSERT INTO dbo.executed_orders(order_no,order_date,execution_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
						VALUES(@order_no_per_row,@order_no_per_row,@execution_time,@customer_id_per_row,@share_id_n,@share_count_n,@per_share_price_per_row,'b');
					SET @share_nums_per_row = @share_nums_per_row-@share_count_n; --shares buyer could not buy yet
					UPDATE dbo.buyers SET share_count=@share_nums_per_row WHERE order_no=@order_no_per_row; --Update the buyers table to reflect how many shares are remaining
					SET @cnt=@cnt_total+1; --coming out of while loop
					--ACID transaction regarding buyer's funds needs to happen.
				ELSE: --@share_nums_per_row < @share_count_n
					SELECT @execution_time=SYSDATETIME();
					--Insert excuted seller record with howmanyever shares that they have sold so far
					INSERT INTO dbo.executed_orders(order_no,order_date,execution_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
						VALUES(@order_no_n,@order_date_n,@execution_time,@customer_id_n,@share_id_n,@share_nums_per_row,@per_share_price_per_row,'s');
					SET @share_count_n = @share_count_n - @share_nums_per_row; --shares remaining to be sold
					UPDATE dbo.seller SET share_count=@share_count_n WHERE order_no=@order_no_n; --Update the seller table to reflect how many shares are remaining
					--Insert executed buyer record
					INSERT INTO dbo.executed_orders(order_no,order_date,execution_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
						VALUES(@order_no_per_row,@order_no_per_row,@execution_time,@customer_id_per_row,@share_id_n,@share_nums_per_row,@per_share_price_per_row,'b');
					DELETE FROM dbo.buyers WHERE order_no=@order_no_per_row; --Since buyer bought all shares they wanted, deleting record from buyers table
					SET @cnt=@cnt+1; --basically increasing row count
					--ACID transaction regarding buyer's funds needs to happen.
	DROP TABLE #tmp_buy_sell; --dropping temporary table before the end of the procedure
END
GO

--Procedure new_order will be executed evey time either a new buy or sell order is placed by a customer
CREATE PROCEDURE new_order(@customer_id_n varchar (10), @share_id_n varchar(10), @share_count_n INTEGER, @per_share_price_n MONEY, @buy_or_sell_n char)
AS
BEGIN
	DECLARE @new_order_no INTEGER; --declaring a  varible to hold a new order number
	SELECT @new_order_no = MAX(order_no)+1 FROM dbo.orders; --generate a new order number as 1 more than the maximum order number in orders table
	DECLARE @curr_date_time DATETIME2;
	SELECT @curr_date_time=SYSDATETIME();
	INSERT INTO dbo.orders(order_no,order_date,customer_id,share_id,share_count,per_share_price,buy_or_sell)
		VALUES(@new_order_no,@curr_date_time,@customer_id_n, @share_id_n, @share_count_n, @per_share_price_n, @buy_or_sell_n);
	IF @buy_or_sell_n = 'b' THEN:
		INSERT INTO dbo.buyers(order_no, order_date,customer_id,share_id,share_count,per_share_price)
			VALUES(@new_order_no,@curr_date_time,@customer_id_n, @share_id_n, @share_count_n, @per_share_price_n);
		EXEC exe_buy_sell(@new_order_no,@curr_date_time,@customer_id_n, @share_id_n, @share_count_n, @per_share_price_n,@buy_or_sell_n);
	IF @buy_or_sell_n = 's' THEN:
		INSERT INTO dbo.sellers(order_no,order_date,customer_id,share_id,share_count,per_share_price)
			VALUES(@new_order_no,@curr_date_time,@customer_id_n, @share_id_n, @share_count_n, @per_share_price_n);
		EXEC exe_buy_sell(@new_order_no,@curr_date_time,@customer_id_n, @share_id_n, @share_count_n, @per_share_price_n,@buy_or_sell_n);
END
GO




CREATE PROCEDURE DEL_ORDER 
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
		per_share_price MONEY NOT NULL
	)
	IF EXISTS (SELECT order_no FROM dbo.seller WHERE order_no=@order_no_n) THEN:
		INSERT INTO #tmp_del VALUES(SELECT * FROM dbo.sellers WHERE order_no==@order_no_n); --to save time before delete, holding record in a temporary table
		SET @deletion_time=SYSDATETIME();
		DELETE FROM dbo.sellers WHERE order_no=@order_no_n;
		INSERT INTO dbo.deleted_orders(order_no,order_date,customer_id,share_id,share_count,per_share_price,deletion_date,buy_or_sell) 
			VALUES(SELECT *,@deletion_time,'s' FROM #tmp_del);
	IF EXISTS (SELECT order_no FROM dbo.buyers WHERE order_no=@order_no_n) THEN:
		INSERT INTO #tmp_del VALUES(SELECT * FROM dbo.buyers WHERE order_no==@order_no_n); --to save time before delete, holding record in a temporary table
		SET @deletion_time=SYSDATETIME();
		DELETE FROM dbo.buyers WHERE order_no=@order_no_n;
		INSERT INTO dbo.deleted_orders(order_no,order_date,customer_id,share_id,share_count,per_share_price,deletion_date,buy_or_sell) 
			VALUES (SELECT *, @deletion_time, 's' FROM #tmp_del);			
	DROP TABLE #tmp_del
END
Go */