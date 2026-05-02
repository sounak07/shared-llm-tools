---
name: python-backend-expert
description: >-
  Applies expert Python backend patterns for Django, FastAPI, Flask-style APIs,
  async I/O, SQLAlchemy 2.0, Pydantic validation, Django ORM, and pytest.
  Use when editing Python backend or API code, when requirements.txt or
  pyproject.toml mentions django, fastapi, flask, sqlalchemy, pydantic, or uvicorn,
  when working under api/, backend/, server/, apps/, or with routes and ORM models,
  or when the user mentions N+1 queries, Depends injection, asyncio, or migrations.
---

# Python backend expert

## When to prioritize

1. Confirm stack (Django vs FastAPI vs Flask) from project files; prefer framework-native patterns over generic advice.
2. Prefer type hints, explicit validation (Pydantic / forms), and clear error boundaries (`HTTPException` / custom exceptions wired to handlers).
3. Optimize data access early: **`select_related` / `prefetch_related`**, **`selectinload` / `joinedload`**, **`exists()`**, **`F()`** / **`bulk_create`**, transactions where multiple writes must succeed together.

---

## 1. FastAPI

### Pydantic models

```python
from pydantic import BaseModel, EmailStr, Field, field_validator

class UserCreate(BaseModel):
    email: EmailStr
    name: str = Field(..., min_length=2, max_length=100)
    password: str = Field(..., min_length=8)

    @field_validator("name")
    @classmethod
    def name_must_not_be_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Name cannot be empty")
        return v.strip()

    model_config = {"str_strip_whitespace": True}
```

### Dependency injection

```python
from typing import Annotated
from fastapi import Depends, HTTPException

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    user = await verify_token(token, db)
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user

CurrentUser = Annotated[User, Depends(get_current_user)]
DB = Annotated[AsyncSession, Depends(get_db)]

@app.get("/me")
async def get_me(user: CurrentUser, db: DB):
    return user
```

### Background tasks

```python
from fastapi import BackgroundTasks

@app.post("/users/")
async def create_user(
    user: UserCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    db_user = await crud.create_user(db, user)
    background_tasks.add_task(send_welcome_email, user.email)
    return db_user
```

### Exception handling

```python
from fastapi import HTTPException
from fastapi.responses import JSONResponse

class AppException(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.code = code
        self.message = message
        self.status_code = status_code

@app.exception_handler(AppException)
async def app_exception_handler(request, exc: AppException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"code": exc.code, "message": exc.message},
    )
```

### Lifespan (startup/shutdown)

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    await database.connect()
    yield
    await database.disconnect()

app = FastAPI(lifespan=lifespan)
```

---

## 2. Django ORM

### Avoid N+1

```python
# BAD — N+1
users = User.objects.all()
for user in users:
    print(user.profile.bio)

# GOOD — FK forward
users = User.objects.select_related("profile").all()

# GOOD — M2M / reverse FK
posts = Post.objects.prefetch_related("tags", "comments").all()
```

### Atomic counters

```python
from django.db.models import F

# BAD — race
article = Article.objects.get(pk=1)
article.views += 1
article.save()

# GOOD
Article.objects.filter(pk=1).update(views=F("views") + 1)
```

### `Q` objects

```python
from django.db.models import Q

users = User.objects.filter(Q(is_staff=True) | Q(is_superuser=True))
users = User.objects.filter(
    Q(email__endswith="@company.com") & (Q(is_active=True) | Q(is_staff=True))
)
```

### Existence and bulk writes

```python
# Prefer exists()
if User.objects.filter(email=email).exists():
    ...

# Prefer bulk_create for many rows (mind M2M and signals constraints)
User.objects.bulk_create([User(**data) for data in users_data])
```

### Transactions

```python
from django.db import transaction

@transaction.atomic
def transfer_funds(from_account, to_account, amount):
    from_account.balance = F("balance") - amount
    from_account.save(update_fields=["balance"])
    to_account.balance = F("balance") + amount
    to_account.save(update_fields=["balance"])
```

(After `save()` with `F()`, re-fetch if you need the updated Python-side value.)

---

## 3. SQLAlchemy 2.0

### Declarative + relationships

```python
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy import ForeignKey

class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(unique=True, index=True)
    name: Mapped[str]
    is_active: Mapped[bool] = mapped_column(default=True)
    posts: Mapped[list["Post"]] = relationship(back_populates="author")
```

### Async select

```python
from sqlalchemy import select

async def get_user(db: AsyncSession, user_id: int) -> User | None:
    stmt = select(User).where(User.id == user_id)
    result = await db.execute(stmt)
    return result.scalar_one_or_none()
```

### Eager loading

```python
from sqlalchemy.orm import selectinload, joinedload

stmt = select(User).options(
    selectinload(User.posts),
    joinedload(User.profile),
)
```

### Pagination

```python
from sqlalchemy import func, select

async def get_users_paginated(
    db: AsyncSession, page: int = 1, per_page: int = 20
) -> tuple[list[User], int]:
    count_stmt = select(func.count()).select_from(User)
    total = await db.scalar(count_stmt)
    stmt = select(User).offset((page - 1) * per_page).limit(per_page)
    result = await db.execute(stmt)
    return list(result.scalars().all()), int(total or 0)
```

---

## 4. Async I/O

```python
import asyncio

# Parallel independent I/O
async def get_dashboard_data(user_id: int) -> dict:
    user, posts, notifications = await asyncio.gather(
        get_user(user_id),
        get_user_posts(user_id),
        get_notifications(user_id),
    )
    return {"user": user, "posts": posts, "notifications": notifications}

# Timeout (3.11+)
async def fetch_with_timeout(url: str, timeout: float = 5.0):
    async with asyncio.timeout(timeout):
        async with httpx.AsyncClient() as client:
            return await client.get(url)

# Concurrency limit
_semaphore = asyncio.Semaphore(10)

async def fetch_limited(url: str):
    async with _semaphore:
        return await fetch(url)

# Structured concurrency (3.11+)
async def process_all(items: list):
    async with asyncio.TaskGroup() as tg:
        for item in items:
            tg.create_task(process_item(item))
```

---

## 5. Type hints

- Prefer **`X | None`** (3.10+), **`list[str]`**, concrete return types on public APIs.
- Use **`TypeVar`** / **`Protocol`** where generics or duck-typing clarifies repositories and services.

---

## 6. Errors and results

Prefer a **small hierarchy** of domain errors mapped to HTTP or messages, or a **`Result`-style** union for explicit control flow where exceptions would obscure errors (see [reference-testing.md](reference-testing.md)).

---

## 7. Quick reference

| Area        | Prefer |
|------------|--------|
| FastAPI    | Pydantic models + `Depends` |
| Django ORM | `select_related` / `prefetch_related` |
| SQLAlchemy | `Mapped[...]` + `selectinload` / `joinedload` |
| Async      | `asyncio.gather` for independent I/O |
| Typing     | `X \| None`, explicit generics |
| Validation | Pydantic (FastAPI) or Django Forms / serializers |
| DB writes  | `atomic`, `F()`, `bulk_create` where appropriate |
| Tests      | pytest fixtures + `parametrize`; see reference file |

---

## More

- Detailed **pytest**, **factory**, **mocking**, **`Result`** example: [reference-testing.md](reference-testing.md)
