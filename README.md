# STOCK_EXCHANGE_SQL
## Executes sale/purchase of stocks whenever a new order is initiated

-Two tables necessary for the project can be created as per the code at the bottom of the stock_exchange file.

-A sample orders.csv file holds some sample pre-existing orders. The first row contains the column headers. 
 order_no,	order_date,	customer_id,	share_id,	share_count,	per_share_price,	buy_or_sell

-Sample input query is shown at the top of the file.
  DECLARE @customer_id_n varchar(10) = <username>;
  DECLARE @share_id_n varchar(10) ='SH3' OR 'SH1' OR 'SH2'; --These are the current share id's currently present in the sample orders.csv file, but could be anything
  DECLARE @share_count_n INTEGER =<enter number of shares>;
  DECLARE @per_share_price_n money = <enter amount per share>;
  DECLARE @buy_or_sell_n char ='b' or 's'; --until here the variables are comming from executing the procedure 

-Two tables orders and executed_orders stored non-executed orders and executed orders respectively.

-Executed_orders table stores both fully/partially executed orders, and any deleted orders. exec_or_del column in the executed_orders table indicates whether that record was executed 'e', or deleted 'd'.

-Any time a new order comes in, a new order number is automatically generated based on the highest order number from the orders and executed_orders tables.

-Sysdatetime at the time the exe_buy_sell procedure starts becomes order_date.

-New order gets compared with existing orders in the orders table and executed if matched. 

-Any order that does not have a match at the moment gets stored in orders.

-A portion of an existing order that is not fully executed gets updated in the orders table.

-If an order is executed in parts, there will be multiple entries for that order number in executed_orders table with a timestamp in execution_date indicating when each portion was executed, with 'e' for exec_or_del column with the remaining portion of the shares to be bought/sold.

-Unexecuted portion of an order gets updated/saved in orders table.

-Any full/partial order still present in orders table can be deleted with the delete_order procedure.

-Any order number that is set to be deleted, gets checked for a match in orders table. If there is a match, that record gets removed from the orders table, and stored in the executed table with 'd' for exec_or_del column. The system time just before deletion from the orders table gets stored as execution_time in the executed_orders table.
