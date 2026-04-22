-- =====================================================================
-- Customer PWA System Migration
-- Creates tables for cashback, withdrawals, and referral system
-- =====================================================================

-- 1. Add cashback_type and cashback_value columns to customers if not exist
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'customers' AND column_name = 'cashback_type') THEN
    ALTER TABLE customers ADD COLUMN cashback_type TEXT NOT NULL DEFAULT 'percentage';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'customers' AND column_name = 'cashback_value') THEN
    ALTER TABLE customers ADD COLUMN cashback_value DOUBLE PRECISION NOT NULL DEFAULT 0;
  END IF;
END $$;

-- 2. Cashback Config table
CREATE TABLE IF NOT EXISTS cashback_config (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  type TEXT NOT NULL DEFAULT 'percentage',
  value DOUBLE PRECISION NOT NULL DEFAULT 0,
  max_cashback DOUBLE PRECISION NOT NULL DEFAULT 0,
  min_order DOUBLE PRECISION NOT NULL DEFAULT 0,
  referral_bonus_type TEXT NOT NULL DEFAULT 'percentage',
  referral_bonus_value DOUBLE PRECISION NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Cashback Log table
CREATE TABLE IF NOT EXISTS cashback_log (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  transaction_id TEXT,
  withdrawal_id TEXT,
  type TEXT NOT NULL,
  amount DOUBLE PRECISION NOT NULL,
  balance_before DOUBLE PRECISION NOT NULL DEFAULT 0,
  balance_after DOUBLE PRECISION NOT NULL DEFAULT 0,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cashback_log_customer_id ON cashback_log(customer_id);
CREATE INDEX IF NOT EXISTS idx_cashback_log_transaction_id ON cashback_log(transaction_id);
CREATE INDEX IF NOT EXISTS idx_cashback_log_withdrawal_id ON cashback_log(withdrawal_id);
CREATE INDEX IF NOT EXISTS idx_cashback_log_type ON cashback_log(type);

-- 4. Cashback Withdrawal table
CREATE TABLE IF NOT EXISTS cashback_withdrawal (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  amount DOUBLE PRECISION NOT NULL,
  bank_name TEXT,
  account_no TEXT,
  account_holder TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  source_type TEXT,
  bank_account_id TEXT,
  cash_box_id TEXT,
  notes TEXT,
  processed_by_id TEXT,
  processed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cashback_withdrawal_customer_id ON cashback_withdrawal(customer_id);
CREATE INDEX IF NOT EXISTS idx_cashback_withdrawal_status ON cashback_withdrawal(status);

-- 5. Customer Referral table
CREATE TABLE IF NOT EXISTS customer_referral (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  referral_customer_id TEXT REFERENCES customers(id) ON DELETE SET NULL,
  referral_code TEXT,
  business_name TEXT,
  pic_name TEXT,
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  notes TEXT,
  follow_up_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_customer_referral_customer_id ON customer_referral(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_referral_referral_customer_id ON customer_referral(referral_customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_referral_status ON customer_referral(status);

-- 6. Atomic cashback RPC function
CREATE OR REPLACE FUNCTION atomic_add_cashback(p_customer_id TEXT, p_delta DOUBLE PRECISION)
RETURNS DOUBLE PRECISION AS $$
DECLARE
  new_balance DOUBLE PRECISION;
BEGIN
  UPDATE customers
  SET cashback_balance = cashback_balance + p_delta
  WHERE id = p_customer_id
  RETURNING cashback_balance INTO new_balance;
  RETURN new_balance;
END;
$$ LANGUAGE plpgsql;

-- 7. Atomic deduct cashback RPC function
CREATE OR REPLACE FUNCTION atomic_deduct_cashback(p_customer_id TEXT, p_delta DOUBLE PRECISION)
RETURNS DOUBLE PRECISION AS $$
DECLARE
  current_balance DOUBLE PRECISION;
  new_balance DOUBLE PRECISION;
BEGIN
  SELECT cashback_balance INTO current_balance FROM customers WHERE id = p_customer_id FOR UPDATE;
  IF current_balance < p_delta THEN
    RAISE EXCEPTION 'Cashback balance tidak mencukupi';
  END IF;
  UPDATE customers
  SET cashback_balance = cashback_balance - p_delta
  WHERE id = p_customer_id
  RETURNING cashback_balance INTO new_balance;
  RETURN new_balance;
END;
$$ LANGUAGE plpgsql;

-- 8. Seed default cashback config if none exists
INSERT INTO cashback_config (type, value, max_cashback, min_order, referral_bonus_type, referral_bonus_value, is_active)
SELECT 'percentage', 0, 0, 0, 'nominal', 0, true
WHERE NOT EXISTS (SELECT 1 FROM cashback_config WHERE is_active = true);
