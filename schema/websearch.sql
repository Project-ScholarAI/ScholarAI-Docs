-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. PAPERS & METADATA
CREATE TABLE papers (
  id                UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id        UUID        NOT NULL,                           -- references core DB project
  doi               VARCHAR(255) NOT NULL,
  title             TEXT        NOT NULL,
  publication_date  DATE,
  venue             VARCHAR(255),
  publisher         VARCHAR(255),
  peer_reviewed     BOOLEAN     NOT NULL DEFAULT FALSE,
  citation_count    INTEGER     NOT NULL DEFAULT 0,
  code_url          TEXT,
  dataset_url       TEXT,
  paper_url         TEXT,
  pdf_content       BYTEA,                                     -- raw PDF blob
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (project_id, doi)
);

-- 2. AUTHORS & MAPPING
CREATE TABLE authors (
  id             UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  name           TEXT        NOT NULL,
  orcid          VARCHAR(19),
  gs_profile_url TEXT,
  affiliation    TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE paper_authors (
  paper_id     UUID NOT NULL REFERENCES papers(id)   ON DELETE CASCADE,
  author_id    UUID NOT NULL REFERENCES authors(id)  ON DELETE CASCADE,
  author_order INTEGER NOT NULL,
  PRIMARY KEY (paper_id, author_id)
);

-- 3. PAPER SCORING (CRITIC)
CREATE TABLE paper_scores (
  id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  paper_id     UUID        NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
  score        NUMERIC(10,4) NOT NULL,
  details      JSONB,                                   -- breakdown of scoring factors
  scored_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. TRIGGER TO AUTO-UPDATE updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to tables with updated_at
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['papers','authors'] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%1$s_updated_at
         BEFORE UPDATE ON %1$s
         FOR EACH ROW EXECUTE PROCEDURE set_updated_at();',
      tbl
    );
  END LOOP;
END;
$$;
