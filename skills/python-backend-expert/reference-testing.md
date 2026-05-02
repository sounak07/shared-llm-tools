# Python backend testing and error patterns

## Pytest fixtures (async app)

```python
import pytest
from httpx import ASGITransport, AsyncClient

@pytest.fixture
async def client(app):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

@pytest.fixture
async def db_session():
    async with async_session() as session:
        yield session
        await session.rollback()
```

*(Adjust transport for your ASGI stack; older examples used `AsyncClient(app=app)` — prefer `ASGITransport` for current httpx.)*

## Parametrize

```python
@pytest.mark.parametrize("email,valid", [
    ("test@example.com", True),
    ("invalid", False),
    ("", False),
    ("a@b.c", True),
])
def test_validate_email(email: str, valid: bool):
    assert validate_email(email) == valid
```

## Factory (factory_boy)

```python
from factory import Factory, Faker

class UserFactory(Factory):
    class Meta:
        model = User
    email = Faker("email")
    name = Faker("name")
    is_active = True

user = UserFactory()
inactive_user = UserFactory(is_active=False)
```

## Mocking async

```python
from unittest.mock import AsyncMock, patch

@pytest.mark.asyncio
async def test_create_user_sends_email():
    with patch("app.services.send_email", new_callable=AsyncMock) as mock_send:
        user = await create_user(UserCreate(email="test@example.com"))
        mock_send.assert_awaited_once()
```

## Custom exception hierarchy

```python
class AppError(Exception):
    def __init__(self, message: str, code: str = "UNKNOWN"):
        self.message = message
        self.code = code
        super().__init__(message)

class NotFoundError(AppError):
    def __init__(self, resource: str, id: int):
        super().__init__(f"{resource} with id {id} not found", "NOT_FOUND")

class ValidationError(AppError):
    def __init__(self, field: str, message: str):
        super().__init__(message, f"VALIDATION_{field.upper()}")
```

## Result pattern

```python
from dataclasses import dataclass
from typing import Generic, TypeVar

T = TypeVar("T")
E = TypeVar("E")

@dataclass
class Ok(Generic[T]):
    value: T

@dataclass
class Err(Generic[E]):
    error: E

type Result[T, E] = Ok[T] | Err[E]

async def get_user(user_id: int) -> Result[User, str]:
    user = await db.get(User, user_id)
    if user is None:
        return Err("User not found")
    return Ok(user)

match await get_user(123):
    case Ok(user):
        print(f"Found: {user.name}")
    case Err(error):
        print(f"Error: {error}")
```

*(Use `Result = Ok[T] | Err[E]` on older Python if `type` aliases are unavailable.)*

## TypeVar helper (FastAPI-style)

```python
from typing import TypeVar

T = TypeVar("T", bound=BaseModel)

async def get_or_404(db: AsyncSession, model: type[T], id: int) -> T:
    obj = await db.get(model, id)
    if obj is None:
        raise HTTPException(status_code=404)
    return obj
```

## Protocol repository

```python
from typing import Protocol

class Repository(Protocol):
    async def get(self, id: int) -> Model | None: ...
    async def create(self, data: dict) -> Model: ...
    async def delete(self, id: int) -> bool: ...
```
