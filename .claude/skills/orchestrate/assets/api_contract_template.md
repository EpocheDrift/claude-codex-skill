# API Contract: {PROJECT_NAME}

> This document is the single source of truth for all inter-component interfaces.
> All agents MUST implement endpoints exactly as specified here.
> Do NOT modify this document after dispatch — re-plan first if changes are needed.

## Base Configuration

| Property | Value |
|----------|-------|
| Backend Base URL | `http://localhost:8000` |
| API Prefix | `/api` |
| Auth Method | {none / JWT / session} |
| Response Format | JSON |

## Shared Models

### {ModelName}

```json
{
  "id": "integer",
  "field_name": "string",
  "created_at": "ISO 8601 datetime string"
}
```

{Repeat for each shared model}

## Endpoints

### {Resource} Endpoints

#### {METHOD} {/api/path}

- **Description**: {What this endpoint does}
- **Auth Required**: {yes/no}

**Request**:
{For GET/DELETE — query parameters}
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `param` | string | yes | Description |

{For POST/PUT — request body}
```json
{
  "field": "type — description"
}
```

**Response** (`{status_code}`):
```json
{
  "field": "type — description"
}
```

**Error Responses**:
| Status | Body | When |
|--------|------|------|
| 404 | `{"detail": "Not found"}` | Resource doesn't exist |
| 422 | `{"detail": [...]}` | Validation error |

---

{Repeat for each endpoint}

## CORS Configuration

| Property | Value |
|----------|-------|
| Allowed Origins | `["http://localhost:3000"]` |
| Allowed Methods | `["GET", "POST", "PUT", "DELETE"]` |
| Allowed Headers | `["Content-Type", "Authorization"]` |

## Error Response Format (Global)

All error responses follow this structure:
```json
{
  "detail": "Human-readable error message"
}
```

## Endpoint Summary

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/... | ... |
| POST | /api/... | ... |
| PUT | /api/... | ... |
| DELETE | /api/... | ... |
