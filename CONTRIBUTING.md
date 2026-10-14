# Contributing to Aegymer

Thanks for helping improve Aegymer. GitHub is the project's source of truth for issues, pull requests, branches, and releases.

## Before you start

Read the [README](README.md), search the existing GitHub issues, and avoid opening a duplicate. Discuss a change before doing substantial work when its scope is unclear.

### Creating and attributing issues

Create issues on [GitHub](https://github.com/felixilars/Aegymer/issues). Use one issue for one outcome and give it a concise, searchable title.

- For a bug, include the app version, device and platform, steps to reproduce, expected behaviour, actual behaviour, and any useful logs or screenshots.
- For a feature, explain the problem, the intended result, and clear acceptance criteria.
- Do not include personal metrics, private notes, or sensitive user data.
- The issue author is credited automatically. If someone else reports or contributes the work, acknowledge them in the issue or pull request.
- Ask to be assigned in a comment before starting work on an unassigned issue. Do not take over work already assigned to someone else without agreement.

## Branches and commits

Start from an up-to-date `main` branch and create one branch per issue:

```bash
git switch main
git pull origin main
git switch -c feature/12-documentation
```

Use lowercase, hyphen-separated branch names in this format:

```text
<type>/<issue-number>-<short-description>
```

Use `feature`, `fix`, `docs`, `refactor`, `test`, `chore`, or `ci` as the type. For example, `fix/42-streak-recalculation` and `docs/12-contributing-guide`.

Write focused commits using the Conventional Commits style:

```text
<type>(<scope>): <imperative summary>
```

Examples:

```text
feat(workout): add auto-save draft recovery
fix(history): handle empty session deletion
docs(contributing): document GitHub contribution workflow
```

Keep the summary short, use the imperative mood, and do not end it with a period. Add `Closes #12` to the pull request description when the change resolves an issue.

## Pull requests and merges

Open pull requests on GitHub with `main` as the target branch. A pull request must cover one issue or coherent change, explain what changed, list validation performed, and link the related issue.

Before requesting review:

- Rebase or merge the latest `main` when needed and resolve conflicts locally.
- Run the relevant checks: `flutter test`.
- If modifying database schemas in `lib/core/databases/`, run `dart run build_runner build --delete-conflicting-outputs` to regenerate Drift files, increment `schemaVersion`, and add an `onUpgrade` migration step.
- Keep generated build artifacts (`build/`), credentials (`key.properties`), signing keys (`*.jks`), and personal data out of commits.

Do not push directly to `main` or force-push a shared branch. A maintainer must approve the pull request and automated checks must pass before it is merged. Use squash merge for a small, single-purpose pull request. Preserve separate commits only when each one is meaningful on its own.

## Development guidelines

- **Offline-First**: All workout logging, nutritional calculations, and machine learning autoregulation must function without an internet connection. Do not introduce mandatory cloud account requirements.
- **Data Integrity**: User workout history and profile records are sacred. Never drop tables or delete local SQLite records during database schema upgrades.
