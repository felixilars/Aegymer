# Contributing to Aegymer

Thank you for your interest in contributing to Aegymer! We welcome contributions ranging from bug fixes and feature implementations to documentation improvements and translations.

Please take a moment to review this guide before submitting code or opening issues.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Features](#suggesting-features)
  - [Pull Requests](#pull-requests)
- [Development Setup](#development-setup)
- [Branch & Commit Conventions](#branch--commit-conventions)
- [Coding Guidelines](#coding-guidelines)
- [License](#license)

---

## Code of Conduct

Please help us maintain a respectful and welcoming environment for everyone. Treat all contributors and users with kindness, empathy, and constructive feedback.

---

## How to Contribute

### Reporting Bugs

Before creating a new bug report, search the [existing issues](https://github.com/felixilars/Aegymer/issues) to verify if the problem has already been reported.

When opening a new issue, please include:
1. **Clear description**: What happened vs. what was expected to happen.
2. **Steps to reproduce**: Minimal, numbered steps showing how to trigger the bug.
3. **Environment details**:
   - Device model & Android / OS version
   - Flutter and Dart version (`flutter --version`)
   - App version / commit hash
4. **Logs or Screenshots**: Relevant console output or visual recordings demonstrating the behavior.

### Suggesting Features

We welcome ideas for improving training tracking, nutrition heuristics, and UI responsiveness. When submitting a feature request:
- Clearly explain the problem or motivation.
- Describe the proposed solution and how it benefits users.
- Provide mockups, sketches, or reference apps if applicable.

---

## Development Setup

1. **Fork and clone the repository:**
   ```bash
   git clone https://github.com/<your-username>/Aegymer.git
   cd Aegymer/flutter_application_1
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Database code generation (Drift):**
   If you modify any database schemas in `lib/core/databases/`, regenerate the Drift companion files:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app locally:**
   ```bash
   flutter run
   ```

5. **Run test suite:**
   ```bash
   flutter test
   ```

---

## Branch & Commit Conventions

### Branch Naming

Create feature branches off `main` using descriptive prefixes:
- `feat/workout-plate-calculator`
- `fix/streak-recalculation-bug`
- `docs/update-contributing-guide`
- `refactor/nutrition-service-cleanup`

### Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>
```

Common types:
- `feat`: A new feature or user-facing improvement
- `fix`: A bug fix
- `docs`: Documentation updates
- `refactor`: Code refactoring without changing behavior
- `test`: Adding or updating unit/widget tests
- `chore`: Build scripts, dependencies, or tool configurations

*Examples:*
- `feat(workout): add autoregulation deload indicator`
- `fix(history): prevent race condition on session deletion`
- `docs(readme): add on-device machine learning section`

---

## Coding Guidelines

1. **Architecture & State Management**:
   - Keep business logic in `core/services/` and repositories in `core/repositories/`.
   - UI widgets in `presentation/` should remain decoupled from direct database queries whenever possible.
2. **Offline-First Principle**:
   - Never introduce mandatory cloud dependencies that break core workout and nutrition logging when offline.
3. **Data Integrity & Preserving Comments**:
   - Preserve existing documentation and comments.
   - When altering SQLite schemas in `app_database.dart`, always implement an `onUpgrade` migration step to prevent wiping existing user data.
4. **Code Quality**:
   - Follow standard Dart style conventions (`dart format .`).
   - Ensure the code passes `flutter test` cleanly before opening a pull request.

---

## Pull Request Checklist

Before submitting a Pull Request, please ensure:

- [ ] Your code compiles cleanly without fatal warnings.
- [ ] Tests pass (`flutter test`).
- [ ] If changing database schemas, `schemaVersion` is incremented and an `onUpgrade` migration is added.
- [ ] Commits follow Conventional Commits formatting.
- [ ] The PR description clearly explains the changes and references any related issue (e.g., `Closes #12`).

---

## License

By contributing to Aegymer, you agree that your contributions will be licensed under the [MIT License](LICENSE).
