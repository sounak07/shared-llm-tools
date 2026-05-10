---
name: microservice-best-practices
description: >-
  Guides production-grade Python microservice design and review (hexagonal layout,
  FastAPI, SQLAlchemy 2 async, DI composition root, async messaging with DLT,
  resilience, structured logging/tracing, testcontainers, Docker, Helm + Argo,
  GitOps CI/CD, mkdocs, cookiecutter templates). Use when bootstrapping or
  refactoring microservices, reviewing service architecture, or when the user
  mentions hexagonal layout, composition root, UoW, Alembic, async consumers,
  dead-letter topics, idempotent handlers, ExternalSecret, pre-sync Job, or
  platform consistency.
disable-model-invocation: true
---

# Microservice best practices skill

## When to use

- Designing, scaffolding, or refactoring a **Python ≥ 3.12** microservice (FastAPI + async SQLAlchemy + optional async consumer).
- Reviewing project structure, DI, DB layer, HTTP/messaging, observability, tests, Docker/Helm, or CI/CD.
- The user asks for **platform-consistent** service layout, Makefile/CI patterns, Helm conventions, or template scaffolding.

## How to apply

1. **Default depth**: answer from this file's section that matches the topic (the section names mirror the source doc).
2. **Full detail / code snippets**: open [reference.md](reference.md) for the complete playbook, including longer code examples.
3. Always **tie recommendations to layer boundaries** (`api` → `application` → `domain` ← `infra`) and prefer **concrete, reviewable defaults** below over vague "best practices" language.

---

## §1 Optimal project layout (hexagonal)

Organize by **role**, not file type. `domain/` has zero framework or I/O imports. `infra/` is the only place that talks to the outside world. `application/` orchestrates use cases and owns the dependency graph. `api/` and `consumers/` are thin transport layers calling into `application/`.

```text
service/
├── pyproject.toml              # single source for deps, tooling, linters
├── Dockerfile                  # multi-stage: base -> builder -> prod -> dev
├── compose.yml                 # local dev stack (db, broker, registry, ui)
├── Makefile                    # one-line entry points for every workflow
├── alembic.ini                 # database migration config
├── uvicorn_logging_conf.ini    # structured-JSON logging config
├── .env.example                # documents every required env var
├── chart-<service>/            # Helm chart (deployment, consumer, jobs)
├── migrations/alembic/         # versioned schema migrations
├── scripts/                    # ad-hoc operational scripts
├── docs/                       # mkdocs site (optional)
├── tests/
│   ├── conftest.py             # global fixtures + env-var defaults
│   └── <module>/
│       ├── unit/               # mirror src tree
│       └── integration/        # docker-backed tests
└── <module>/
    ├── main.py                 # ASGI entrypoint, only top-level wiring
    ├── api/v1/<resource>/      # versioned HTTP routers
    ├── application/            # orchestration layer
    │   ├── app.py              # FastAPI factory + lifespan
    │   ├── bootstrap.py        # one-time process bootstrap (tracing etc.)
    │   ├── config.py           # typed Settings (pydantic-settings)
    │   ├── depends.py          # framework-agnostic Depends shim
    │   ├── di/main.py          # composition root
    │   ├── exception_handlers.py
    │   ├── middleware.py
    │   └── usecases/           # one file per use case
    ├── consumers/              # async event handlers
    │   ├── generic.py          # broker wiring, decorators, lifecycle
    │   ├── <resource>_consumer.py
    │   └── events/             # event schemas (Pydantic)
    ├── domain/                 # pure business models (no I/O)
    └── infra/                  # outward-facing adapters
        ├── db/postgresql/
        │   ├── database.py     # engine + session factory
        │   ├── models.py       # ORM base + mixins
        │   ├── tables/         # concrete table definitions
        │   ├── repositories/   # data-access patterns
        │   ├── mappers/        # ORM <-> domain translation
        │   └── uow.py          # Unit of Work
        ├── exceptions/         # typed errors + handlers
        └── utils/              # cross-cutting helpers (retry, json)
```

---

## §2 Dependency & tooling stack

| Concern              | Tool                                            |
| -------------------- | ----------------------------------------------- |
| Package manager      | `uv` (fast, lockfile-first, deterministic)      |
| Build backend        | `hatchling`                                     |
| Linting & formatting | `ruff` (replaces flake8 + isort)                |
| Testing              | `pytest` + `pytest-asyncio` + `pytest-cov`      |
| Integration tests    | `testcontainers` (real services in Docker)      |
| HTTP framework       | `FastAPI`                                       |
| ORM / migrations     | `SQLAlchemy 2.x async` + `alembic`              |
| JSON serialization   | `orjson` (faster, native UUID etc.)             |
| Settings             | `pydantic-settings`                             |
| Retry                | `tenacity` wrapped behind a small facade        |
| Tracing              | OpenTelemetry / APM agent injected at runtime   |
| Structured logging   | `python-json-logger`                            |
| Feature flags        | `openfeature-sdk` (vendor-agnostic)             |

`pyproject.toml` highlights:
- `requires-python = ">=3.12"` (for `Self`, `StrEnum`, `match`).
- Use **dependency groups** (`dev`, `test`, `docs`) instead of separate `requirements-*.txt`.
- Configure tooling inline (`[tool.ruff]`, `[tool.pytest.ini_options]` with `asyncio_mode = "strict"` and the `integration` marker).
- Multiple `[[tool.uv.index]]` entries with `explicit = true` for private registries.

---

## §3 Settings — typed, singleton, override-friendly

- Single `Settings(BaseSettings)` class; `model_config = SettingsConfigDict(env_file=".env", extra="allow", case_sensitive=True)`.
- `get_settings()` returns a process-wide singleton (`_instance: ClassVar[Self | None] = None`).
- `override(**kwargs)` `@contextmanager` for tests — restores original `_instance`.
- `@computed_field` for derived values (e.g. DB DSNs).
- `StrEnum` for environments (`DEVELOPMENT`, `STAGING`, `PROD`) so comparisons are type-checked.
- **Fail fast** at startup on misconfiguration.

---

## §4 Composition root — one place for the object graph

`application/di/main.py` builds and exposes every dependency. Everything else only **imports** from this module.

- Prefix every provider with `di_get_` (trivial to grep).
- `@lru_cache` for process-wide singletons (`Settings`, `Logger`, DB).
- Async generators for per-request resources (sessions, transactions) so cleanup is guaranteed.
- Broker / publisher factories live here too — producers and consumers share wiring.

**Framework-agnostic `Depends` shim** (`application/depends.py`): swap `from fastapi import Depends` and `from streaming_lib import Depends` based on `USE_STREAM_DEPENDS` so use cases run unchanged under HTTP and streaming runtimes.

---

## §5 Domain & event modelling

- Domain models are **plain Pydantic `BaseModel`s** — no ORM, no I/O.
- Events extend a small base adding `event_uuid`, `event_type`, `event_timestamp`, plus a `from_domain_object(cls, obj)` factory that does `**obj.model_dump()` + ids/timestamps. Wire format is **derived from the domain object** — eliminates whole class of mapping bugs.

---

## §6 Database layer

### 6.1 Async engine wrapper (singleton)
- `create_async_engine` with **explicit** `pool_size`, `max_overflow`, `pool_recycle` (prevents stale connections behind LBs) — reviewable in code, not buried in env vars.
- `json_serializer=partial(OrjsonHelpers.serialize, return_bytes=False)` for parity with wire format.
- `async_sessionmaker(..., expire_on_commit=False)`.
- `await engine.dispose()` in `shutdown()`.

### 6.2 Declarative base
- Apply a fixed naming convention so migrations have stable identifiers:
  ```python
  convention = {
    "ix": "ix__%(table_name)s__%(all_column_names)s",
    "uq": "uq__%(table_name)s__%(all_column_names)s",
    "ck": "ck__%(table_name)s__%(constraint_name)s",
    "fk": "fk__%(table_name)s__%(all_column_names)s__%(referred_table_name)s",
    "pk": "pk__%(table_name)s",
  }
  ```
- `type_annotation_map` for `datetime` (timezone=True), `UUID`, `dict→JSONB`, `list[str]→ARRAY`.
- Mixins: `UUIDPrimaryKeyMixin`, `TimestampMixin` (DB-side `server_default=func.now()` + `onupdate`), `DeletedMixin`. Compose via `BaseSQLModel(TimestampMixin, UUIDPrimaryKeyMixin, DeletedMixin, Base)`.
- Wrap PostgreSQL dialect imports in `try/except` for **SQLite fallback** in tests.

### 6.3 Unit of Work
- `AsyncUnitOfWork(AsyncContextManager)` opens `session.begin()`; on exception → rollback + raise; on success → commit (rollback on commit failure); always close session.
- Use cases stay readable: `async with uow: await repo.save(entity); await publisher.publish(event)`.

### 6.4 Migrations (Alembic, async-aware)
- `migrations/alembic/env.py` reads the DSN from the **same `Settings`** — app and migrations cannot drift.
- Filename template includes timestamp: `2025_05_02_12_30-<rev>_<slug>`.
- `[post_write_hooks]` runs `ruff --fix` on generated revisions.
- Migrations are run as a **Helm pre-sync Job**, never on app startup.

---

## §7 HTTP layer

### 7.1 App factory + `lifespan`
- Build the app **inside `create_app()`** (never module-level).
- `@asynccontextmanager async def lifespan(app)`: start broker → `yield` → stop broker, dispose DB.
- Versioned URL prefixes (`/api/v1/...`) **from day one**.
- Mount an OpenAPI viewer (Scalar / Swagger UI).
- Add `/` and `/health` for liveness/readiness probes.

### 7.2 Routers
Tiny: validate input → call use case → return Pydantic model. **No business logic** in router files.

### 7.3 Custom request-logging middleware
Emit structured JSON access logs with platform-indexable fields: `host`, `x-forwarded-for`, `method`, `path`, `status`, `duration`. Log shippers do zero parsing.

### 7.4 Exception handling
Single registry passed to `FastAPI(exception_handlers=...)`:
```python
error_handlers_map = {
    AppError: app_error_handler,
    PydanticValidationError: pydantic_handler,
    RequestValidationError: pydantic_handler,
    Exception: default_exception_handler,    # catch-all -> safe 500
}
```
Typed error hierarchy with status codes baked in:
- `AppError` (abstract, 500 default; `message`, `error_code`, `status_code`, `detail`).
- `ValidationError` 400, `UnauthorizedError` 401, `NotFoundError` 404, `InternalError` 500.
Handlers always **log with `exc_info`** before returning a sanitized body. Use `ORJSONResponse` everywhere.

---

## §8 Async messaging

### 8.1 Broker wiring
Broker, serializer, publisher factory live in the composition root. Subscribers and HTTP routers depend on the **same** factory.

### 8.2 Idempotent consumers (exactly-once-effect on at-least-once delivery)
1. Use a durable workflow library (DBOS, Temporal, …) or implement the inbox pattern.
2. Derive workflow id from `(topic, partition, group_id, offset)` — broker's natural idempotency key.
3. Wrap the actual handler in a workflow; redeliveries hit the same id and short-circuit.

### 8.3 Dead-letter topics — explicit & observable
- DLT middleware republishes to `<source-topic>-dlt` with headers: `x-dlt-reason`, `x-dlt-original-topic`, `x-dlt-original-exception`.
- **Startup hook validates** that every subscribed topic has a sibling `*-dlt` topic — misconfiguration fails immediately, not at first error.
- Three entry points to DLT: raise typed `MessageUnprocessable`, call `send_to_dlt(...)` and return, or use a decorator that converts terminal failures (e.g. exhausted retries) into DLT routes.

### 8.4 Subscriber decorator pipeline
Stack one-thing decorators:
```python
@broker.subscriber("topic-a", decoder=serializer.decode, group_id=GROUP_ID)
@broker.publisher("topic-b", middlewares=[serializer.encoder("topic-b")])
@terminal_failures_to_dlt
async def handler(event: ResourceCreated, message: Annotated[StreamMessage, Context()]):
    return await use_case(event, message)
```

---

## §9 Resilience — `Retrier` facade

Wrap `tenacity` so every call site looks the same:
- Three usage modes: **callable** (`await retrier(func, *args)`), **decorator** (`@retrier.as_decorator()`), **context manager** (`async for attempt in retrier.context(): with attempt: ...`).
- Typed `RetryableError` to **opt in** from business code; preserve original exception via `__cause__`.
- Configurable `max_attempts`, `multiplier`, `min_wait`, `max_wait`, `retry_exceptions`, `logger`, `log_level_before_sleep/after`, `reraise`.
- Tune wait windows by call type:
  - Internal APIs: `min=1, max=10`
  - External services: `min=2, max=60`
  - Background jobs: `min=5, max=300`

---

## §10 Logging & observability

### 10.1 Structured JSON logs
Configure via mounted INI:
```ini
[formatter_json]
class=pythonjsonlogger.json.JsonFormatter
format=%(asctime)s %(levelname)s [%(name)s] [%(filename)s:%(lineno)d] [trace_id=%(trace_id)s span_id=%(span_id)s] - %(message)s
```
- Access logs → `stdout`; app/error logs → `stderr`.
- Per-library loggers (`uvicorn`, `streaming-lib.kafka`, …) so noise is tunable.
- Inject correlation IDs via `asgi-correlation-id` for cross-service traces.

### 10.2 Distributed tracing
Run under an APM/OTel auto-instrumentation wrapper. A small `application/bootstrap.py` toggles trace options **once** at process start (`trace_query_string`, `trace_headers`).

### 10.3 Metrics & log shipping at deploy time
Helm attaches log-source annotations + APM env vars on every Deployment / Consumer / Job — every workload is auto-discoverable and end-to-end correlated:
```yaml
labels:
  tags.<vendor>.com/env: <env>
  tags.<vendor>.com/service: <fullname>-api
  tags.<vendor>.com/version: {{ .Values.image.tag }}
annotations:
  ad.<vendor>.com/<container>.logs: '[{"source": "python"}]'
env:
  - { name: TRACE_LOGS_INJECTION, value: "true" }
  - { name: TRACE_LOGS_ENABLED,    value: "true" }
```

---

## §11 Testing strategy

- **Mirror** the src tree under `tests/<module>/unit/...` and `tests/<module>/integration/...`.
- Global `tests/conftest.py` sets safe env defaults (`POSTGRES_*`, `LOGGING_CONFIG`) so tests never depend on the dev's local `.env`.
- `pytest-asyncio` in **strict** mode; isolate units with `MagicMock`/`AsyncMock`; cover happy/edge/explicit-failure paths.
- Integration tests use **`testcontainers`** behind `@pytest.mark.integration`. Standard fixtures:
  - `kafka_container` (`module` scope) using `KafkaContainer("confluentinc/cp-kafka:7.6.0")`.
  - `managed_topics` (parametrized indirectly) creates and tears down topics around each test.
- Run locally `uv run pytest`; skip docker tests with `uv run pytest -m "not integration"`.
- Coverage: `make test-cov` (terminal), `make test-cov-html` (browsable). Surface JUnit XML in CI.

---

## §12 Build & containerization

### 12.1 Multi-stage `Dockerfile`
```text
FROM python:3.12-slim AS base
FROM base       AS builder    # uv install, BuildKit cache
FROM builder    AS prod       # copies code, non-root, traced uvicorn
FROM prod       AS dev        # adds dev/test groups, --reload
```
- `--mount=type=cache,target=/root/.cache/uv` to reuse package cache across builds.
- `--mount=type=bind,source=uv.lock,...` to avoid baking the lockfile into runtime.
- `UV_COMPILE_BYTECODE=1`, `UV_LINK_MODE=copy` for reproducible builds.
- Pin `uv` via `COPY --from=ghcr.io/astral-sh/uv:<version>`.

### 12.2 Local `compose.yml`
Bundle every backing service (DB, broker, schema registry, broker UI). DB has a healthcheck and other services use `depends_on: condition: service_healthy`. Single command brings the stack up.

---

## §13 Makefile — one verb per workflow

```text
test, test-cov, test-cov-html
format, lint, lint-fix
up, up-interactive, wipe
migrate-up, migrate-down, add-migration
new-kafka-topic, new-kafka-message, dump-kafka-topic
new-schema-local, new-schema-staging
run-consumer, docs
```
Every CI job and onboarding doc references the same targets.

---

## §14 CI/CD

Pipeline shape: `generate -> test (unit + integration) -> build -> deploy`.
- `generate` only when the repo is a template; otherwise pipeline starts at `test`.
- Unit and integration jobs run **in parallel**; integration uses `docker:dind` + `testcontainers`.
- Build with **Kaniko** (no Docker daemon); tag images with the git tag.
- Deploy = register the app in **GitOps** tooling (Argo etc.); cluster reconciles. Never `kubectl apply` from CI.
- Quality gates: `ruff format --check` + `ruff check` non-negotiable; every test job exports JUnit XML; production deploys gated by tag patterns (e.g. `^\d+\.\d+\.\d+-prod$`).

---

## §15 Helm chart conventions

### 15.1 One chart, multiple workloads
```text
templates/
  deployment.yml         # API
  consumer.yml           # streaming consumer (optional)
  mcp-deployment.yml     # extra protocol surface (optional)
  service.yml
  ingress.yml
  external_secret.yml    # pull secrets from cloud secret manager
  migration.yml          # pre-sync Job
```

### 15.2 Secret management
Never bake secrets into the chart. `ExternalSecret` pulls a JSON blob from the cloud secret manager and is mounted via `envFrom: - secretRef: { name: {{ .Values.secrets_json.name }}-k8s }`.

### 15.3 Migrations as a pre-sync Job
```yaml
annotations:
  argocd.argoproj.io/hook: "PreSync"
  argocd.argoproj.io/sync-wave: "1"
  argocd.argoproj.io/hook-delete-policy: "HookSucceeded"
```
Schema migrates **before** new pods roll — no startup races, no N-replica concurrent migrations.

### 15.4 Per-workload labels
Same APM/log labels (`env`, `service`, `version`, `component=api|consumer|migration`) on every workload so dashboards/SLOs work out of the box.

### 15.5 Environment separation
`values.yaml` is the production baseline; `staging.yaml` overrides. Per-env ingress/host parameters are passed by the deploy job, not committed.

---

## §16 Documentation

- `mkdocs.yml` + Material theme; ship docs alongside the service via `make docs`.
- Mermaid diagrams render natively (architecture / sequence).
- Long, opinionated `README.md` covers prerequisites, setup, every common task, and pointers into deeper docs.
- `.env.example` is the **canonical list** of every env var — update on every new setting.

---

## §17 Cookiecutter / template pattern

When >2 services share the same shape, lift them into a template:
- `cookiecutter.json` exposes feature toggles (`add_kafka_consumer`, `add_documentation`, `add_mcp_server`, …).
- Use Jinja conditionals inside files (`{% if cookiecutter.add_kafka_consumer == "y" %} … {% endif %}`) so generated projects only contain what they need.
- `hooks/post_gen_project.py` removes empty directories and renames the package directory to a Python-safe identifier.
- The template repo runs the same CI on a generated project on every push — the template never silently breaks.

---

## §18 Quick-adoption checklist

When bootstrapping a new service, do these in order:

1. Copy the **project layout** (`api`, `application`, `consumers`, `domain`, `infra`, mirrored `tests`).
2. Pin Python ≥ 3.12; configure `uv`, `ruff`, `pytest` in `pyproject.toml`.
3. Create the typed `Settings` singleton + `.env.example`.
4. Write the composition root (`application/di/main.py`) and the FastAPI factory with `lifespan`.
5. Add the SQLAlchemy `Base` (naming convention + mixins), the UoW, and wire Alembic.
6. Add the typed error hierarchy and the global exception handler map.
7. Add the JSON logging config, request-logging middleware, and tracing bootstrap.
8. Add `Retrier` and `RetryableError`.
9. (If async) Wire broker + serializer + DLT + idempotency in the composition root; stack the subscriber decorators.
10. Write the multi-stage `Dockerfile`, `compose.yml`, and `Makefile` with the standard verbs.
11. Author the Helm chart (deployment + migration job + ExternalSecret + consumer if applicable), all with consistent observability labels.
12. Add `tests/conftest.py` with safe env defaults and split tests into `unit/` and `integration/` (latter behind a marker).
13. Wire CI: lint, unit test, integration test (docker-in-docker), Kaniko build, GitOps-driven deploy.
14. Document every workflow in `README.md` and reference the Makefile targets.

---

## Reference map

For full prose and longer code samples see [reference.md](reference.md):

| Topic                             | reference.md |
| --------------------------------- | ------------ |
| Project layout                    | §1           |
| Tooling stack / `pyproject`       | §2           |
| Settings                          | §3           |
| Composition root / `Depends` shim | §4           |
| Domain & events                   | §5           |
| Database / UoW / migrations       | §6           |
| HTTP layer                        | §7           |
| Async messaging                   | §8           |
| Retry                             | §9           |
| Logging & observability           | §10          |
| Testing                           | §11          |
| Docker & compose                  | §12          |
| Makefile                          | §13          |
| CI/CD                             | §14          |
| Helm                              | §15          |
| Docs                              | §16          |
| Cookiecutter template             | §17          |
| Full checklist                    | §18          |
