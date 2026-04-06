-- ============================================================
-- VOB3 — Complete Supabase SQL Schema  (migration-safe)
-- Run ALL statements in your Supabase SQL Editor (in order).
-- Safe to re-run: uses IF NOT EXISTS / IF NOT EXISTS guards.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. CANDLE DATA  (OHLCV price history cache)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS candle_data (
    id          bigserial        PRIMARY KEY,
    symbol      text             NOT NULL,
    exchange    text             NOT NULL,
    timeframe   text             NOT NULL,
    timestamp   bigint           NOT NULL DEFAULT 0,
    datetime    timestamptz      NOT NULL DEFAULT now(),
    open        double precision,
    high        double precision,
    low         double precision,
    close       double precision,
    volume      bigint
);

-- Migration: add missing columns to existing candle_data table
ALTER TABLE candle_data ADD COLUMN IF NOT EXISTS timestamp bigint NOT NULL DEFAULT 0;
ALTER TABLE candle_data ADD COLUMN IF NOT EXISTS datetime  timestamptz NOT NULL DEFAULT now();
ALTER TABLE candle_data ADD COLUMN IF NOT EXISTS open      double precision;
ALTER TABLE candle_data ADD COLUMN IF NOT EXISTS high      double precision;
ALTER TABLE candle_data ADD COLUMN IF NOT EXISTS low       double precision;
ALTER TABLE candle_data ADD COLUMN IF NOT EXISTS close     double precision;
ALTER TABLE candle_data ADD COLUMN IF NOT EXISTS volume    bigint;

-- Add unique constraint if missing (ignore error if already exists)
DO $$ BEGIN
  ALTER TABLE candle_data ADD CONSTRAINT candle_data_symbol_exchange_timeframe_timestamp_key
    UNIQUE (symbol, exchange, timeframe, timestamp);
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_candle_data_lookup
    ON candle_data (symbol, exchange, timeframe, datetime DESC);


-- ─────────────────────────────────────────────────────────────
-- 2. SIGNALS  (Trading signal log — CONFLUENCE, ITM, CIE, etc.)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS signals (
    id          bigserial        PRIMARY KEY,
    created_at  timestamptz      DEFAULT now(),
    signal_time timestamptz      NOT NULL DEFAULT now(),
    signal_type text             NOT NULL DEFAULT '',
    direction   text,
    source      text             NOT NULL DEFAULT '',
    symbol      text             NOT NULL DEFAULT 'NIFTY',
    spot_price  double precision,
    confidence  text,
    entry       double precision,
    target      double precision,
    stop_loss   double precision,
    details     jsonb            DEFAULT '{}'::jsonb
);

-- Migration: add missing columns
ALTER TABLE signals ADD COLUMN IF NOT EXISTS created_at  timestamptz DEFAULT now();
ALTER TABLE signals ADD COLUMN IF NOT EXISTS signal_time timestamptz NOT NULL DEFAULT now();
ALTER TABLE signals ADD COLUMN IF NOT EXISTS signal_type text NOT NULL DEFAULT '';
ALTER TABLE signals ADD COLUMN IF NOT EXISTS direction   text;
ALTER TABLE signals ADD COLUMN IF NOT EXISTS source      text NOT NULL DEFAULT '';
ALTER TABLE signals ADD COLUMN IF NOT EXISTS symbol      text NOT NULL DEFAULT 'NIFTY';
ALTER TABLE signals ADD COLUMN IF NOT EXISTS spot_price  double precision;
ALTER TABLE signals ADD COLUMN IF NOT EXISTS confidence  text;
ALTER TABLE signals ADD COLUMN IF NOT EXISTS entry       double precision;
ALTER TABLE signals ADD COLUMN IF NOT EXISTS target      double precision;
ALTER TABLE signals ADD COLUMN IF NOT EXISTS stop_loss   double precision;
ALTER TABLE signals ADD COLUMN IF NOT EXISTS details     jsonb DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_signals_time ON signals (signal_time DESC);


-- ─────────────────────────────────────────────────────────────
-- 3. OPTION HISTORY  (PCR / GEX / OI / IV time-series per index)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS option_history (
    id            bigserial   PRIMARY KEY,
    history_type  text        NOT NULL DEFAULT '',
    recorded_at   timestamptz NOT NULL DEFAULT now(),
    data          jsonb       NOT NULL DEFAULT '{}'::jsonb,
    trade_date    date        NOT NULL DEFAULT CURRENT_DATE
);

-- Migration: add missing columns
ALTER TABLE option_history ADD COLUMN IF NOT EXISTS history_type text NOT NULL DEFAULT '';
ALTER TABLE option_history ADD COLUMN IF NOT EXISTS recorded_at  timestamptz NOT NULL DEFAULT now();
ALTER TABLE option_history ADD COLUMN IF NOT EXISTS data         jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE option_history ADD COLUMN IF NOT EXISTS trade_date   date NOT NULL DEFAULT CURRENT_DATE;

-- Add unique constraint if missing
DO $$ BEGIN
  ALTER TABLE option_history ADD CONSTRAINT option_history_history_type_recorded_at_key
    UNIQUE (history_type, recorded_at);
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

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
    pivot_settings  text        DEFAULT '{}',
    pivot_proximity integer     DEFAULT 5,
    updated_at      timestamptz DEFAULT now()
);

-- Migration: add missing columns
ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS timeframe       text DEFAULT '5';
ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS auto_refresh    boolean DEFAULT true;
ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS days_back       integer DEFAULT 1;
ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS pivot_settings  text DEFAULT '{}';
ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS pivot_proximity integer DEFAULT 5;
ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS updated_at      timestamptz DEFAULT now();


-- ─────────────────────────────────────────────────────────────
-- 5. MARKET ANALYTICS  (daily OHLCV summary per symbol)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS market_analytics (
    id               bigserial        PRIMARY KEY,
    symbol           text             NOT NULL DEFAULT 'NIFTY',
    date             date             NOT NULL DEFAULT CURRENT_DATE,
    day_high         double precision,
    day_low          double precision,
    day_open         double precision,
    day_close        double precision,
    total_volume     bigint,
    avg_price        double precision,
    price_change     double precision,
    price_change_pct double precision
);

-- Migration: add missing columns
ALTER TABLE market_analytics ADD COLUMN IF NOT EXISTS symbol           text NOT NULL DEFAULT 'NIFTY';
ALTER TABLE market_analytics ADD COLUMN IF NOT EXISTS date             date NOT NULL DEFAULT CURRENT_DATE;
ALTER TABLE market_analytics ADD COLUMN IF NOT EXISTS day_high         double precision;
ALTER TABLE market_analytics ADD COLUMN IF NOT EXISTS day_low          double precision;
ALTER TABLE market_analytics ADD COLUMN IF NOT EXISTS day_open         double precision;
ALTER TABLE market_analytics ADD COLUMN IF NOT EXISTS day_close        double precision;
ALTER TABLE market_analytics ADD COLUMN IF NOT EXISTS total_volume     bigint;
ALTER TABLE market_analytics ADD COLUMN IF NOT EXISTS avg_price        double precision;
ALTER TABLE market_analytics ADD COLUMN IF NOT EXISTS price_change     double precision;
ALTER TABLE market_analytics ADD COLUMN IF NOT EXISTS price_change_pct double precision;

-- Add unique constraint if missing
DO $$ BEGIN
  ALTER TABLE market_analytics ADD CONSTRAINT market_analytics_symbol_date_key UNIQUE (symbol, date);
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_market_analytics_date
    ON market_analytics (symbol, date DESC);


-- ─────────────────────────────────────────────────────────────
-- 6. SPIKE HISTORY  (Options Spike Detector snapshots, last 300)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS spike_history (
    id              bigserial        PRIMARY KEY,
    "timestamp"     timestamptz      NOT NULL DEFAULT now(),
    atm_strike      double precision,
    spike_score     double precision,
    direction       text,
    signal          text,
    conditions_met  integer
);

-- Migration: add missing columns
ALTER TABLE spike_history ADD COLUMN IF NOT EXISTS "timestamp"    timestamptz NOT NULL DEFAULT now();
ALTER TABLE spike_history ADD COLUMN IF NOT EXISTS atm_strike     double precision;
ALTER TABLE spike_history ADD COLUMN IF NOT EXISTS spike_score    double precision;
ALTER TABLE spike_history ADD COLUMN IF NOT EXISTS direction      text;
ALTER TABLE spike_history ADD COLUMN IF NOT EXISTS signal         text;
ALTER TABLE spike_history ADD COLUMN IF NOT EXISTS conditions_met integer;

CREATE INDEX IF NOT EXISTS idx_spike_history_ts ON spike_history ("timestamp" DESC);


-- ─────────────────────────────────────────────────────────────
-- 7. EXPIRY SPIKE HISTORY  (Expiry day spike snapshots, last 300)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS expiry_spike_history (
    id                  bigserial        PRIMARY KEY,
    "timestamp"         timestamptz      NOT NULL DEFAULT now(),
    atm_strike          double precision,
    dte                 integer,
    expiry_spike_score  double precision,
    signal              text,
    short_cover         boolean          DEFAULT false,
    long_unwind         boolean          DEFAULT false
);

-- Migration: add missing columns
ALTER TABLE expiry_spike_history ADD COLUMN IF NOT EXISTS "timestamp"        timestamptz NOT NULL DEFAULT now();
ALTER TABLE expiry_spike_history ADD COLUMN IF NOT EXISTS atm_strike         double precision;
ALTER TABLE expiry_spike_history ADD COLUMN IF NOT EXISTS dte                integer;
ALTER TABLE expiry_spike_history ADD COLUMN IF NOT EXISTS expiry_spike_score double precision;
ALTER TABLE expiry_spike_history ADD COLUMN IF NOT EXISTS signal             text;
ALTER TABLE expiry_spike_history ADD COLUMN IF NOT EXISTS short_cover        boolean DEFAULT false;
ALTER TABLE expiry_spike_history ADD COLUMN IF NOT EXISTS long_unwind        boolean DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_expiry_spike_ts ON expiry_spike_history ("timestamp" DESC);


-- ─────────────────────────────────────────────────────────────
-- 8. GAMMA SEQUENCE HISTORY  (Gamma sequence pattern snapshots, last 300)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gamma_sequence_history (
    id            bigserial   PRIMARY KEY,
    "timestamp"   timestamptz NOT NULL DEFAULT now(),
    atm_strike    double precision,
    pattern       text,
    direction     text,
    acceleration  boolean     DEFAULT false,
    bull_trap     boolean     DEFAULT false,
    bear_trap     boolean     DEFAULT false
);

-- Migration: add missing columns
ALTER TABLE gamma_sequence_history ADD COLUMN IF NOT EXISTS "timestamp"  timestamptz NOT NULL DEFAULT now();
ALTER TABLE gamma_sequence_history ADD COLUMN IF NOT EXISTS atm_strike   double precision;
ALTER TABLE gamma_sequence_history ADD COLUMN IF NOT EXISTS pattern      text;
ALTER TABLE gamma_sequence_history ADD COLUMN IF NOT EXISTS direction    text;
ALTER TABLE gamma_sequence_history ADD COLUMN IF NOT EXISTS acceleration boolean DEFAULT false;
ALTER TABLE gamma_sequence_history ADD COLUMN IF NOT EXISTS bull_trap    boolean DEFAULT false;
ALTER TABLE gamma_sequence_history ADD COLUMN IF NOT EXISTS bear_trap    boolean DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_gamma_seq_ts ON gamma_sequence_history ("timestamp" DESC);


-- ─────────────────────────────────────────────────────────────
-- 9. PRO TRADER METRICS  (Unified Sentiment Engine snapshots)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pro_trader_metrics (
    id              bigserial        PRIMARY KEY,
    "timestamp"     timestamptz      NOT NULL DEFAULT now(),
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

-- Migration: add missing columns
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS "timestamp"    timestamptz NOT NULL DEFAULT now();
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS spot           double precision;
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS atm_strike     integer;
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS straddle_atm   double precision;
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS iv_skew        double precision;
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS pcr_oi         double precision;
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS pcr_vol        double precision;
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS pcr_chgoi      double precision;
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS call_pressure  double precision;
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS put_pressure   double precision;
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS net_delta      double precision;
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS net_gex        double precision;
ALTER TABLE pro_trader_metrics ADD COLUMN IF NOT EXISTS breakout_score integer;

-- Add unique constraint on timestamp for upsert
DO $$ BEGIN
  ALTER TABLE pro_trader_metrics ADD CONSTRAINT pro_trader_metrics_timestamp_key UNIQUE ("timestamp");
EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_pro_trader_ts ON pro_trader_metrics ("timestamp" DESC);


-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- Safe to re-run — ALTER TABLE ENABLE RLS is idempotent.
-- ============================================================

ALTER TABLE candle_data            ENABLE ROW LEVEL SECURITY;
ALTER TABLE signals                ENABLE ROW LEVEL SECURITY;
ALTER TABLE option_history         ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences       ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_analytics       ENABLE ROW LEVEL SECURITY;
ALTER TABLE spike_history          ENABLE ROW LEVEL SECURITY;
ALTER TABLE expiry_spike_history   ENABLE ROW LEVEL SECURITY;
ALTER TABLE gamma_sequence_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE pro_trader_metrics     ENABLE ROW LEVEL SECURITY;

-- Allow anon role full access (Streamlit Cloud uses anon key).
-- DROP + CREATE so re-running this script doesn't fail on duplicate policy.
DO $$ BEGIN DROP POLICY IF EXISTS "anon_all_candle_data"           ON candle_data;            EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "anon_all_signals"               ON signals;                EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "anon_all_option_history"        ON option_history;         EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "anon_all_user_preferences"      ON user_preferences;       EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "anon_all_market_analytics"      ON market_analytics;       EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "anon_all_spike_history"         ON spike_history;          EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "anon_all_expiry_spike_history"  ON expiry_spike_history;   EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "anon_all_gamma_seq_history"     ON gamma_sequence_history; EXCEPTION WHEN undefined_object THEN NULL; END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "anon_all_pro_trader_metrics"    ON pro_trader_metrics;     EXCEPTION WHEN undefined_object THEN NULL; END $$;

CREATE POLICY "anon_all_candle_data"           ON candle_data            FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_signals"               ON signals                FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_option_history"        ON option_history         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_user_preferences"      ON user_preferences       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_market_analytics"      ON market_analytics       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_spike_history"         ON spike_history          FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_expiry_spike_history"  ON expiry_spike_history   FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_gamma_seq_history"     ON gamma_sequence_history FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_pro_trader_metrics"    ON pro_trader_metrics     FOR ALL TO anon USING (true) WITH CHECK (true);


-- ============================================================
-- CLEANUP / MAINTENANCE FUNCTIONS  (optional, safe to call manually)
-- ============================================================

CREATE OR REPLACE FUNCTION trim_spike_history() RETURNS void LANGUAGE sql AS $$
  DELETE FROM spike_history WHERE id NOT IN (SELECT id FROM spike_history ORDER BY id DESC LIMIT 300);
$$;

CREATE OR REPLACE FUNCTION trim_expiry_spike_history() RETURNS void LANGUAGE sql AS $$
  DELETE FROM expiry_spike_history WHERE id NOT IN (SELECT id FROM expiry_spike_history ORDER BY id DESC LIMIT 300);
$$;

CREATE OR REPLACE FUNCTION trim_gamma_sequence_history() RETURNS void LANGUAGE sql AS $$
  DELETE FROM gamma_sequence_history WHERE id NOT IN (SELECT id FROM gamma_sequence_history ORDER BY id DESC LIMIT 300);
$$;

CREATE OR REPLACE FUNCTION clear_old_option_history(days_old integer DEFAULT 3)
RETURNS void LANGUAGE sql AS $$
  DELETE FROM option_history WHERE trade_date < (CURRENT_DATE - days_old * INTERVAL '1 day')::date;
$$;
