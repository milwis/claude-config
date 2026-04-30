# Exception hierarchy — implementation reference

Used by `new-project` Phase 7. The pattern is universal; the example below is Python — adapt to your stack (TypeScript classes, PHP \Exception subclasses, Go error wrappers).

## Pattern (every language)

```
ProjectBaseError
├── ExternalServiceError   # outside our control
│   ├── ConnectionError
│   ├── APIError
│   └── RateLimitError
├── ValidationError        # bad input/config
│   ├── InvalidConfigError
│   └── MissingFieldError
├── SecurityError          # auth/authz failures
│   ├── AuthenticationError
│   └── AuthorizationError
└── DomainError            # business logic violations
```

## Why a hierarchy

- **Catch by category** — `except ExternalServiceError` retries; `except ValidationError` returns 400; `except SecurityError` returns 401/403 + alerts.
- **Carry context as data** — exceptions are not strings, they're typed records with the data needed to handle / log them.
- **Boundary translation** — leaf exceptions never leak across module boundaries unmodified; convert to higher-level when crossing layers.

## Python implementation

```python
class ProjectBaseError(Exception):
    def __init__(self, message: str = "", **kwargs):
        self._context = kwargs
        for key, value in kwargs.items():
            setattr(self, key, value)
        ctx_str = " | ".join(f"{k}={v}" for k, v in kwargs.items())
        full_message = f"{message} [{ctx_str}]" if message and kwargs else message or ctx_str
        super().__init__(full_message)

    @property
    def context(self) -> dict:
        return dict(self._context)


class ExternalServiceError(ProjectBaseError): pass
class ConnectionError(ExternalServiceError): pass
class APIError(ExternalServiceError): pass
class RateLimitError(ExternalServiceError): pass

class ValidationError(ProjectBaseError): pass
class InvalidConfigError(ValidationError): pass
class MissingFieldError(ValidationError): pass

class SecurityError(ProjectBaseError): pass
class AuthenticationError(SecurityError): pass
class AuthorizationError(SecurityError): pass

class DomainError(ProjectBaseError): pass
```

## Use site

```python
try:
    process_order(order_id=123)
except DomainError as exc:
    logger.error("Order rejected", **exc.context, exc_info=True)
    return BadRequestResponse(reason=str(exc))
except ExternalServiceError as exc:
    logger.warning("Will retry", **exc.context)
    raise  # let retry decorator handle it
```

## TypeScript adaptation

```typescript
export class ProjectBaseError extends Error {
  constructor(message: string, public readonly context: Record<string, unknown> = {}) {
    const ctx = Object.entries(context).map(([k, v]) => `${k}=${v}`).join(' | ');
    super(message && Object.keys(context).length ? `${message} [${ctx}]` : (message || ctx));
    Object.setPrototypeOf(this, new.target.prototype);
    this.name = new.target.name;
  }
}

export class ExternalServiceError extends ProjectBaseError {}
export class APIError extends ExternalServiceError {}
// ... etc
```

## PHP adaptation

```php
abstract class ProjectBaseException extends \RuntimeException {
    public function __construct(string $message = '', public readonly array $context = []) {
        $ctx = implode(' | ', array_map(fn($k, $v) => "$k=$v", array_keys($context), $context));
        parent::__construct($message && $context ? "$message [$ctx]" : ($message ?: $ctx));
    }
}

abstract class ExternalServiceException extends ProjectBaseException {}
final class APIException extends ExternalServiceException {}
// ... etc
```

## Tests for hierarchy (Phase 7 deliverable)

- Each leaf exception can be caught by its mid-level group
- Each mid-level can be caught by `ProjectBaseError`
- Context dictionary survives serialization
- Message includes context when both present
