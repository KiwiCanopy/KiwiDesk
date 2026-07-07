## Description

Brief summary of the change(s).

## Related Issue(s)

Closes #... (if applicable)

## Checklist

- [ ] I understand what this change does and have run it in
  the app to confirm it works as intended (see "How I
  verified" below and CONTRIBUTING.md → Using AI Assistants)
- [ ] Commits follow Conventional Commits format
  (see AGENTS.md §3)
- [ ] New behavior is tested (pure logic / layout code
  required)
- [ ] User-facing changes are documented in `docs/`
- [ ] No contradictions between code and docs
- [ ] `swift build && swift test && ./scripts/lint.sh`
  passes
- [ ] Release build passes: `swift build -c release`
- [ ] PR is focused; refactors separated from features

## How I verified

How you exercised this in the running app (steps, what you
saw). "Tests pass" is not enough for user-facing changes.

## Notes for Reviewer

(Any context that makes review easier, or open questions.)
