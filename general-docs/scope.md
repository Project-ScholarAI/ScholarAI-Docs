# ScholarAI – High‑Level Project Scope  
*Version 0.1 – May 2025*

## 1  Purpose
ScholarAI is a web‑based research copilot that streamlines the early, time‑consuming stages of academic work. It automates discovery, extraction, summarization, evaluation, and organization of scholarly literature, allowing researchers to focus on high‑value analysis and ideation.

## 2  Core Deliverables
| Area | Description |
|------|-------------|
| **Authentication & Authorization** | Secure JWT‑based login, role‑based access control, refresh‑token workflow. |
| **Project Workspaces** | Create, rename, and delete research projects; each workspace isolates its documents, agent configurations, and insights. |
| **Document Library** | Central store for metadata, PDFs, scraped text, and summaries. Supports tagging, search, reading‑status flags, and bulk actions. |
| **AI Agent Orchestration** | 1) WebSearch, 2) Scraper, 3) Summarizer, 4) Critic, 5) Gap‑Analysis, 6) Topic‑Suggestion(If have time), 7) Contextual QA(If have time). |
| **Insights Panel** | Displays scores, gaps, and recommended topics; sortable and exportable. |
| **Task & Reminder System** | Reading list status, calendar/event integration(optional), email or in‑app reminders. |
| **Frontend UI (Next.js)** | Responsive dashboard, library views, chat panel, document views, and notifications. |
| **Backend Services** | Spring Boot core APIs (auth, projects, library, tasks) and FastAPI AI backend for agent execution. |

## 3  Functional Boundaries
| In‑Scope | Out‑of‑Scope (Initial Release) |
|----------|-------------------------------|
| User registration, login, Social‑login | Email verification, password reset, profile management |
| Retrieval from public scholarly APIs | Paywalled or institutional‑proxy access |
| PDF/HTML scraping and summarization | OCR for scanned images |
| Citation,Publication etc metadatabased based scoring heuristics | Full semantic content grading or peer‑review prediction |
| Topic suggestions based on gaps | Automatic manuscript drafting |
| Email & calendar reminders | Conference or meeting managements |

## 4  Core Use Cases Flow
1. **Create Workspace** → **Define Research Domain** → **Configure Agents**
2. **Discover Literature** → **Import & Process PDFs** → **Review Summaries**
3. **Analyze Gaps** → **Identify New Directions & topics** → **Prioritize Reading**
4. **Track Progress** → **Export Insights** → **Schedule Follow-ups**

## 5  Non‑Functional Requirements
1. **Security** – JWT, Encrypted passwords, Sonar Cloud based security hotspots maintained, HTTPS everywhere, Middleware setup.  
2. **Scalability** – Dual Backend Service architecture with Springboot(core) and FastAPI(AI).  
3. **Performance** – Fast library search ; agent batch operations queue‑based, performance optimized architecture.  
4. **Reliability** – Rate Limiter setup to prevent DOS attack, General reliability.  
5. **Compliance** –  User‑controlled deletion of uploaded files.

## 6  Assumptions & Constraints
- Academic APIs (Crossref, Semantic Scholar) remain publicly accessible within their rate limits.  
- Users provide legally obtained PDFs.  
- Initial deployment targets modern desktop browsers.  
- Budget limit use of LLM API's.

---
