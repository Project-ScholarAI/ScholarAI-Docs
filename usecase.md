# ScholarAI Use Cases

## UC-01: User Authentication & Authorization

### Actors
- Researcher (end-user)
- System (Spring Boot Auth Service)

### Goal
Researcher securely logs in and gains access to ScholarAI features based on their role.

### Preconditions
- Researcher has already registered and confirmed email
- JWT keys are configured in backend

### Main Flow
1. Researcher navigates to Login page
2. Researcher enters email & password and submits
3. Frontend (Next.js) sends credentials to Spring Boot Auth endpoint
4. Auth service validates credentials against user store
5. On success, system issues a signed JWT + refresh token
6. Frontend stores JWT (e.g. HttpOnly cookie) and updates UI to "logged in"
7. Researcher gains access to authorized UI routes

### Alternative Flows
- **Invalid Credentials**: System returns 401 → frontend shows "Invalid email or password"
- **Expired Refresh Token**: On token refresh attempt, system returns 403 → user is redirected to login

### Postconditions
- JWT is active and researcher may call protected APIs
- Unauthorized requests to protected endpoints are denied

## UC-02: Create & Manage Research Project

### Actors
- Researcher

### Goal
Set up a new research "project" workspace to scope ScholarAI agents.

### Preconditions
- Researcher is authenticated

### Main Flow
1. On dashboard, researcher clicks "New Project"
2. System displays a form requesting:
   - Project name
   - Research domain (e.g. "Computer Vision")
   - Optional seed topics (tags)
3. Researcher fills form and submits
4. Backend creates a Project record (Spring Boot), initializes empty library and agent configs
5. Frontend redirects to Project Overview page, showing blank library and controls to run agents

### Alternative Flows
- **Missing Required Fields**: Validation error; form highlights omissions
- **Duplicate Project Name**: Backend returns 409; frontend prompts to choose another name

### Postconditions
- New project exists; researcher may invoke WebSearch, Scraper, etc., scoped to this project

## UC-03: Automated Paper Retrieval (WebSearch Agent)

### Actors
- Researcher
- WebSearch Agent (FastAPI AI backend)

### Goal
Fetch a batch of relevant papers based on project settings.

### Preconditions
- Researcher has created a project with domain (and optionally topics)
- Researcher clicks "Fetch Papers"

### Main Flow
1. Frontend issues request to FastAPI WebSearch agent with project ID, domain, topics, desired count (e.g. 20)
2. Agent queries academic APIs (e.g. Crossref, Semantic Scholar) to retrieve metadata for landmark, survey, and recent papers
3. Agent returns a list of paper metadata (title, authors, DOI, abstract, publication date)
4. Backend stores metadata in project's Library table (Spring Boot service)
5. Frontend displays retrieved items under "Library → Retrieved Papers"

### Alternative Flows
- **API Rate Limit Hit**: Agent responds with partial results + warning; researcher is informed
- **No Papers Found**: Agent returns empty list; frontend suggests broadening topics

### Postconditions
- Library contains newly fetched paper entries, ready for scraping and scoring

## UC-04: Content Extraction & Summarization

### Actors
- Researcher
- Scraper Agent
- Summarizer Agent

### Goal
Convert raw PDFs/web pages into structured text and generate concise summaries.

### Preconditions
- Library contains paper entries with accessible URLs or uploaded PDFs

### Main Flow
1. Researcher selects one or more library items and clicks "Extract & Summarize"
2. For each item, backend invokes:
   - Scraper Agent: downloads PDF/HTML, extracts sections (abstract, methods, conclusions)
   - Summarizer Agent: ingests extracted text and returns a 3–5-sentence summary
3. Backend persists raw extraction and summary to the item's record
4. Frontend shows summary inline and tags item as "summarized"

### Alternative Flows
- **Extraction Failure**: Malformed PDF → item flagged with "Extraction Error," researcher can re-upload or skip
- **Summarization Rate Limit**: Queue job and notify researcher when ready

### Postconditions
- Each processed item has structured text and summary; researcher can review without opening full PDF

## UC-05: Critique & Gap Analysis

### Actors
- Researcher
- Critic Agent
- Gap Analysis Agent

### Goal
Evaluate paper quality and identify research gaps.

### Preconditions
- Papers are retrieved and (optionally) summarized
- Metadata (citation counts, author h-index) available

### Main Flow (Critic)
1. Researcher selects a set of papers and clicks "Score Papers"
2. Backend feeds metadata to Critic Agent, which computes a composite score (e.g. based on citation count, venue rank, author prestige)
3. Scores are stored and library items are sorted by score

### Main Flow (Gap Analysis)
1. Researcher clicks "Analyze Gaps"
2. Backend collates summaries of top-N papers and invokes Gap Analysis Agent
3. Agent returns bullet points describing under-explored areas or opportunities
4. Frontend displays gap list in "Insights" panel

### Alternative Flows
- **Insufficient Data**: Fewer than 3 papers → system warns and suggests fetching more

### Postconditions
- Papers are ranked; clear research gaps are presented for planning next steps

## UC-06: Topic Suggestion Agent

### Actors
- Researcher
- Topic Suggestion Agent

### Goal
Propose novel, relevant research topics.

### Preconditions
- Research gaps have been generated

### Main Flow
1. Researcher clicks "Suggest Topics"
2. Backend compiles gap points + domain context and calls Topic Suggestion Agent
3. Agent returns a list of 5–10 candidate topics (with brief rationale)
4. Frontend displays topics; researcher can "Save" any to project's Reading List

### Alternative Flows
- **No Gaps Available**: Agent uses raw summaries to propose broader topics

### Postconditions
- Project's Reading List is populated with new topic entries for further exploration

## UC-07: Contextual QA Chat

### Actors
- Researcher
- QA Agent

### Goal
Answer ad-hoc questions using selected documents as context.

### Preconditions
- One or more library items are summarized/extracted
- Researcher has a project open

### Main Flow
1. Researcher selects a document (or multiple) and opens the side-chat panel
2. Researcher types a question (e.g. "What methodology did Smith et al. use?")
3. Frontend sends question + context (summaries or extracted text) to QA Agent
4. Agent returns a concise, context-grounded answer
5. Frontend displays the answer in chat history

### Alternative Flows
- **Out-of-Scope Question**: Agent replies "I'm not sure—try rephrasing or selecting another document"

### Postconditions
- Researcher obtains targeted insights without manually reading full PDFs

## UC-08: Task Checklist & Reminder Notifications

### Actors
- Researcher

### Goal
Track reading progress, set reminders, and integrate with calendar.

### Preconditions
- Researcher is authenticated and on a project page

### Main Flow
1. Under "Reading List", researcher marks each paper as "To Read," "Reading," or "Done"
2. Researcher clicks "Add Reminder" on any item, picks date/time, and opts for calendar integration (e.g. Google Calendar)
3. System schedules a notification via Spring Boot (email/push) and creates calendar event via API
4. At the scheduled time, researcher receives reminder

### Alternative Flows
- **Failed Calendar Sync**: Fallback to email reminder only

### Postconditions
- Reading status is up to date; reminders keep researcher on schedule