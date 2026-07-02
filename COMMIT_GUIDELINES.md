# Commit Guidelines

Use detailed conventional commits so the project history explains both what
changed and why it matters.

## Format

```text
type(scope): short imperative summary

Section name

- Concrete change or group of changes.
- Behavior kept, moved, or intentionally preserved.
- User-facing impact, migration note, or verification detail when useful.

Another section

- Keep related changes together.
- Prefer specific surfaces, modules, or flows over generic wording.
```

## Types

- `feat`: new capability or visible product improvement.
- `fix`: bug fix or regression correction.
- `refactor`: internal change without intended behavior change.
- `test`: test coverage or test tooling.
- `docs`: documentation only.
- `chore`: maintenance, configuration, or dependency work.

## Good Example

```text
feat(i18n): migrate core app surfaces

App surfaces

- Move Home, downloads, playlists, artists, captures, history, player,
  sources, World Mode and Listenfy Connect visible copy onto localization keys.
- Keep the existing layouts and controller flows while replacing hardcoded
  user-facing labels.
- Cover the main library surfaces that users touch most often before the
  advanced workflow pass.

Local alerts and actions

- Localize notification titles, channel labels and media action dialogs so
  shared app flows follow the selected language.
- Update nearby transfer, local connect and import feedback messages to use the
  translation layer.
- Preserve the current service behavior while making the displayed copy
  language-aware.

Wrapped and recommendations shell

- Localize Wrapped/stat labels and the recommendation surface text used by the
  main library experience.
- Move section hints, empty states and action labels into the shared translation
  files.
- Keep recommendation generation logic unchanged while preparing the UI for full
  multilingual coverage.
```

## Checklist

- The subject is short, imperative and scoped.
- The body is grouped by meaningful areas, not file names alone.
- Bullets explain user-visible impact or preserved behavior.
- The commit only contains the files described by the message.
