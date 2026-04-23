-- =============================================================================
-- Snowflake-managed Iceberg tables writing to Microsoft Fabric OneLake
-- Demo: Capital Markets / Equity Trading
--
-- Run order:
--   1. Section A (one-time setup) as ACCOUNTADMIN
--   2. Section B (DDL) as a working role (e.g., DATA_ENGINEER)
--   3. Use 02_load_data.sql to PUT + COPY the demo CSVs
--
-- Replace placeholders:
--   <workspace>       Fabric workspace name (URL-encoded if it has spaces)
--   <lakehouse>       Lakehouse name (without .Lakehouse suffix)
--   <entra-tenant-id> Microsoft Entra tenant GUID
--   <warehouse>       Snowflake virtual warehouse for the demo
-- =============================================================================

-- =====================================================================
-- A. ONE-TIME SETUP  (ACCOUNTADMIN)
-- =====================================================================
USE ROLE ACCOUNTADMIN;

-- A.1  Working warehouse + role + DB
CREATE WAREHOUSE IF NOT EXISTS <warehouse>
  WITH WAREHOUSE_SIZE='X-SMALL' AUTO_SUSPEND=60 AUTO_RESUME=TRUE;

CREATE DATABASE IF NOT EXISTS CAPITAL_MARKETS;
CREATE SCHEMA   IF NOT EXISTS CAPITAL_MARKETS.PUBLIC;

CREATE ROLE IF NOT EXISTS DATA_ENGINEER;
GRANT USAGE  ON WAREHOUSE <warehouse>             TO ROLE DATA_ENGINEER;
GRANT USAGE  ON DATABASE  CAPITAL_MARKETS         TO ROLE DATA_ENGINEER;
GRANT USAGE  ON SCHEMA    CAPITAL_MARKETS.PUBLIC  TO ROLE DATA_ENGINEER;
GRANT CREATE TABLE, CREATE STAGE, CREATE EXTERNAL VOLUME, CREATE VIEW
      ON SCHEMA CAPITAL_MARKETS.PUBLIC TO ROLE DATA_ENGINEER;
GRANT ROLE DATA_ENGINEER TO USER <your_user>;

-- A.2  EXTERNAL VOLUME pointing at Fabric OneLake (ADLS-Gen2 compatible endpoint)
--      Format:  azure://onelake.dfs.fabric.microsoft.com/<workspace>/<lakehouse>.Lakehouse/Files/iceberg/
CREATE OR REPLACE EXTERNAL VOLUME onelake_capmkts
  STORAGE_LOCATIONS = (
    (
      NAME             = 'onelake'
      STORAGE_PROVIDER = 'AZURE'
      STORAGE_BASE_URL = 'azure://onelake.dfs.fabric.microsoft.com/<workspace>/<lakehouse>.Lakehouse/Files/iceberg/'
      AZURE_TENANT_ID  = '<entra-tenant-id>'
    )
  )
  ALLOW_WRITES = TRUE;

-- A.3  Authorize Snowflake's Entra app on OneLake
--      DESC returns AZURE_CONSENT_URL and AZURE_MULTI_TENANT_APP_NAME.
DESC EXTERNAL VOLUME onelake_capmkts;
--   1) Open the AZURE_CONSENT_URL in a browser; grant tenant-wide consent.
--   2) In the Fabric workspace, add the Snowflake Entra app as a workspace member
--      with role 'Contributor' (so it can write Iceberg files into Files/iceberg/).
--      Or grant it 'Storage Blob Data Contributor' on the underlying OneLake path
--      via Azure RBAC if your tenant supports it.

-- A.4  Sanity check
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('onelake_capmkts');


-- =====================================================================
-- B. ICEBERG TABLE DDL  (run as DATA_ENGINEER)
-- =====================================================================
USE ROLE DATA_ENGINEER;
USE WAREHOUSE <warehouse>;
USE SCHEMA CAPITAL_MARKETS.PUBLIC;

-- ---------- DIMENSIONS ----------

CREATE OR REPLACE ICEBERG TABLE securities (
    symbol      STRING NOT NULL,
    isin        STRING,
    cusip       STRING,
    name        STRING,
    sector      STRING,
    industry    STRING,
    exchange    STRING,
    currency    STRING,
    country     STRING
)
  CATALOG         = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'onelake_capmkts'
  BASE_LOCATION   = 'securities/'
  COMMENT = 'Master list of tradable instruments';

CREATE OR REPLACE ICEBERG TABLE clients (
    client_id        STRING NOT NULL,
    name             STRING,
    client_type      STRING,                   -- INSTITUTIONAL / RETAIL / HEDGE_FUND / PENSION / SOVEREIGN
    country          STRING,
    kyc_tier         STRING,                   -- TIER_1..TIER_3
    risk_profile     STRING,                   -- CONSERVATIVE / MODERATE / AGGRESSIVE
    aum_usd          NUMBER(20,2),
    onboarded_date   DATE
)
  CATALOG='SNOWFLAKE' EXTERNAL_VOLUME='onelake_capmkts' BASE_LOCATION='clients/'
  COMMENT='Counterparties (institutional & retail)';

CREATE OR REPLACE ICEBERG TABLE accounts (
    account_id     STRING NOT NULL,
    client_id      STRING NOT NULL,
    account_type   STRING,                     -- CASH / MARGIN / PRIME_BROKERAGE / CUSTODY
    base_currency  STRING,
    opened_date    DATE,
    status         STRING                      -- ACTIVE / CLOSED / FROZEN
)
  CATALOG='SNOWFLAKE' EXTERNAL_VOLUME='onelake_capmkts' BASE_LOCATION='accounts/'
  COMMENT='Brokerage / custody accounts';

CREATE OR REPLACE ICEBERG TABLE traders (
    trader_id  STRING NOT NULL,
    name       STRING,
    desk       STRING,                         -- EQUITY_CASH / PROGRAM_TRADING / ETF / DERIVATIVES / QUANT
    region     STRING                          -- AMER / EMEA / APAC
)
  CATALOG='SNOWFLAKE' EXTERNAL_VOLUME='onelake_capmkts' BASE_LOCATION='traders/'
  COMMENT='Internal trading-desk personnel';

-- ---------- FACTS ----------

CREATE OR REPLACE ICEBERG TABLE eod_prices (
    symbol      STRING NOT NULL,
    trade_date  DATE   NOT NULL,
    open        NUMBER(18,4),
    high        NUMBER(18,4),
    low         NUMBER(18,4),
    close       NUMBER(18,4),
    volume      NUMBER(20,0),
    adj_close   NUMBER(18,4)
)
  CATALOG='SNOWFLAKE' EXTERNAL_VOLUME='onelake_capmkts' BASE_LOCATION='eod_prices/'
  CLUSTER BY (symbol, trade_date)
  COMMENT='Daily OHLCV';

CREATE OR REPLACE ICEBERG TABLE trades (
    trade_id     STRING        NOT NULL,
    trade_ts     TIMESTAMP_NTZ NOT NULL,
    symbol       STRING        NOT NULL,
    account_id   STRING        NOT NULL,
    trader_id    STRING        NOT NULL,
    side         STRING,                       -- BUY / SELL
    quantity     NUMBER(20,0),
    price        NUMBER(18,4),
    notional     NUMBER(22,2),
    venue        STRING,
    order_type   STRING,                       -- MARKET / LIMIT / STOP / STOP_LIMIT
    status       STRING                        -- FILLED / PARTIAL / CANCELLED
)
  CATALOG='SNOWFLAKE' EXTERNAL_VOLUME='onelake_capmkts' BASE_LOCATION='trades/'
  CLUSTER BY (DATE(trade_ts), symbol)
  COMMENT='Executed equity trades';

CREATE OR REPLACE ICEBERG TABLE market_quotes (
    symbol     STRING        NOT NULL,
    quote_ts   TIMESTAMP_NTZ NOT NULL,
    bid        NUMBER(18,4),
    ask        NUMBER(18,4),
    bid_size   NUMBER(20,0),
    ask_size   NUMBER(20,0),
    venue      STRING
)
  CATALOG='SNOWFLAKE' EXTERNAL_VOLUME='onelake_capmkts' BASE_LOCATION='market_quotes/'
  CLUSTER BY (DATE(quote_ts), symbol)
  COMMENT='Intraday bid/ask quotes (last 5 trading days in demo)';

CREATE OR REPLACE ICEBERG TABLE positions (
    as_of_date          DATE   NOT NULL,
    account_id          STRING NOT NULL,
    symbol              STRING NOT NULL,
    quantity            NUMBER(20,0),
    avg_cost            NUMBER(18,4),
    market_value_usd    NUMBER(22,2),
    unrealized_pnl_usd  NUMBER(22,2)
)
  CATALOG='SNOWFLAKE' EXTERNAL_VOLUME='onelake_capmkts' BASE_LOCATION='positions/'
  CLUSTER BY (as_of_date, account_id)
  COMMENT='Snapshot of holdings per account';

-- ---------- INFORMATIONAL CONSTRAINTS (PK/FK) ----------
-- Iceberg tables don't enforce constraints, but RELY hints help Fabric IQ
-- and BI tools auto-discover relationships.

ALTER ICEBERG TABLE securities    ADD CONSTRAINT pk_securities    PRIMARY KEY (symbol)                        RELY;
ALTER ICEBERG TABLE clients       ADD CONSTRAINT pk_clients       PRIMARY KEY (client_id)                     RELY;
ALTER ICEBERG TABLE accounts      ADD CONSTRAINT pk_accounts      PRIMARY KEY (account_id)                    RELY;
ALTER ICEBERG TABLE traders       ADD CONSTRAINT pk_traders       PRIMARY KEY (trader_id)                     RELY;
ALTER ICEBERG TABLE trades        ADD CONSTRAINT pk_trades        PRIMARY KEY (trade_id)                      RELY;
ALTER ICEBERG TABLE eod_prices    ADD CONSTRAINT pk_eod           PRIMARY KEY (symbol, trade_date)            RELY;
ALTER ICEBERG TABLE positions     ADD CONSTRAINT pk_positions     PRIMARY KEY (as_of_date, account_id, symbol) RELY;

ALTER ICEBERG TABLE accounts      ADD CONSTRAINT fk_acc_client    FOREIGN KEY (client_id)  REFERENCES clients(client_id)    RELY;
ALTER ICEBERG TABLE trades        ADD CONSTRAINT fk_trd_acc       FOREIGN KEY (account_id) REFERENCES accounts(account_id)  RELY;
ALTER ICEBERG TABLE trades        ADD CONSTRAINT fk_trd_sym       FOREIGN KEY (symbol)     REFERENCES securities(symbol)    RELY;
ALTER ICEBERG TABLE trades        ADD CONSTRAINT fk_trd_trader    FOREIGN KEY (trader_id)  REFERENCES traders(trader_id)    RELY;
ALTER ICEBERG TABLE eod_prices    ADD CONSTRAINT fk_eod_sym       FOREIGN KEY (symbol)     REFERENCES securities(symbol)    RELY;
ALTER ICEBERG TABLE market_quotes ADD CONSTRAINT fk_mq_sym        FOREIGN KEY (symbol)     REFERENCES securities(symbol)    RELY;
ALTER ICEBERG TABLE positions     ADD CONSTRAINT fk_pos_acc       FOREIGN KEY (account_id) REFERENCES accounts(account_id)  RELY;
ALTER ICEBERG TABLE positions     ADD CONSTRAINT fk_pos_sym       FOREIGN KEY (symbol)     REFERENCES securities(symbol)    RELY;

-- =====================================================================
-- VERIFY
-- =====================================================================
SHOW ICEBERG TABLES IN SCHEMA CAPITAL_MARKETS.PUBLIC;
