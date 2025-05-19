-- 1. Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. EXTRACTOR: raw text + section info
CREATE TABLE extracted_documents (
  id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  paper_id     UUID          NOT NULL,                                 -- FK to papers.id in WebSearch DB
  full_text    TEXT          NOT NULL,                                 -- entire extracted text
  sections     JSONB         NOT NULL,                                 -- e.g. [{ "heading":"Introduction","start":0,"end":200 }, …]
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- 3. SUMMARIZER: human‐friendly summaries (updated fields per UC-06)
CREATE TABLE human_summaries (
  id                              UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  paper_id                        UUID          NOT NULL,               -- FK to papers.id in WebSearch DB
  problem_motivation              TEXT,                                 -- 1–2 sentence gap & why it matters
  key_contributions               TEXT[]        NOT NULL DEFAULT ARRAY[]::TEXT[],  
                                                        -- bullet points ("propose…", "demonstrate…")
  method_overview                 TEXT,                                 -- short paragraph or diagram description
  data_experimental_setup         TEXT,                                 -- datasets, baselines, hardware, protocol
  headline_results                JSONB         DEFAULT '[]'::JSONB,   -- e.g. [{ "method":"X","baseline":"Y","gain":"3%" }, …]
  limitations_failure_modes       TEXT[]        NOT NULL DEFAULT ARRAY[]::TEXT[],  
                                                        -- listed weaknesses or failure modes
  practical_implications_next_steps TEXT,                               -- how to use or extend; open questions
  created_at                      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at                      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE (paper_id)
);

-- 4. SUMMARIZER: machine‐friendly structured facts
CREATE TABLE structured_facts (
  id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  paper_id     UUID          NOT NULL,                                 -- FK to papers.id in WebSearch DB
  facts        JSONB         NOT NULL,                                 -- the full paper_summary.json payload
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE (paper_id)
);

-- 5. Trigger function to auto-update updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Attach trigger to keep updated_at current
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['extracted_documents','human_summaries','structured_facts'] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%1$s_updated
         BEFORE UPDATE ON %1$s
         FOR EACH ROW EXECUTE PROCEDURE set_updated_at();',
      tbl
    );
  END LOOP;
END;
$$;
