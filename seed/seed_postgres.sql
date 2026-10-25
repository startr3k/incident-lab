-- PAY-4371 lab: fee rules table WITHOUT an index on rule_key (the latent landmine).
CREATE TABLE fee_rules (
  id serial PRIMARY KEY,
  rule_key varchar(64) NOT NULL,
  rate numeric(10,6) NOT NULL,
  effective_date date NOT NULL,
  payload text
);
INSERT INTO fee_rules (rule_key, rate, effective_date, payload)
SELECT
  'FEE_' || lpad((i % 500)::text, 4, '0') || '_' || (i % 12 + 1)::text,
  (random() * 0.02)::numeric(10,6),
  date '2024-01-01' + (i % 900),
  repeat('x', 80)
FROM generate_series(1, 200000) AS s(i);

CREATE TABLE settlement_orders (
  id bigserial PRIMARY KEY,
  order_ref varchar(32),
  amount numeric(14,2),
  status varchar(16),
  created_at timestamptz DEFAULT now()
);
INSERT INTO settlement_orders (order_ref, amount, status, created_at)
SELECT 'SG' || lpad(i::text, 10, '0'), (random()*10000)::numeric(14,2),
       (ARRAY['NEW','SETTLED','PENDING'])[1 + (i % 3)],
       now() - interval '2 hours'
FROM generate_series(1, 500000) AS s(i);
ANALYZE;
