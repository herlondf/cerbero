# Contributing to Cerbero

Thank you for your interest in contributing! This guide covers everything you need to build, test, and submit changes.

---

## Building

1. Open RAD Studio 12 Athens.
2. Open `tests/Cerbero.Tests.dproj` (for the test runner) or the main project `.dproj` in `src/`.
3. Select **Build > Build All** (`Shift+F9`).
4. Compiled output (`.dcu`, `.exe`) goes to `bin/` and `dcu/` — both are git-ignored.

No external packages are required. The library depends only on Delphi RTL units: `System.Hash`, `System.JSON`, and `System.NetEncoding`.

---

## Running Tests

Tests use the **DUnitX** framework and run via the console runner.

```
cd tests/
Cerbero.Tests.exe --format=plain
```

All tests must pass before submitting a pull request. Output should end with:

```
Tests passed: N  Failed: 0  Errors: 0
```

Test files follow the naming convention `Cerbero.Tests.<Module>.pas` inside `tests/`. Mocks live in `tests/mocks/` with the prefix `Cerbero.Mock.<Type>.pas`.

---

## Submitting a Pull Request

1. Fork the repository and create a feature branch from `main`:
   ```
   git checkout -b feat/my-feature
   ```
2. Make your changes. See the code conventions below.
3. Run all tests and confirm zero failures.
4. Commit using [Conventional Commits](https://www.conventionalcommits.org/) in Portuguese (as per project rules):
   ```
   feat(jwt): adiciona suporte a RS256
   fix(verify): corrige leitura de claim booleana vazia
   ```
5. Open a pull request against `main`. Fill in the PR description explaining **what** changed and **why**.

---

## Code Conventions

### Naming

| Element | Prefix | Example |
|---------|--------|---------|
| Class | `T` + project prefix | `TCerberoBuilder` |
| Interface | `I` + project prefix | `ICerberoClaims` |
| Exception | `E` + project prefix | `ECerberoExpiredToken` |
| Method parameter | `A` | `ASecret`, `ASubject` |
| Local variable | `L` | `LToken`, `LClaims` |
| Class field | `F` | `FSecret`, `FExpiry` |

All names use PascalCase. Interfaces must have a unique GUID — never copy one from another interface.

### Declarations

- Declare local variables in the `var` section of the method, not inline (`var x :=`).
- Extract magic numbers and string literals to named `const` sections.

### `uses` clause

- Units used in a type's declaration belong in the `interface` section.
- Units used only in implementation belong in the `implementation` section.
- Order: RTL/VCL (`System.*`) → third-party libs → Cerbero units.
- Do not reorder existing `uses` entries when editing a file — change only what is necessary.

### Formatting

- Indentation: **2 spaces** (no tabs).
- Encoding: UTF-8 with BOM where already present — do not change it.
- Follow the [Embarcadero Delphi Style Guide](https://docwiki.embarcadero.com/RADStudio/en/Delphi_Style_Guide).

### Error handling

- `try/finally` is mandatory whenever an object is allocated and must be freed.
- No empty `except` blocks (`except end`). Always log or re-raise.
- Avoid catching the generic `Exception` class without a meaningful handler.

---

## Project Structure

```
Cerbero/
├── src/          <- library source (.pas)
├── tests/        <- DUnitX tests and mocks
│   └── mocks/
├── samples/      <- numbered usage examples
└── docs/         <- playbook and contributing guides
```

New source files must be registered in the corresponding `.dpr` and `.dproj` immediately after creation.
