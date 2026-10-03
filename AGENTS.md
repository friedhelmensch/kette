# Development workflow

Always write tests first when doing development.

For each behavior change, write a meaningful test, run it and observe the expected
failure, then implement the smallest change that makes it pass. Refactor with the
tests passing. Include relevant build and test results when reporting progress.

Use deterministic unit tests for application logic and appropriate UI tests for
user-facing flows. Keep live Apple services and GPS out of deterministic tests
through injectable boundaries; validate their integration separately.
