# Development workflow

Keep it simple. Stick to the implementation plan and the current milestone.
Prefer straightforward code and the smallest useful design. Do not add speculative
features, convoluted abstractions, or exhaustive handling of hypothetical edge
cases. Test the required behavior and realistic failures; do not over-engineer.

Always write tests first when doing development.

For each behavior change, write a meaningful test, run it and observe the expected
failure, then implement the smallest change that makes it pass. Refactor with the
tests passing. Include relevant build and test results when reporting progress.

Use deterministic unit tests for application logic and appropriate UI tests for
user-facing flows. Keep live Apple services and GPS out of deterministic tests
through injectable boundaries; validate their integration separately.
