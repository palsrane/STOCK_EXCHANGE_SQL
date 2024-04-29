--Sample request. This is how the procedure gets called
DECLARE @customer_id_n varchar(10) = 'JSK';
DECLARE @share_id_n varchar(10) ='SH3';
DECLARE @share_count_n INTEGER =5;
DECLARE @per_share_price_n money = 8.00;
DECLARE @buy_or_sell_n char ='b'; --until here the variables are comming from executing the procedure

EXEC exe_buy_sell @customer_id_n, @share_id_n, @share_count_n, @per_share_price_n, @buy_or_sell_n
Go --Go breaks the page in sections

--This procedure gets called every time a client submits a buy/sell request
--This finishes any execution of possible orders that match this new request
CREATE OR ALTER PROCEDURE exe_buy_sell
	@customer_id_n varchar(10),
	@share_id_n varchar(10),
	@share_count_n INTEGER,
	@per_share_price_n money,
	@buy_or_sell_n char
AS
BEGIN	
	DECLARE @order_date_n DATETIME2=SYSDATETIME(); --The time that order came in
	DECLARE @order_no_n INTEGER; --generate a new order number as 1 more than the maximum order number in orders/executed_orders tables
	SELECT @order_no_n = MAX(order_no)+1 FROM 
		(SELECT order_no from dbo.orders UNION ALL SELECT order_no from dbo.executed_orders)O_N; 
	DECLARE @LookingForBuyerOrSeller CHAR;
	DECLARE @exec_or_del_n CHAR ='e';
	DECLARE @cnt_total INTEGER;
	DECLARE @cnt INTEGER = 1;
	DECLARE @order_no_per_row INTEGER;
	DECLARE @order_date_per_row DATETIME2;
	DECLARE @share_nums_per_row INTEGER;
	DECLARE @per_share_price_per_row MONEY;
	DECLARE @customer_id_per_row varchar(10);
	DECLARE @execution_time DATETIME2;
	DECLARE @sale_price MONEY;

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
		PRINT 'Pallavi You are here to BUY Shares Pallavi';
		SELECT @LookingForBuyerOrSeller ='s';
		INSERT INTO #tmp_buy_sell 			--temporary table share_id=@share_id_n and per_share_price<=@per_share_price_n ORDER BY per_share_price, order_date; cheapest seller on top
			SELECT ROW_NUMBER() OVER (ORDER BY per_share_price,order_date), --rows are ordered in the ascending share prices with lowest share prices on top
			order_no,order_date,customer_id,share_id,share_count,per_share_price 
			FROM dbo.orders 
			WHERE share_id=@share_id_n AND customer_id <> @customer_id_n AND per_share_price<=@per_share_price_n AND buy_or_sell = @LookingForBuyerOrSeller --looking for sellers willing to sell at offered or lower cost
			ORDER BY per_share_price,order_date;

	IF @buy_or_sell_n = 's'	
		PRINT 'Pallavi You are here to SELL Shares Pallavi';
		SELECT @LookingForBuyerOrSeller ='b';
		INSERT INTO #tmp_buy_sell 			--temporary table share_id=@share_id_n and per_share_price>=@per_share_price_n ORDER BY per_share_price, order_date; highest paying buyer on top
			SELECT ROW_NUMBER() OVER (ORDER BY per_share_price DESC,order_date),--rows are ordered in the descending share prices with highest share prices on top
			order_no,order_date,customer_id,share_id,share_count,per_share_price 
			FROM dbo.orders 
			WHERE share_id=@share_id_n AND customer_id <> @customer_id_n AND per_share_price>=@per_share_price_n AND buy_or_sell =  @LookingForBuyerOrSeller --looking for buyers willing to buy shares at offered or higher cost
			ORDER BY per_share_price DESC,order_date;

	SELECT @cnt_total = COUNT(*) FROM #tmp_buy_sell; --total number of buyers
	--PRINT @cnt_total
	IF @cnt_total =0 
		BEGIN
			PRINT CASE WHEN @buy_or_sell_n = 'b' THEN 'No matching purchase options available at this time' ELSE 'No buyers available at this time' END
			INSERT INTO dbo.orders(order_no, --Since no matching buyer or seller is available, add the order to pending order to orders table
								order_date,
								customer_id,
								share_id,
								share_count,
								per_share_price,
								buy_or_sell)
							VALUES (@order_no_n,
								@order_date_n,
								@customer_id_n,
								@share_id_n,
								@share_count_n,
								@per_share_price_n,
								@buy_or_sell_n);
		END
	IF @cnt_total>0
		BEGIN
			WHILE (@cnt_total>=@cnt AND @share_count_n>0) --@cnt=1 initially
			BEGIN
				SELECT @order_no_per_row=order_no, @order_date_per_row=order_date, @customer_id_per_row=customer_id, 
					@share_nums_per_row=share_count, @per_share_price_per_row=per_share_price
					FROM #tmp_buy_sell WHERE row_num=@cnt;
				--PRINT @order_no_per_row;
				--PRINT @order_date_per_row;
				--PRINT @customer_id_per_row;
				--PRINT @share_nums_per_row;
				--PRINT @per_share_price_per_row;

				IF @share_nums_per_row > @share_count_n --more shares are available in the current row that requested in the new order
				BEGIN
					SET @execution_time=SYSDATETIME();
					SET @share_nums_per_row = @share_nums_per_row - @share_count_n
					UPDATE dbo.orders SET share_count=@share_nums_per_row WHERE order_no=@order_no_per_row; 
					--update orders table to reflect the shares from the current row that were not processed
					INSERT INTO dbo.executed_orders( --Add to executed orders
								order_no,
								order_date,
								execution_date,
								customer_id,
								share_id,
								share_count,
								per_share_price,
								buy_or_sell,
								exec_or_del)
							VALUES (@order_no_n,	--the new order that got executed fully
								@order_date_n,
								@execution_time,
								@customer_id_n,
								@share_id_n,
								@share_count_n,
								@per_share_price_per_row,
								@buy_or_sell_n,
								@exec_or_del_n),
								(@order_no_per_row,	--and the Part of the record from the current row that got executed partially
								@order_date_per_row,
								@execution_time,
								@customer_id_per_row,
								@share_id_n,
								@share_count_n,
								@per_share_price_per_row,
								@LookingForBuyerOrSeller,
								@exec_or_del_n);
					SET @share_count_n=0 --All shares from new order were bought/sold
				END
				IF @share_nums_per_row <= @share_count_n
				BEGIN
					SET @execution_time=SYSDATETIME();
					SET @share_count_n = @share_count_n - @share_nums_per_row
					INSERT INTO dbo.executed_orders( --Add to ecexuted orders table
								order_no,
								order_date,
								execution_date,
								customer_id,
								share_id,
								share_count,
								per_share_price,
								buy_or_sell,
								exec_or_del)
							VALUES (@order_no_n, --the part of order that got executed
								@order_date_n,
								@execution_time,
								@customer_id_n,
								@share_id_n,
								@share_nums_per_row,
								@per_share_price_per_row,
								@buy_or_sell_n,
								@exec_or_del_n),
								(@order_no_per_row,	--the record from the current row that also got executed
								@order_date_per_row,
								@execution_time,
								@customer_id_per_row,
								@share_id_n,
								@share_nums_per_row,
								@per_share_price_per_row,
								@LookingForBuyerOrSeller,
								@exec_or_del_n);
					-- Delete the current row record from the orderstable as it is now completely executed
					DELETE FROM dbo.orders WHERE order_no=@order_no_per_row;
				END
				SET @cnt=@cnt+1;
			END
			IF @share_count_n > 0	--if not all shares from new order were bought/sold
				INSERT INTO dbo.orders( --then add to orders table
								order_no, 
								order_date,
								customer_id,
								share_id,
								share_count,
								per_share_price,
								buy_or_sell)
							VALUES (@order_no_n, --the part of the new order that did not get executed
								@order_date_n,
								@customer_id_n,
								@share_id_n,
								@share_count_n,
								@per_share_price_n,
								@buy_or_sell_n)
		END
	DROP TABLE #tmp_buy_sell; --dropping temporary table before the end of the procedure
END
GO

CREATE OR ALTER PROCEDURE del_order 
@order_no_n INTEGER 
AS
BEGIN
	DECLARE @deletion_time DATETIME2;
	DECLARE @num_orders INTEGER;
	DECLARE @exec_or_del_n CHAR = 'd'; --implies that these records were deleted and not executed
	CREATE TABLE #tmp_del(
		order_no INTEGER NOT NULL,
		order_date DATETIME2 NOT NULL,
		customer_id varchar(10) NOT NULL,
		share_id varchar(10) NOT NULL,
		share_count INTEGER NOT NULL,
		per_share_price MONEY NOT NULL,
		buy_or_sell CHAR NOT NULL
	)
	
	SELECT @num_orders=count(*) FROM dbo.orders WHERE order_no=@order_no_n
	IF (@num_orders = 1) 
	BEGIN
		INSERT INTO #tmp_del SELECT * FROM dbo.orders WHERE order_no=@order_no_n; --to save time before delete, holding record in a temporary table
		SET @deletion_time=SYSDATETIME();
		DELETE FROM dbo.orders WHERE order_no=@order_no_n;
		INSERT INTO dbo.executed_orders(order_no,order_date,customer_id,share_id,share_count,per_share_price,buy_or_sell,execution_date,exec_or_del) 
			SELECT *,@deletion_time,@exec_or_del_n FROM #tmp_del;
	END
	IF (@num_orders > 1)  PRINT 'Order number descripency. Multiple orders with same order number.'
	IF (@num_orders = 0) PRINT 'Check order number. No such peding order. Order might have been executed.'
	DROP TABLE #tmp_del
END
Go

--Tables needed for the stock exchange
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