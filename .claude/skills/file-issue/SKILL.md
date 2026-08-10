---
description: File a KiwiDesk GitHub issue the way an agent must — render the template body by hand, then set the Type and the Priority/Effort issue fields the web form would have set for a human. Use whenever creating an issue with `gh`.
argument-hint: "[template: bug_report|feature_request|docs_report|collector|roadmap]"
---

File a GitHub issue for this repository. AGENTS.md §3 (Branching
& Pull Requests) owns the *why* — which template an issue takes,
and why its questions must be answered rather than skipped. This
skill owns the mechanics.

`gh issue create` does not apply the
`.github/ISSUE_TEMPLATE/*.yml` forms: the body observation is
AGENTS.md §3's (2026-08-02, `gh` 2.x — a `--body-file` filing
starts blank), and since the form never runs, its `type:` key
cannot apply either (inferred from that observation, not
separately tested — a filing that does land with a Type set is
news worth updating this line with). So reproduce by hand what
the web form gives a human for free.

## 1. Render the template

The template to use is `$ARGUMENTS` (pick per AGENTS.md §3 if
not given). Read `.github/ISSUE_TEMPLATE/$ARGUMENTS.yml` and
reproduce it:

- each `label:` becomes a `###` heading, in declared order,
  answered honestly — an internal issue answers the user-shaped
  questions from the dev machine, never drops them;
- the template's `title:` prefix goes on the title;
- any `labels:` the template declares go on the command line
  (`--label …`).

Then:

```sh
gh issue create --title "<prefix> <title>" --body-file <file>
```

## 2. Set the Type

Set it explicitly — `Bug`, `Feature`, or `Task`, matching the
template's `type:` value. `{owner}/{repo}` is literal: `gh`
resolves it from the current repository, so never substitute a
hand-written owner.

```sh
gh api -X PATCH repos/{owner}/{repo}/issues/<n> -f type=Bug
```

## 3. Set Priority and Effort

Skip this step for `collector` and `roadmap` issues — they
sequence work rather than being work, so they take a Type but no
Priority/Effort.

For everything else, set both single-select issue fields.
Discover the current field and option IDs rather than trusting a
stale copy (`:owner`/`:repo` are literal too — `gh` fills them):

```sh
gh api graphql -F owner=':owner' -F name=':repo' -f query='
  query($owner:String!, $name:String!) {
    repository(owner:$owner, name:$name) {
      issueFields(first:20) { nodes {
        ... on IssueFieldSingleSelect { id name
          options { id name } } } } } }'
```

Then, with the issue's node id
(`gh api repos/{owner}/{repo}/issues/<n> --jq .node_id`):

```sh
gh api graphql -f query='mutation($id:ID!){
  setIssueFieldValue(input:{issueId:$id, issueFields:[
    {fieldId:"<priority-field-id>",
     singleSelectOptionId:"<option-id>"},
    {fieldId:"<effort-field-id>",
     singleSelectOptionId:"<option-id>"}]})
  { issue { number } } }' -f id=<node-id>
```

### The Priority ladder

Read it against the current roadmap issue (the open `🗺️`
issue), whose waves are the authority on what the release
contains:

- **Urgent** — blocks the next release, or daily use is broken
  now.
- **High** — the release's own work: an open wave item, or a
  defect that belongs in one.
- **Medium** — the quality bar behind it: localization and
  terminology defects, docs parity, test debt, polish the
  release wants but does not gate on.
- **Low** — deferred, icebox, or blocked on the OS; behind the
  release by the roadmap's own guiding rule.

### The Effort ladder

The honest size of the fix, not its importance:

- **Low** — one sitting: a pin, a caption, a rename with a
  parity guard, a worksheet fix.
- **Medium** — a lane: one subsystem, its tests and its review
  round.
- **High** — a dedicated session or more: cross-subsystem, a
  new surface, or an unscoped investigation.

## 4. Verify

Read the issue back and confirm all three landed:

```sh
gh api repos/{owner}/{repo}/issues/<n> \
  --jq '{type: .type.name, fields: [.issue_field_values[]
  | {(.issue_field_name): .single_select_option.name}]}'
```
