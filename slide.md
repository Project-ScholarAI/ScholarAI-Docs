# ScholarAI System Architecture

## System Overview
ScholarAI is an enterprise-grade research assistance platform leveraging microservices architecture to provide automated literature discovery, analysis, and research planning capabilities. The system integrates AI-powered agents with robust backend services through event-driven communication patterns.

---

## Architecture Components

### 1. **Frontend Layer**
**Technology Stack:** Next.js 14 (React), TypeScript, TailwindCSS

**Key Responsibilities:**
- Single Page Application (SPA) with server-side rendering capabilities
- Secure token storage and management
- Real-time collaboration features (document editing, comments)
- Responsive design for desktop interfaces
- Integration with backend services through API Gateway

**Technical Highlights:**
- Next.js for enterprise-grade React framework with built-in routing, SSR, and API routes
- Server-side rendering for improved SEO and initial load performance
- TypeScript for enhanced type safety and developer experience
- TailwindCSS for consistent design system implementation
- React Query for efficient data fetching and caching

---

### 2. **API Gateway Layer**
**Technology Stack:** Spring Cloud Gateway

**Core Functions:**
- Request routing and load balancing (optional)
- Authentication and authorization middleware
- Rate limiting and circuit breaking
- Request/response transformation
- API versioning and documentation (OpenAPI/Swagger)

**Security Features:**
- JWT validation and token refresh
- CORS policy enforcement
- Request sanitization
- IP-based rate limiting

---

### 3. **Core Microservices (Spring Boot)**
**Technology Stack:** Spring Boot, Java 21, Spring Cloud

**Service Decomposition:**
1. **User Service**
   - Centralized authentication and authorization
   - JWT token generation, validation, and refresh
   - OAuth2/OpenID Connect integration
   - Role-based access control (RBAC)
   - Session management and token lifecycle
   - User account management
     - User registration and profile management
     - Password reset and account recovery
     - Email verification
     - Account settings and preferences
     - Account deactivation and deletion
     - Social login integration

2. **Project Service**
   - Project lifecycle management
     - Project creation and initialization, deletion
     - Project status tracking (active, archived, completed)
   - Service coordination
     - Project-scoped resource isolation
   - Project settings
     - Research domain configuration
     - Notification rules
   - Project workspace
     - Document organization
     - Activity timeline
     - Project milestones and deadlines (optional)

3. **Library Service**
   - Document management
     - User document upload and storage
     - File format support (PDF, DOCX, TXT, etc.)
   - Organization and categorization
     - Custom tagging and labeling
   - Search and discovery
     - Semantic search with embeddings (optional)
     - Advanced filtering and sorting

4. **Notification Service**
   - Event-driven notification dispatch

5. **Task Management Service**
   - To-do list management
   - Progress tracking
   - Task automation (optional)
     - Automated task creation
     - Reminder notifications
     - Status updates
     - Deadline alerts

**Inter-Service Communication:**
- Synchronous: REST APIs, gRPC
- Asynchronous: Event-driven via RabbitMQ
- Service Discovery: Spring Cloud Eureka
- Configuration Management: Spring Cloud Config

---

### 4. **AI Agent Layer**
**Technology Stack:** FastAPI, Python 3.11+, LangChain

**Core Capabilities:**
- Semantic document analysis
- Automated literature review
- Research gap identification
- Intelligent search and recommendation

**Event-Driven Architecture:**
- RabbitMQ for event processing
- Celery for background task processing
- Redis for caching and rate limiting

**AI Components:**
- Document processing pipeline
- Embedding generation
- Vector similarity search
- LLM integration (OpenAI, Gemini)

---

### 5. **Data Layer**
**Technology Stack:** PostgreSQL 15, Redis, MinIO

**Data Management:**
- PostgreSQL: Primary data store
  - Structured data (users, projects, metadata)
  - JSON/JSONB for flexible schema
- Redis: Caching and session management
- MinIO: Object storage for documents and artifacts

**Data Architecture:**
- Database per service pattern
- CQRS for complex queries

---

### 6. **DevOps & Infrastructure**
**Technology Stack:** Docker, Kubernetes, GitHub Actions

**Infrastructure Components:**
- Container orchestration with Kubernetes (optional)
- CI/CD pipelines
- Monitoring and logging (Prometheus, Grafana)

