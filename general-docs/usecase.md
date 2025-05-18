# ScholarAI Use Cases

## UC-01: User Authentication & Authorization

### Actors
- Researcher (end-user)
- System (Spring Boot Auth Service)
- Social Providers (Google, GitHub)

### Goal
Researcher securely signs up or logs in and gains access to ScholarAI features based on their role.

### Preconditions
- For Login: Researcher has already registered and confirmed email (if using email/password).
- For Social Auth: Researcher has an account with Google or GitHub.
- JWT keys are configured in backend.
- OAuth 2.0 credentials for Google and GitHub are configured in backend.

### Main Flow (Login - Email/Password)
1. Researcher navigates to Login page.
2. Researcher enters email & password and submits.
3. Frontend (Next.js) sends credentials to Spring Boot Auth endpoint.
4. Auth service validates credentials against user store.
5. On success, system issues a signed JWT + refresh token.
6. Frontend stores JWT (e.g. HttpOnly cookie) and updates UI to "logged in".
7. Researcher gains access to authorized UI routes.

### Main Flow (Signup - Email/Password)
1. Researcher navigates to Signup page.
2. Researcher enters email & password and submits.
3. Frontend (Next.js) sends credentials to Spring Boot Auth endpoint for registration.
4. Auth service creates a new user record (status: pending confirmation).
5. System sends a confirmation email to the researcher.
6. Researcher clicks the confirmation link in the email.
7. Auth service activates the user account.
8. Researcher can now log in using the new credentials.

### Main Flow (Login/Signup - Social Auth)
1. Researcher navigates to Login or Signup page.
2. Researcher clicks "Login with Google" or "Login with GitHub".
3. Frontend redirects to the respective Social Provider's authentication page.
4. Researcher authenticates with the Social Provider.
5. Social Provider redirects back to ScholarAI (callback URL) with an authorization code.
6. Frontend sends the authorization code to Spring Boot Auth endpoint.
7. Auth service exchanges the code for an access token from the Social Provider.
8. Auth service retrieves user profile information (email, name) from the Social Provider.
9. If user with this email exists, system links social account. If not, system creates a new user record.
10. System issues a signed JWT + refresh token.
11. Frontend stores JWT and updates UI to "logged in".
12. Researcher gains access to authorized UI routes.

### Alternative Flows
- **Invalid Credentials (Email/Password Login)**: System returns 401 → frontend shows "Invalid email or password".
- **Email Already Exists (Email/Password Signup)**: System returns 409 → frontend shows "Email already registered. Try logging in or use a different email."
- **Social Auth Failure**: Social Provider returns an error → frontend shows a generic error message.
- **Expired Refresh Token**: On token refresh attempt, system returns 403 → user is redirected to login.
- **Unconfirmed Email (Login Attempt)**: System returns 403 → frontend prompts to check email for confirmation link.

### Postconditions
- JWT is active and researcher may call protected APIs.
- Unauthorized requests to protected endpoints are denied.
- New user account is created and/or linked with social provider if signup/social auth was used.

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
Iteratively download batches of relevant papers (if accessible) and collect comprehensive metadata based on project settings, adding them to the project library while avoiding duplicates.

### Preconditions
- Researcher has created a project with domain (and optionally topics).
- Researcher clicks "Fetch Papers" (this can be done multiple times to retrieve more papers).

### Main Flow
1. Frontend issues request to FastAPI WebSearch agent with project ID, domain, topics, and a desired count for the current batch (e.g., 20 papers).
2. Agent queries academic APIs (e.g., Crossref, Semantic Scholar, etc.) and attempts to download full-text PDFs where available for up to the desired count.
3. For each paper, the Agent collects the following metadata (fields are optional and will be empty if not found):
    - Title (string)
    - DOI (string) - Used for deduplication.
    - Publication date (ISO date string)
    - Venue name (string, e.g., journal name, conference name, or "arXiv")
    - Publisher (string)
    - Peer-reviewed? (boolean)
    - Authors (array of objects): `[ { name: string, orcid?: string, gsProfileUrl?: string, affiliation?: string } ]`
    - Citation count (integer, total)
    - Code repository URL (string, e.g., GitHub, Zenodo link)
    - Dataset URL (string)
    - Paper URL (string, link to the paper's landing page or PDF source)
4. Agent returns a list of objects for the current batch, each containing the paper's metadata, the downloaded PDF content (if successful, e.g., as a base64 string or binary data), and the Paper URL.
5. Backend receives the batch. For each paper, it checks if a paper with the same DOI already exists in the project's Library. 
   - If a duplicate DOI is found, the existing entry may be updated with any new metadata (and potentially the PDF content if previously missing/failed), but a new entry is not created.
   - If the DOI is new, the metadata, the downloaded PDF content (if any), and the Paper URL are stored in the project's Library table (Spring Boot service, PDF likely stored as BLOB or in a managed file store associated with the record).
6. Frontend displays newly added or updated items from the batch under "Library → Retrieved Papers", indicating which have successfully downloaded PDFs available directly in the library.

### Alternative Flows
- **API Rate Limit Hit**: Agent responds with partial results for the current batch + warning; researcher is informed and can try fetching again later.
- **No New Papers Found**: Agent returns an empty list or indicates no new papers matching criteria were found for the current batch; frontend informs the researcher.
- **Download Failure**: If a paper PDF cannot be downloaded (e.g., paywall, broken link), metadata (including Paper URL and DOI) is still collected. The system checks for duplicates based on DOI and stores/updates the entry accordingly, marking it in the frontend and providing the direct link.

### Postconditions
- Project Library is augmented with newly fetched paper entries (or existing entries are updated); duplicates are avoided based on DOI.
- Downloaded PDF content (for newly added non-duplicate papers, or updated entries) is stored directly within or associated with their respective library entries.
- All retrieved items (new or updated) are ready for scraping (if PDF available), summarization, and scoring.

## UC-04: View Paper Details and Content

### Actors
- Researcher

### Goal
Researcher views the full content of a downloaded paper and its associated metadata within the application.

### Preconditions
- Researcher is authenticated and has a project open.
- At least one paper with a downloaded PDF exists in the project's library.

### Main Flow
1. Researcher navigates to the "Library" section.
2. Researcher selects a paper that has a downloaded PDF.
3. Frontend displays a view with two main sections:
    - A PDF viewer component showing the full content of the paper.
    - A metadata panel displaying all collected information for the paper (Title, DOI, Publication Date, Venue, Publisher, Peer-reviewed status, Authors, Citation count, Code/Dataset URLs, Paper URL) in a clear, readable format.
4. Researcher can read the PDF and review its metadata.

### Alternative Flows
- **PDF Rendering Issues**: If the PDF cannot be rendered correctly by the viewer, a message is displayed, and the researcher can still view the metadata and attempt to download the original PDF file via its Paper URL (if available).
- **Paper Not Downloaded**: If the selected paper's PDF was not successfully downloaded (only metadata and Paper URL exist), the PDF viewer area shows a message indicating the PDF is not available locally, and prominently displays the Paper URL to access it externally.

### Postconditions
- Researcher has a clear view of the paper's content and its metadata, facilitating easier review and assessment.

## UC-05: Automated Paper Scoring & Sorting (Critic Agent)

### Actors
- Researcher
- Critic Agent (FastAPI AI backend)
- System (Spring Boot Backend)

### Goal
Automatically score papers in the project library based on comprehensive metadata and allow the researcher to sort the library by this score to highlight relevance or impact.

### Preconditions
- Researcher is authenticated and has a project open.
- The project library contains papers with metadata (as collected in UC-03).

### Main Flow
1. Researcher is viewing the project library.
2. Researcher activates a "Sort by Value" feature (e.g., clicks a sort button or selects an option).
3. Frontend sends a request to the System (Spring Boot Backend) to score and sort the papers.
4. For any papers in the library not yet scored or whose metadata has changed, the System invokes the Critic Agent.
5. The Critic Agent computes a composite score for each paper based on available metadata, such as:
    - Total citation count
    - Journal/conference name (and its perceived prestige/rank)
    - Lead & last author h-index (if available)
    - Aggregate author citation counts (if available)
    - Recency (publication date)
    - Keyword overlap in title (with project topics or recent search queries if an abstract is not available/processed).
6. The Critic Agent returns the scores to the System.
7. The System persists these scores with the paper records in the library.
8. The System provides the sorted list of papers (or just the scores for the frontend to sort) back to the Frontend.
9. Frontend updates the library view, displaying papers sorted by their calculated score (e.g., highest to lowest). The score may be optionally displayed next to each paper.

### Alternative Flows
- **Insufficient Metadata for Scoring**: If a paper lacks key metadata for scoring, it may be assigned a default/low score, be excluded from sorting by score, or scored based on available data with a notification.
- **Scoring Already Up-to-Date**: If scores are current, the system may sort using existing scores without invoking the Critic Agent.
- **Partial Scoring/Background Process**: For large libraries, scoring might be initiated as a background job, with the UI updating as scores become available.

### Postconditions
- Relevant papers in the library are assigned a relevance/value score.
- The library view is sorted according to these scores, helping the researcher identify key papers.
- Researcher can make more informed decisions about which papers to prioritize.

## UC-06: Content Extraction & Summarization

### Actors
- Researcher
- Scraper Agent (FastAPI AI backend)
- Summarizer Agent (FastAPI AI backend)
- System (Spring Boot Backend)

### Goal
For selected papers, extract content from downloaded PDFs and generate both multiple levels of human-friendly summaries and a machine-friendly structured JSON object of facts to aid in rapid understanding and further analysis.

### Preconditions
- Researcher is authenticated and has a project open.
- Project library contains papers with successfully downloaded PDF content (from UC-03).

### Main Flow
1. Researcher selects one or more papers from the project library that have downloaded PDFs.
2. Researcher clicks an "Extract & Summarize" button/option.
3. Frontend sends a request to the System (Spring Boot Backend) with the IDs of the selected papers.
4. For each selected paper, the System coordinates the following:
    a. Invokes the Scraper Agent: The agent takes the downloaded PDF content, extracts its textual content, and identifies major sections (e.g., abstract, introduction, methods, conclusions).
    b. Invokes the Summarizer Agent: The agent ingests the extracted text and section information and produces two complementary sets of outputs:
        i.  **Human-Friendly Summaries:**
            -   **Problem & Motivation:** What gap or pain-point does the paper address, and why does it matter now? (1–2 sentences)
            -   **Key Contributions:** Bullet list of what the authors claim is new or better—keep it verb-led (“propose… demonstrate…”).
            -   **Method Overview:** One short paragraph or a simple block diagram that captures the core idea/architecture/training trick.
            -   **Data & Experimental Setup:** Datasets, baselines, hardware, and evaluation protocol—just enough to judge fairness and reproducibility.
            -   **Headline Results (Metrics Table):** Compact table: paper method vs. strongest baseline(s); highlight gains or trade-offs.
            -   **Limitations & Failure Modes:** Author-stated or reviewer-observed weaknesses, scalability ceilings, ethical concerns.
            -   **Practical Implications / Next Steps:** How practitioners or researchers might use or extend the work; open questions.
        ii. **Machine-Friendly Structured Facts (JSON Object):** A detailed JSON object (`paper_summary.json`) containing structured information (see example below). This JSON is also used by the Gap Analysis Agent (UC-07).
5. The System (Spring Boot Backend) persists all generated summaries and the structured JSON data, associating them with the respective paper record in the project library.
6. Frontend updates the UI to display the generated summaries in appropriate sections within the paper's detailed view, allowing easy access to each component (Problem & Motivation, Key Contributions, Method Overview, etc.).
7. The paper is tagged or visually indicated as "Summarized".

### Example Machine-Friendly Structured Facts (`paper_summary.json`)
```json
{
  "paperId": "DOI or arXiv",
  "title": "...",
  "coreIdea": "...",
  "contributions": [
    "First to use ...",
    "Introduces a ...",
    "Achieves state-of-the-art on ..."
  ],
  "problemAddressed": "...",
  "method": {
    "paradigm": "Graph Neural Network",
    "keySteps": ["Data preprocessing ...", "Edge-weighted ..."],
    "diagramNeeded": false
  },
  "datasets": ["Cora", "Citeseer"],
  "metrics": [
    {"name": "Accuracy", "value": 0.912, "baseline": 0.88},
    {"name": "F1",       "value": 0.901}
  ],
  "resultsClaim": "Outperforms baseline GCN by 3 %.",
  "strengths": [
    "Demonstrates robustness to noisy edges",
    "Open-sourced code and dataset splits"
  ],
  "weaknesses": [
    "Tested only on citation networks (limited domain)",
    "Lacks ablation on hyper-parameters"
  ],
  "limitations": [
    "Requires full graph in memory",
    "Assumes homophily; performance drops on heterophilous graphs"
  ],
  "futureWork": [
    "Scale to graphs with >1 M nodes",
    "Explore heterophilous settings"
  ],
  "openQuestions": [
    "Can the approach generalize to dynamic graphs?"
  ],
  "tags": ["graph", "semi-supervised", "citation network"],
  "sectionChunks": [
    {"heading": "Introduction", "start": 0, "end": 200},
    {"heading": "Method",        "start": 201, "end": 852}
  ]
}
```

### Alternative Flows
- **Extraction Failure**: If the Scraper Agent fails to extract text from a PDF (e.g., image-based PDF with no OCR layer, corrupted file), the item is flagged with an "Extraction Error." No summarization occurs for that paper. Researcher may be able to manually provide text or re-upload a better PDF if that feature exists.
- **Summarization Failure/Partial Success**: If the Summarizer Agent fails for some reason, or can only produce some of the requested outputs, the item is flagged accordingly. Any successfully generated parts are saved and displayed.
- **Content Not Suitable for All Summary Types**: If the paper content doesn't lend itself to a specific summary type (e.g., no empirical results for a Key Numbers Table), that part of the summary may be omitted or indicate N/A.
- **Rate Limiting/Queueing**: For multiple paper selections, summarization tasks may be queued, and the UI updates as each paper is processed.

### Postconditions
- Each successfully processed paper in the library has:
    - Multiple human-friendly summary sections (Problem & Motivation, Key Contributions, etc.) stored and accessible through the UI.
    - A machine-friendly structured JSON object of facts (`paper_summary.json`) stored.
- These outputs are available for researcher review and for downstream agents (e.g., Gap Analysis).

## UC-07: Research Gap Analysis & Topic Suggestion

### Actors
- Researcher
- Gap Analysis & Topic Suggestion Agent (FastAPI AI backend)
- System (Spring Boot Backend)

### Goal
Identify research gaps from a collection of summarized papers and suggest novel, relevant research topics based on these gaps, providing both machine-readable structured data and a human-friendly report.

### Preconditions
- Researcher is authenticated and has a project open.
- The project library contains multiple papers that have been processed by `UC-06: Content Extraction & Summarization`, resulting in machine-friendly structured JSON facts (`paper_summary.json`) for each.
- Researcher is ready to identify overarching research gaps and explore new topic ideas.

### Main Flow
1. Researcher navigates to an "Insights" or "Analysis" section of the project.
2. Researcher clicks an "Analyze Gaps & Suggest Topics" button (potentially after selecting a specific set of summarized papers, or defaulting to all summarized papers in the project).
3. Frontend sends a request to the System (Spring Boot Backend), indicating the set of papers to analyze.
4. The System collates the `paper_summary.json` objects for all selected/relevant papers.
5. The System invokes the Gap Analysis & Topic Suggestion Agent, providing the collection of structured JSON facts.
6. The Agent processes the input to:
    a. Identify research gaps (e.g., under-explored areas, contradictions, limitations in current work).
    b. For each significant gap, generate a set of potential research topic suggestions with rationales.
7. The Agent returns two outputs to the System:
    a. **Structured JSON Data (`gap_analysis.json`):** A JSON object containing detailed information about identified gaps, supporting evidence from papers, severity/opportunity scores, and associated topic suggestions with their details (see example schema below).
    b. **Human-Readable Report:** A formatted text summary of the top gaps and most promising topic ideas (see example below).
8. The System (Spring Boot Backend) persists the `gap_analysis.json` data, potentially associating it with the project or the specific analysis run.
9. Frontend receives both the structured JSON and the human-readable report from the System.
10. Frontend displays the information:
    - The human-readable report is presented in an "Insights" panel, possibly with collapsible sections for each gap, allowing users to expand for details like supporting paper excerpts and full topic suggestions.
    - The UI might offer options to "Save" or "Add to Reading List" for promising topic suggestions, linking them to the project.

### Output Schema (`gap_analysis.json` - Stored as JSONB)
```json
{
  "generatedAt": "2025-05-18T14:07:21Z",
  "gaps": [
    {
      "gapId": "G1",
      "label": "Heterophilous Graph Benchmarks",
      "summary": "Current GNN research lacks large-scale benchmarks where connected nodes have dissimilar labels.",
      "severityScore": 0.82,
      "opportunityScore": 0.76,
      "supportingPapers": [
        {
          "paperId": "10.1145/XYZ",
          "excerpt": "… performance drops on heterophilous graphs, a direction we leave for future work."
        },
        { "paperId": "arXiv:2403.01234", "excerpt": "… our method assumes homophily…" }
      ],
      "topicSuggestions": [
        {
          "title": "Benchmarking GNNs on Massive Heterophilous Graphs",
          "rationale": "Would directly address the data scarcity identified in 5 high-impact papers",
          "feasibility": "Medium",
          "novelty": "High"
        },
        {
          "title": "Self-Supervised Pre-training for Heterophilous Networks",
          "rationale": "Leverages recent SSL advances; none of the surveyed papers attempted SSL in this setting",
          "feasibility": "High",
          "novelty": "Medium"
        }
      ],
      "keywords": ["heterophily", "graph benchmark", "GNN"]
    }
    // ... more gaps ...
  ],
  "method": "embedding-cluster-2025-05",
  "papersAnalyzed": 42
}
```

### Example Human-Readable Report (Returned alongside JSON)
```text
Top Gaps Detected (click to expand):

* Heterophilous Graph Benchmarks — Severity 0.82 Opportunity 0.76
  ↳ Topic idea: **"Benchmarking GNNs on Massive Heterophilous Graphs"** (Rationale: Would directly address the data scarcity identified in 5 high-impact papers…)
  ↳ Topic idea: **"Self-Supervised Pre-training for Heterophilous Networks"** (Rationale: Leverages recent SSL advances…)
  (Show evidence...)

* Lack of Real-Time Inference on Mobile Devices — Severity 0.71 Opportunity 0.64
  ↳ Topic idea: **"8-bit Quantization for Graph Transformers on Edge Hardware"** (Rationale: …)
  (Show evidence...)
```
(The UI can render the list collapsible; "Show evidence" reveals the supporting excerpts with inline links to the papers.)

### Alternative Flows
- **Insufficient Summarized Data**: If fewer than a threshold (e.g., 3-5) of papers have the required `paper_summary.json` available, the system may warn the researcher or disallow the analysis, suggesting more papers be processed via UC-06.
- **No Clear Gaps/Topics Found**: The Agent may return a message indicating no significant gaps or viable topic suggestions could be identified from the provided set of papers.
- **Partial Results**: If the analysis is complex or time-consuming, the system might provide partial results or updates as they become available, especially for a large number of input papers.

### Postconditions
- A structured `gap_analysis.json` object containing identified research gaps, supporting evidence, and topic suggestions is stored and available.
- A human-readable report summarizing these findings is presented to the researcher.
- Researcher can use these insights to identify promising research directions and populate their project's reading list or idea backlog.

## UC-08: Contextual QA Chat

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

## UC-09: Task Checklist & Reminder Notifications

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