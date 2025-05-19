-- enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Function to auto-update updated_at columns
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1. USERS & AUTH (from core.sql)

-- Social providers
CREATE TYPE social_provider AS ENUM ('google', 'github');

-- Users table
CREATE TABLE users (
  id            UUID      PRIMARY KEY DEFAULT uuid_generate_v4(),
  email         VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Social accounts linked to users
CREATE TABLE social_accounts (
  id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider            social_provider NOT NULL,
  provider_user_id    VARCHAR(255)    NOT NULL,
  provider_email      VARCHAR(255),
  created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- Added updated_at
  UNIQUE (provider, provider_user_id)
);

-- Refresh tokens for JWT refresh flow
CREATE TYPE token_status AS ENUM ('active', 'revoked');

CREATE TABLE refresh_tokens (
  id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token        VARCHAR(255)  NOT NULL UNIQUE,
  expires_at   TIMESTAMPTZ   NOT NULL,
  status       token_status  NOT NULL DEFAULT 'active',
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW() -- Added updated_at
);


-- 2. PROJECTS (from core.sql)

CREATE TABLE projects (
  id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name         VARCHAR(255)  NOT NULL,
  domain       VARCHAR(255),
  seed_topics  TEXT[]        DEFAULT ARRAY[]::TEXT[],
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, name)
);


-- 3. ASYNCHRONOUS JOBS (from core.sql)

-- Types of background jobs
CREATE TYPE job_type AS ENUM (
  'web_search',        -- UC-03 fetch papers
  'summarize',         -- UC-06 summarization & extractor
  'critic',            -- UC-05 scoring
  'gap_analysis',      -- UC-07 gap/topic analysis
  'qa'                 -- UC-08 contextual QA
);

-- Job statuses
CREATE TYPE job_status AS ENUM ('pending', 'in_progress', 'completed', 'failed');

CREATE TABLE async_jobs (
  id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id   UUID        REFERENCES projects(id) ON DELETE SET NULL,
  job_type     job_type    NOT NULL,
  status       job_status  NOT NULL DEFAULT 'pending',
  payload      JSONB,
  result       JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- 4. READING LIST & REMINDERS (UC-09) (from core.sql)

-- Reading statuses
CREATE TYPE reading_status AS ENUM ('to_read', 'reading', 'done');

CREATE TABLE reading_list (
  id           UUID           PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id   UUID           NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  paper_doi    VARCHAR(255)   NOT NULL,
  status       reading_status NOT NULL DEFAULT 'to_read',
  created_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  UNIQUE (project_id, paper_doi)
);

CREATE TABLE reminders (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  reading_list_id UUID        NOT NULL REFERENCES reading_list(id) ON DELETE CASCADE,
  remind_at       TIMESTAMPTZ NOT NULL,
  is_notified     BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. WEB SEARCH (from websearch.sql) - MOVED UP to be before tables that reference papers

-- PAPERS & METADATA
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

-- AUTHORS & MAPPING
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

-- PAPER SCORING (CRITIC)
CREATE TABLE paper_scores (
  id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  paper_id     UUID        NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
  score        NUMERIC(10,4) NOT NULL,
  details      JSONB,                                   -- breakdown of scoring factors
  scored_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. GAP ANALYSIS (from gap-analysis.sql)

-- GAP ANALYSIS RUNS
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

-- INDIVIDUAL GAPS
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

-- SUPPORTING PAPERS FOR EACH GAP
CREATE TABLE gap_supporting_papers (
  gap_id     UUID      NOT NULL REFERENCES gaps(id) ON DELETE CASCADE,
  paper_doi  VARCHAR   NOT NULL,                                -- DOI to link back to paper
  excerpt    TEXT      NOT NULL,
  PRIMARY KEY (gap_id, paper_doi, excerpt)
  -- No created_at/updated_at as it's a join table unlikely to be updated independently
);

-- TOPIC SUGGESTIONS FOR EACH GAP
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

-- 7. SUMMARIZER (from summarizer.sql)

-- EXTRACTOR: raw text + section info
CREATE TABLE extracted_documents (
  id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  paper_id     UUID          NOT NULL REFERENCES papers(id) ON DELETE CASCADE,  -- FK to papers.id
  full_text    TEXT          NOT NULL,                                 -- entire extracted text
  sections     JSONB         NOT NULL,                                 -- e.g. [{ "heading":"Introduction","start":0,"end":200 }, …]
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- SUMMARIZER: human‐friendly summaries
CREATE TABLE human_summaries (
  id                              UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  paper_id                        UUID          NOT NULL REFERENCES papers(id) ON DELETE CASCADE,  -- FK to papers.id
  problem_motivation              TEXT,                                 -- 1–2 sentence gap & why it matters
  key_contributions               TEXT[]        NOT NULL DEFAULT ARRAY[]::TEXT[],
  method_overview                 TEXT,                                 -- short paragraph or diagram description
  data_experimental_setup         TEXT,                                 -- datasets, baselines, hardware, protocol
  headline_results                JSONB         DEFAULT '[]'::JSONB,   -- e.g. [{ "method":"X","baseline":"Y","gain":"3%" }, …]
  limitations_failure_modes       TEXT[]        NOT NULL DEFAULT ARRAY[]::TEXT[],
  practical_implications_next_steps TEXT,                               -- how to use or extend; open questions
  created_at                      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at                      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE (paper_id)
);

-- SUMMARIZER: machine‐friendly structured facts
CREATE TABLE structured_facts (
  id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  paper_id     UUID          NOT NULL REFERENCES papers(id) ON DELETE CASCADE,  -- FK to papers.id
  facts        JSONB         NOT NULL,                                 -- the full paper_summary.json payload
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE (paper_id)
);

-- 8. QA (from qa.sql)

-- QA SESSIONS: one per user conversation thread
CREATE TABLE qa_sessions (
  id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- Assumes users table is in the same DB
  project_id   UUID          REFERENCES projects(id) ON DELETE CASCADE, -- Assumes projects table
  title        TEXT,                          -- optional label
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- MESSAGE ROLES ENUM (only two now)
DROP TYPE IF EXISTS message_role; -- Keep this in case qa.sql was run before and this type exists
CREATE TYPE message_role AS ENUM ('user', 'assistant');

-- QA MESSAGES: full chat history per session
CREATE TABLE qa_messages (
  id            UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id    UUID          NOT NULL REFERENCES qa_sessions(id) ON DELETE CASCADE,
  role          message_role  NOT NULL,
  content       TEXT          NOT NULL,                     -- the question or answer text
  metadata      JSONB         NOT NULL DEFAULT '{}'::JSONB, -- e.g. { "source_chunks": [<ids>], "tokens": 120 }
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
  -- No updated_at as messages are immutable
);

-- DOCUMENT CHUNKS: retrievable chunks for context
CREATE TABLE document_chunks (
  id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  paper_id     UUID          NOT NULL,                      -- FK to papers.id (assumed to be in the same DB)
  chunk_index  INTEGER       NOT NULL,                      -- order within paper
  chunk_text   TEXT          NOT NULL,
  embedding    REAL[],                                      -- optional similarity embeddings (originally VECTOR(1536), requires pgvector extension)
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE(paper_id, chunk_index)
);

-- SESSION CONTEXT: which chunks are part of each session's context
CREATE TABLE session_context_chunks (
  session_id       UUID      NOT NULL REFERENCES qa_sessions(id)   ON DELETE CASCADE,
  chunk_id         UUID      NOT NULL REFERENCES document_chunks(id) ON DELETE CASCADE,
  relevance_score  REAL,
  PRIMARY KEY (session_id, chunk_id)
  -- No created_at/updated_at as it's a join table
);

-- 9. Consolidated Triggers to keep updated_at current

DO $$
DECLARE
  tbl_name TEXT;
BEGIN
  FOR tbl_name IN
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public' -- Or your specific schema
    AND table_name IN (
      'users','projects','async_jobs','reading_list','reminders',
      'refresh_tokens','social_accounts',
      'gap_analyses','gaps','topic_suggestions',
      'extracted_documents','human_summaries','structured_facts',
      'papers','authors',
      'qa_sessions','document_chunks'
      -- Add any other tables here that have an updated_at column
      -- and don't already have a specific trigger from original files
    )
  LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%1$s_updated
         BEFORE UPDATE ON %1$s
         FOR EACH ROW EXECUTE PROCEDURE set_updated_at();',
      tbl_name
    );
  END LOOP;
END;
$$;

-- Note: Foreign key references between tables from different original files
-- (e.g., gap_analyses.project_id to projects.id, extracted_documents.paper_id to papers.id)
-- will now work correctly as all tables are in the same schema.
-- The `DROP TYPE IF EXISTS message_role;` is kept from qa.sql to ensure idempotency if this script is run multiple times.
-- Tables like `paper_authors`, `gap_supporting_papers`, `session_context_chunks` and `paper_scores`
-- do not have `updated_at` triggers as they are either join tables or represent immutable records.
-- `social_accounts` and `refresh_tokens` from `core.sql` now have `updated_at` and corresponding triggers.
