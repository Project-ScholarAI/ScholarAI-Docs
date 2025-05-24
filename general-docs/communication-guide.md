# ScholarAI Inter-Service Communication Guide

This guide documents the RabbitMQ-based communication architecture between Spring Boot and FastAPI services in the ScholarAI system.

## 🏗️ Architecture Overview

```
┌─────────────────┐    RabbitMQ     ┌─────────────────┐
│   Spring Boot   │ ──────────────► │    FastAPI      │
│   (Core API)    │                 │  (AI Service)   │
│                 │ ◄────────────── │                 │
└─────────────────┘    Results      └─────────────────┘
```

**Flow:**

1. Spring Boot receives HTTP request
2. Spring Boot publishes job to RabbitMQ queue
3. FastAPI consumes job from queue
4. FastAPI simulates AI processing (10-15s delay)
5. FastAPI publishes result back to RabbitMQ
6. Spring Boot receives and processes result

## 🚀 Quick Start

### Prerequisites

- RabbitMQ running on localhost:5672
- User: `scholar`, Password: `scholar123`
- Java 17+ for Spring Boot
- Python 3.10+ for FastAPI

### 1. Start RabbitMQ

```bash
# If using Docker
docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 \
  -e RABBITMQ_DEFAULT_USER=scholar \
  -e RABBITMQ_DEFAULT_PASS=scholar123 \
  rabbitmq:3-management

# Or use your existing RabbitMQ setup
```

### 2. Start Spring Boot Service

```bash
cd ScholarAI-Backend-Springboot
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

The service will be available at: `http://localhost:8080`
Swagger UI: `http://localhost:8080/docs`

### 3. Start FastAPI Service

#### Option A: Run with integrated consumer (recommended)

```bash
cd ScholarAI-Backend-FastAPI
poetry install
poetry run uvicorn app.main:app --reload --port 8001
```

#### Option B: Run consumer separately

```bash
cd ScholarAI-Backend-FastAPI
poetry install
poetry run python app/consumer_runner.py
```

## 🧪 Testing the Communication

### Method 1: Using Swagger UI

1. Go to `http://localhost:8080/docs`
2. Find the `/api/demo/trigger-summarization` endpoint
3. Click "Try it out"
4. Use this sample request:

```json
{
  "pdfUrl": "https://arxiv.org/pdf/2301.00001.pdf"
}
```

5. Execute the request

### Method 2: Using curl

```bash
curl -X POST "http://localhost:8080/api/demo/trigger-summarization" \
  -H "Content-Type: application/json" \
  -d '{"pdfUrl": "https://arxiv.org/pdf/2301.00001.pdf"}'
```

### Method 3: Using HTTPie

```bash
http POST localhost:8080/api/demo/trigger-summarization pdfUrl="https://arxiv.org/pdf/2301.00001.pdf"
```

## 📊 Expected Output

### Spring Boot Response (Immediate)

```json
{
  "message": "Summarization job submitted successfully",
  "paperId": "123e4567-e89b-12d3-a456-426614174000",
  "correlationId": "987fcdeb-51a2-43d1-9f4e-123456789abc",
  "pdfUrl": "https://arxiv.org/pdf/2301.00001.pdf",
  "status": "SUBMITTED"
}
```

### Spring Boot Logs (After ~12 seconds)

```
📄 Received summarization result for paper ID: 123e4567-e89b-12d3-a456-426614174000
🔗 Correlation ID: 987fcdeb-51a2-43d1-9f4e-123456789abc
📝 Summary length: 1247 characters
✅ Summary preview: This is a simulated summary for paper 123e4567-e89b-12d3-a456-426614174000...
🎯 Summarization processing completed successfully!
```

### FastAPI Logs

```
📥 Received summarization request: {'paperId': '123e4567-e89b-12d3-a456-426614174000', ...}
🔄 Processing paper 123e4567-e89b-12d3-a456-426614174000 from https://arxiv.org/pdf/2301.00001.pdf
⏳ Simulating AI processing for 12 seconds...
📤 Sent completion event for paper 123e4567-e89b-12d3-a456-426614174000
✅ Successfully processed summarization for paper 123e4567-e89b-12d3-a456-426614174000
```

## 🔧 Configuration

### Spring Boot Configuration

File: `ScholarAI-Backend-Springboot/src/main/resources/application-dev.yml`

```yaml
scholarai:
  rabbitmq:
    exchange: scholarai.exchange
    summarization:
      queue: scholarai.summarization.queue
      routing-key: scholarai.summarization
      completed-queue: scholarai.summarization.completed.queue
      completed-routing-key: scholarai.summarization.completed
```

### FastAPI Configuration

Environment variables:

- `RABBITMQ_HOST=localhost`
- `RABBITMQ_PORT=5672`
- `RABBITMQ_USER=scholar`
- `RABBITMQ_PASSWORD=scholar123`

## 🐛 Troubleshooting

### Common Issues

1. **RabbitMQ Connection Failed**

   - Check if RabbitMQ is running: `sudo systemctl status rabbitmq-server`
   - Verify credentials: `scholar/scholar123`
   - Check port accessibility: `telnet localhost 5672`

2. **No Messages Received**

   - Verify queue names match between Spring Boot and FastAPI
   - Check RabbitMQ Management UI: `http://localhost:15672`
   - Ensure both services are connected to the same exchange

3. **FastAPI Consumer Not Starting**
   - Install dependencies: `poetry install`
   - Check Python version: `python --version` (should be 3.10+)
   - Verify import paths in consumer_runner.py

### Monitoring

1. **RabbitMQ Management UI**: `http://localhost:15672`

   - Username: `scholar`
   - Password: `scholar123`

2. **Spring Boot Actuator**: `http://localhost:8080/actuator/health`

3. **FastAPI Health**: `http://localhost:8001/health`

## 🔄 Message Flow Details

### Request Message (Spring Boot → FastAPI)

```json
{
  "paperId": "uuid-string",
  "pdfUrl": "https://example.com/paper.pdf",
  "correlationId": "uuid-string"
}
```

### Response Message (FastAPI → Spring Boot)

```json
{
  "paperId": "uuid-string",
  "summaryText": "Generated summary content...",
  "correlationId": "uuid-string"
}
```

## 🎯 Next Steps

This demo establishes the basic communication backbone. Future enhancements:

1. **Error Handling**: Dead letter queues, retry mechanisms
2. **Monitoring**: Metrics, health checks, alerting
3. **Scaling**: Multiple consumers, load balancing
4. **Security**: Message encryption, authentication
5. **Real AI Integration**: Replace mock processing with actual AI models
6. **Database Integration**: Persist job status and results
7. **User Notifications**: WebSocket updates, email notifications

## 📝 Notes

- The artificial delay (12 seconds) simulates real AI processing time
- Correlation IDs enable request-response tracking
- The system is designed to be asynchronous and scalable
- All queues are durable to survive service restarts
