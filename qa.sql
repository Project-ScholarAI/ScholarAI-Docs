-- 1. Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. QA SESSIONS: one per user conversation thread
--    each session belongs to a specific user (and optionally a project)
CREATE TABLE qa_sessions (
  id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  project_id   UUID          REFERENCES projects(id) ON DELETE CASCADE,
  title        TEXT,                          -- optional label
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- 3. MESSAGE ROLES ENUM (only two now)
DROP TYPE IF EXISTS message_role;
CREATE TYPE message_role AS ENUM ('user', 'assistant');

-- 4. QA MESSAGES: full chat history per session
CREATE TABLE qa_messages (
  id            UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id    UUID          NOT NULL REFERENCES qa_sessions(id) ON DELETE CASCADE,
  role          message_role  NOT NULL,
  content       TEXT          NOT NULL,                     -- the question or answer text
  metadata      JSONB         NOT NULL DEFAULT '{}'::JSONB, -- e.g. { "source_chunks": [<ids>], "tokens": 120 }
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- 5. DOCUMENT CHUNKS: retrievable chunks for context
CREATE TABLE document_chunks (
  id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  paper_id     UUID          NOT NULL,                      -- FK to papers.id
  chunk_index  INTEGER       NOT NULL,                      -- order within paper
  chunk_text   TEXT          NOT NULL,
  embedding    VECTOR(1536),                                -- optional similarity embeddings
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  UNIQUE(paper_id, chunk_index)
);

-- 6. SESSION CONTEXT: which chunks are part of each session’s context
CREATE TABLE session_context_chunks (
  session_id       UUID      NOT NULL REFERENCES qa_sessions(id)   ON DELETE CASCADE,
  chunk_id         UUID      NOT NULL REFERENCES document_chunks(id) ON DELETE CASCADE,
  relevance_score  REAL,
  PRIMARY KEY (session_id, chunk_id)
);

-- 7. Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  FOR tbl IN ARRAY['qa_sessions','document_chunks'] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%1$s_updated
         BEFORE UPDATE ON %1$s
         FOR EACH ROW EXECUTE PROCEDURE set_updated_at();',
      tbl
    );
  END LOOP;
END;
$$;
