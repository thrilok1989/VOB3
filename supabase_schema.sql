-- ============================================================
-- VOB3 — Complete Supabase SQL Schema
-- Run ALL statements in your Supabase SQL Editor (in order)
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. CANDLE DATA  (OHLCV price history cache)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS candle_data (
    id          bigserial        PRIMARY KEY,
    symbol      text             NOT NULL,
    exchange    text             NOT NULL,
    timeframe   text             NOT NULL,
    timestamp   bigint           NOT NULL,
    datetime    timestamptz      NOT NULL,
    open        double precision,
    high        double precision,
    low         double precision,
    close       double precision,
    volume      bigint,
    UNIQUE (symbol, exchange, timeframe, timestamp)
);
CREATE INDEX IF NOT EXISTS idx_candle_data_lookup
    ON candle_data (symbol, exchange, timeframe, datetime DESC);


-- ─────────────────────────────────────────────────────────────
-- 2. SIGNALS  (Trading signal log — CONFLUENCE, ITM, CIE, etc.)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS signals (
    id          bigserial        PRIMARY KEY,
    created_at  timestamptz      DEFAULT now(),
    signal_time timestamptz      NOT NULL,
    signal_type text             NOT NULL,  -- CONFLUENCE | ITM | CIE | CMCE | IOFCE
    direction   text,                        -- BUY | SELL
    source      text             NOT NULL,  -- human-readable analysis source name
    symbol      text             NOT NULL DEFAULT 'NIFTY',
    spot_price  double precision,
    confidence  text,
    entry       double precision,
    target      double precision,
    stop_loss   double precision,
    details     jsonb            DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_signals_time ON signals (signal_time DESC);


-- ─────────────────────────────────────────────────────────────
-- 3. OPTION HISTORY  (PCR / GEX / OI / IV time-series per index)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS option_history (
    id            bigserial   PRIMARY KEY,
    history_type  text        NOT NULL,
    recorded_at   timestamptz NOT NULL,
    data          jsonb       NOT NULL DEFAULT '{}'::jsonb,
    trade_date    date        NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (history_type, recorded_at)
);
CREATE INDEX IF NOT EXISTS idx_option_history_lookup
    ON option_history (history_type, trade_date, recorded_at DESC);


-- ─────────────────────────────────────────────────────────────
-- 4. USER PREFERENCES  (per-user app settings)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id         text        PRIMARY KEY,
    timeframe       text        DEFAULT '5',
    auto_refresh    boolean     DEFAULT true,
    days_back       integer     DEFAULT 1,
    pivot_settings  text        DEFAULT '{}',   -- JSON string
    pivot_proximity integer     DEFAULT 5,
    updated_at      timestamptz DEFAULT now()
);


-- ─────────────────────────────────────────────────────────────
-- 5. MARKET ANALYTICS  (daily OHLCV summary per symbol)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS market_analytics (
    id               bigserial        PRIMARY KEY,
    symbol           text             NOT NULL DEFAULT 'NIFTY',
    date             date             NOT NULL,
    day_high         double precision,
    day_low          double precision,
    day_open         double precision,
    day_close        double precision,
    total_volume     bigint,
    avg_price        double precision,
    price_change     double precision,
    price_change_pct double precision,
    UNIQUE (symbol, date)
);
CREATE INDEX IF NOT EXISTS idx_market_analytics_date
    ON market_analytics (symbol, date DESC);


-- ─────────────────────────────────────────────────────────────
-- 6. SPIKE HISTORY  (Options Spike Detector snapshots, last 300)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS spike_history (
    id              bigserial        PRIMARY KEY,
    timestamp       timestamptz      NOT NULL DEFAULT now(),
    atm_strike      double precision,
    spike_score     double precision,
    direction       text,
    signal          text,
    conditions_met  integer
);
CREATE INDEX IF NOT EXISTS idx_spike_history_ts
    ON spike_history (timestamp DESC);


-- ─────────────────────────────────────────────────────────────
-- 7. EXPIRY SPIKE HISTORY  (Expiry day spike snapshots, last 300)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS expiry_spike_history (
    id                  bigserial        PRIMARY KEY,
    timestamp           timestamptz      NOT NULL DEFAULT now(),
    atm_strike          double precision,
    dte                 integer,          -- days to expiry
    expiry_spike_score  double precision,
    signal              text,
    short_cover         boolean          DEFAULT false,
    long_unwind         boolean          DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_expiry_spike_ts
    ON expiry_spike_history (timestamp DESC);


-- ─────────────────────────────────────────────────────────────
-- 8. GAMMA SEQUENCE HISTORY  (Gamma sequence pattern snapshots, last 300)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gamma_sequence_history (
    id            bigserial   PRIMARY KEY,
    timestamp     timestamptz NOT NULL DEFAULT now(),
    atm_strike    double precision,
    pattern       text,
    direction     text,
    acceleration  boolean     DEFAULT false,
    bull_trap     boolean     DEFAULT false,
    bear_trap     boolean     DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_gamma_seq_ts
    ON gamma_sequence_history (timestamp DESC);


-- ─────────────────────────────────────────────────────────────
-- 9. PRO TRADER METRICS  (Unified Sentiment Engine snapshots)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pro_trader_metrics (
    timestamp       timestamptz      PRIMARY KEY,
    spot            double precision,
    atm_strike      integer,
    straddle_atm    double precision,
    iv_skew         double precision,
    pcr_oi          double precision,
    pcr_vol         double precision,
    pcr_chgoi       double precision,
    call_pressure   double precision,
    put_pressure    double precision,
    net_delta       double precision,
    net_gex         double precision,
    breakout_score  integer
);
CREATE INDEX IF NOT EXISTS idx_pro_trader_ts
    ON pro_trader_metrics (timestamp DESC);


-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- Enable RLS and grant anon/service_role access per table.
-- Adjust policies to match your authentication setup.
-- ============================================================

ALTER TABLE candle_data           ENABLE ROW LEVEL SECURITY;
ALTER TABLE signals               ENABLE ROW LEVEL SECURITY;
ALTER TABLE option_history        ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences      ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_analytics      ENABLE ROW LEVEL SECURITY;
ALTER TABLE spike_history         ENABLE ROW LEVEL SECURITY;
ALTER TABLE expiry_spike_history  ENABLE ROW LEVEL SECURITY;
ALTER TABLE gamma_sequence_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE pro_trader_metrics    ENABLE ROW LEVEL SECURITY;

-- Allow anon role full access (Streamlit Cloud uses anon key)
CREATE POLICY "anon_all_candle_data"            ON candle_data            FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_signals"                ON signals                FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_option_history"         ON option_history         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_user_preferences"       ON user_preferences       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_market_analytics"       ON market_analytics       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_spike_history"          ON spike_history          FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_expiry_spike_history"   ON expiry_spike_history   FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_gamma_seq_history"      ON gamma_sequence_history FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_pro_trader_metrics"     ON pro_trader_metrics     FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- CLEANUP / MAINTENANCE FUNCTIONS (optional helpers)
-- ============================================================

-- Auto-trim spike_history to 300 rows (call manually or via pg_cron)
CREATE OR REPLACE FUNCTION trim_spike_history() RETURNS void LANGUAGE sql AS $$
  DELETE FROM spike_history
  WHERE id NOT IN (
    SELECT id FROM spike_history ORDER BY id DESC LIMIT 300
  );
$$;

CREATE OR REPLACE FUNCTION trim_expiry_spike_history() RETURNS void LANGUAGE sql AS $$
  DELETE FROM expiry_spike_history
  WHERE id NOT IN (
    SELECT id FROM expiry_spike_history ORDER BY id DESC LIMIT 300
  );
$$;

CREATE OR REPLACE FUNCTION trim_gamma_sequence_history() RETURNS void LANGUAGE sql AS $$
  DELETE FROM gamma_sequence_history
  WHERE id NOT IN (
    SELECT id FROM gamma_sequence_history ORDER BY id DESC LIMIT 300
  );
$$;

-- Delete option_history older than 3 days (matches app's clear_old_option_history)
CREATE OR REPLACE FUNCTION clear_old_option_history(days_old integer DEFAULT 3)
RETURNS void LANGUAGE sql AS $$
  DELETE FROM option_history
  WHERE trade_date < (CURRENT_DATE - days_old * INTERVAL '1 day')::date;
$$;
