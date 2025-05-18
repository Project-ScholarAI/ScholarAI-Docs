-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. GAP ANALYSIS RUNS
CREATE TABLE gap_analyses (
  id               UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id       UUID          NOT NULL,                       -- reference to core DB project
  generated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  method           TEXT          NOT NULL,                       -- e.g. 'embedding-cluster-2025-05'
  papers_analyzed  INTEGER       NOT NULL,
  report           TEXT          NOT NULL,                       -- human-readable report
  raw_json         JSONB         NOT NULL,                       -- full gap_analysis.json payload
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- 2. INDIVIDUAL GAPS
CREATE TABLE gaps (
  id                UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  analysis_id       UUID          NOT NULL REFERENCES gap_analyses(id) ON DELETE CASCADE,
  gap_key           TEXT          NOT NULL,                       -- e.g. 'G1', 'G2'
  label             TEXT          NOT NULL,
  summary           TEXT          NOT NULL,
  severity_score    NUMERIC(5,3)  NOT NULL,
  opportunity_score NUMERIC(5,3)  NOT NULL,
  keywords          TEXT[]        NOT NULL DEFAULT ARRAY[]::TEXT[],
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE (analysis_id, gap_key)
);

-- 3. SUPPORTING PAPERS FOR EACH GAP
CREATE TABLE gap_supporting_papers (
  gap_id     UUID      NOT NULL REFERENCES gaps(id) ON DELETE CASCADE,
  paper_doi  VARCHAR   NOT NULL,                                -- DOI to link back to paper
  excerpt    TEXT      NOT NULL,
  PRIMARY KEY (gap_id, paper_doi, excerpt)
);

-- 4. TOPIC SUGGESTIONS FOR EACH GAP
CREATE TABLE topic_suggestions (
  id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  gap_id       UUID        NOT NULL REFERENCES gaps(id) ON DELETE CASCADE,
  title        TEXT        NOT NULL,
  rationale    TEXT        NOT NULL,
  feasibility  TEXT        NOT NULL,                            -- e.g. 'High', 'Medium', 'Low'
  novelty      TEXT        NOT NULL,                            -- e.g. 'High', 'Medium', 'Low'
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Trigger function to auto‐update updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Attach trigger to keep updated_at current
DO $$
BEGIN
  FOR tbl IN ARRAY['gap_analyses','gaps','topic_suggestions'] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%1$s_updated
         BEFORE UPDATE ON %1$s
         FOR EACH ROW EXECUTE PROCEDURE set_updated_at();',
      tbl
    );
  END LOOP;
END;
$$;
