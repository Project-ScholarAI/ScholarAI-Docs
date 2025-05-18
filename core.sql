
-- enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USERS & AUTH

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
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);


-- 2. PROJECTS

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


-- 3. ASYNCHRONOUS JOBS

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


-- 4. READING LIST & REMINDERS (UC-09)

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


-- 5. TRIGGERS TO KEEP updated_at CURRENT

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach for every table with updated_at
DO $$
BEGIN
  FOR tbl IN ARRAY['users','projects','async_jobs','reading_list','reminders','refresh_tokens','social_accounts'] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%1$s_updated
         BEFORE UPDATE ON %1$s
         FOR EACH ROW EXECUTE PROCEDURE set_updated_at();',
      tbl
    );
  END LOOP;
END;
$$;

