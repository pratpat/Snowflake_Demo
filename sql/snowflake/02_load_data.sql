-- =============================================================================
-- Load demo CSVs into the Iceberg tables (which write Parquet to OneLake).
-- Run as DATA_ENGINEER after 01_iceberg_schema_onelake.sql has been executed.
--
-- Pre-step from a SnowSQL prompt on your workstation:
--   snowsql -a <account> -u <user> -r DATA_ENGINEER -w <warehouse> \
--           -d CAPITAL_MARKETS -s PUBLIC -f 02_load_data.sql
--
-- The PUT commands assume CSVs are at: C:\Users\ppatwari\fabric-capital-markets-demo\data\
-- (or your local clone path). Adjust if needed.
-- =============================================================================

USE ROLE DATA_ENGINEER;
USE SCHEMA CAPITAL_MARKETS.PUBLIC;

-- 1. Internal stage + file format
CREATE OR REPLACE FILE FORMAT capmkts_csv
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  EMPTY_FIELD_AS_NULL = TRUE
  NULL_IF = ('', 'NULL');

CREATE OR REPLACE STAGE capmkts_stage FILE_FORMAT = capmkts_csv;

-- 2. Upload CSVs (run from SnowSQL; remove "file://" prefix on macOS/Linux)
PUT file://C:/Users/ppatwari/fabric-capital-markets-demo/data/securities.csv    @capmkts_stage AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT file://C:/Users/ppatwari/fabric-capital-markets-demo/data/clients.csv       @capmkts_stage AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT file://C:/Users/ppatwari/fabric-capital-markets-demo/data/accounts.csv      @capmkts_stage AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT file://C:/Users/ppatwari/fabric-capital-markets-demo/data/traders.csv       @capmkts_stage AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT file://C:/Users/ppatwari/fabric-capital-markets-demo/data/eod_prices.csv    @capmkts_stage AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT file://C:/Users/ppatwari/fabric-capital-markets-demo/data/trades.csv        @capmkts_stage AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT file://C:/Users/ppatwari/fabric-capital-markets-demo/data/market_quotes.csv @capmkts_stage AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
PUT file://C:/Users/ppatwari/fabric-capital-markets-demo/data/positions.csv     @capmkts_stage AUTO_COMPRESS=TRUE OVERWRITE=TRUE;

LIST @capmkts_stage;

-- 3. Load — column order matches the CSV headers produced by generate_data.py
COPY INTO securities    FROM @capmkts_stage/securities.csv.gz    FILE_FORMAT=(FORMAT_NAME=capmkts_csv);
COPY INTO clients       FROM @capmkts_stage/clients.csv.gz       FILE_FORMAT=(FORMAT_NAME=capmkts_csv);
COPY INTO accounts      FROM @capmkts_stage/accounts.csv.gz      FILE_FORMAT=(FORMAT_NAME=capmkts_csv);
COPY INTO traders       FROM @capmkts_stage/traders.csv.gz       FILE_FORMAT=(FORMAT_NAME=capmkts_csv);
COPY INTO eod_prices    FROM @capmkts_stage/eod_prices.csv.gz    FILE_FORMAT=(FORMAT_NAME=capmkts_csv);
COPY INTO trades        FROM @capmkts_stage/trades.csv.gz        FILE_FORMAT=(FORMAT_NAME=capmkts_csv);
COPY INTO market_quotes FROM @capmkts_stage/market_quotes.csv.gz FILE_FORMAT=(FORMAT_NAME=capmkts_csv);
COPY INTO positions     FROM @capmkts_stage/positions.csv.gz     FILE_FORMAT=(FORMAT_NAME=capmkts_csv);

-- 4. Row counts
SELECT 'securities'    AS table_name, COUNT(*) AS rows FROM securities
UNION ALL SELECT 'clients',       COUNT(*) FROM clients
UNION ALL SELECT 'accounts',      COUNT(*) FROM accounts
UNION ALL SELECT 'traders',       COUNT(*) FROM traders
UNION ALL SELECT 'eod_prices',    COUNT(*) FROM eod_prices
UNION ALL SELECT 'trades',        COUNT(*) FROM trades
UNION ALL SELECT 'market_quotes', COUNT(*) FROM market_quotes
UNION ALL SELECT 'positions',     COUNT(*) FROM positions
ORDER BY table_name;

-- 5. Quick sanity query — top traded sectors
SELECT s.sector,
       COUNT(*)              AS trade_count,
       ROUND(SUM(t.notional),2) AS total_notional_usd
FROM   trades t
JOIN   securities s ON s.symbol = t.symbol
GROUP  BY s.sector
ORDER  BY total_notional_usd DESC;
