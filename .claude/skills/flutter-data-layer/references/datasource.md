# Repository / Remote data source (dio)

This document contains detailed guidance and an example implementation for remote-only data layers using `dio`.

Key points
- Use `dio` as the HTTP client.
- Centralize mapping of HTTP status codes to domain exceptions in the repository layer (or a dedicated mapper).
- Only throw mapped/domain errors (e.g., 401 -> InvalidCredentialsException). Rethrow other errors (preserve original error for higher-level handling).

Check [user_repository.dart](../templates/user_repository.dart) for a working example of a `UserRepositoryImpl` that implements these principles.

Notes
- Keep mapping logic small and explicit. Map only well-understood codes to domain errors; rethrow unexpected errors.
- For more complex mapping (token refresh, complex error bodies), centralize logic in an `ErrorMapper` or an interceptor.
- Document mapped errors in the repository interface so callers know what to expect.
- Write unit tests for the repository to verify correct mapping of status codes to exceptions and that unexpected errors are rethrown.
