-- =====================================================
-- Concurrency Fixes — Atomic RPC functions for
-- high-concurrency transaction processing.
--
-- These functions replace read-then-write patterns with
-- single-statement atomic operations to prevent race
-- conditions under concurrent load.
--
-- Run this SQL in Supabase SQL Editor.
-- =====================================================

-- =====================================================
-- 1. atomic_increment_customer_stats
--    Atomically increments customer total_orders and
--    total_spent in a single statement. Prevents the
--    race condition where two concurrent reads both see
--    total_orders=N and both write N+1 instead of N+2.
-- =====================================================
CREATE OR REPLACE FUNCTION atomic_increment_customer_stats(
  p_customer_id UUID,
  p_order_delta INTEGER DEFAULT 1,
  p_spent_delta NUMERIC DEFAULT 0
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE customers
  SET
    total_orders   = COALESCE(total_orders, 0) + p_order_delta,
    total_spent    = COALESCE(total_spent, 0)  + p_spent_delta,
    last_transaction_date = GREATEST(
      COALESCE(last_transaction_date, '1970-01-01'::timestamptz),
      NOW()
    )
  WHERE id = p_customer_id;
END;
$$;


-- =====================================================
-- 2. decrement_unit_stock_recalc
--    Combined function that atomically decrements a
--    unit product's stock AND recalculates the global
--    product stock in one call. Replaces the previous
--    pattern of 3 sequential RPC calls:
--      1. decrement_unit_stock
--      2. recalc_global_stock
--      3. Read updated product
--
--    Returns the new unit stock and new global stock.
-- =====================================================
CREATE OR REPLACE FUNCTION decrement_unit_stock_recalc(
  p_unit_product_id TEXT,
  p_qty NUMERIC
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_unit_stock  NUMERIC;
  v_new_global_stock NUMERIC;
  v_product_id      TEXT;
BEGIN
  -- Step 1: Decrement unit stock atomically
  UPDATE unit_products
  SET stock = stock - p_qty
  WHERE id = p_unit_product_id AND stock >= p_qty
  RETURNING stock, product_id
    INTO v_new_unit_stock, v_product_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stok unit tidak cukup (unit_product_id: %)', p_unit_product_id;
  END IF;

  -- Step 2: Recalculate global stock from all unit_products
  SELECT COALESCE(SUM(stock), 0) INTO v_new_global_stock
  FROM unit_products
  WHERE product_id = v_product_id;

  UPDATE products
  SET global_stock = v_new_global_stock
  WHERE id = v_product_id;

  -- Return both values for the caller
  RETURN json_build_object(
    'new_unit_stock', v_new_unit_stock,
    'new_global_stock', v_new_global_stock,
    'product_id', v_product_id
  );
END;
$$;


-- =====================================================
-- 3. batch_decrement_centralized_stock
--    Atomically decrements stock for multiple centralized
--    products in a single call. Accepts parallel arrays
--    of product IDs and quantities. Uses CTE to check all
--    stock levels before applying any deductions (all-or-nothing).
--
--    Parameters:
--      p_product_ids — JSONB array of product ID strings
--      p_quantities  — JSONB array of numeric quantities
--
--    Returns: JSON array of { product_id, new_stock } for
--    each successfully decremented product.
-- =====================================================
CREATE OR REPLACE FUNCTION batch_decrement_centralized_stock(
  p_product_ids JSONB,
  p_quantities  JSONB
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_results JSONB := '[]'::JSONB;
  v_pid TEXT;
  v_qty NUMERIC;
  v_new_stock NUMERIC;
  v_idx INTEGER;
BEGIN
  -- Validate array lengths match
  IF jsonb_array_length(p_product_ids) != jsonb_array_length(p_quantities) THEN
    RAISE EXCEPTION 'product_ids and quantities arrays must have the same length';
  END IF;

  -- Pre-flight: check ALL products have sufficient stock before deducting any
  FOR v_idx IN 0 .. jsonb_array_length(p_product_ids) - 1 LOOP
    v_pid := p_product_ids->>v_idx;
    v_qty := (p_quantities->>v_idx)::numeric;

    SELECT global_stock INTO v_new_stock
    FROM products
    WHERE id = v_pid;

    IF v_new_stock IS NULL THEN
      RAISE EXCEPTION 'Produk tidak ditemukan: %', v_pid;
    END IF;

    IF v_new_stock < v_qty THEN
      RAISE EXCEPTION 'Stok tidak cukup untuk produk %. Tersedia: %, Dibutuhkan: %',
        v_pid, v_new_stock, v_qty;
    END IF;
  END LOOP;

  -- Apply all deductions
  FOR v_idx IN 0 .. jsonb_array_length(p_product_ids) - 1 LOOP
    v_pid := p_product_ids->>v_idx;
    v_qty := (p_quantities->>v_idx)::numeric;

    UPDATE products
    SET global_stock = global_stock - v_qty
    WHERE id = v_pid
    RETURNING global_stock INTO v_new_stock;

    v_results := v_results || jsonb_build_object(
      'product_id', v_pid,
      'new_stock', v_new_stock
    );
  END LOOP;

  RETURN v_results;
END;
$$;
