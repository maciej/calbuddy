# CalBuddy

A modern replacement for icalBuddy, built with Swift and EventKit.

## Build

```bash
make build
```

## Install

```bash
make install   # copies to ~/.local/bin/calbuddy
# optional: override install prefix
make install PREFIX=/usr/local
```

## Usage

```bash
# Today's events
calbuddy eventsToday

# Next 7 days
calbuddy eventsToday+7

# Events happening right now
calbuddy eventsNow

# Date range
calbuddy eventsFrom:2026-02-01 to:2026-02-28

# List calendars
calbuddy calendars

# Add, edit, and delete events with reversible action-log entries
calbuddy addEvent --title "Dentist" --calendar Family --start "2026-02-10 14:00" --duration 30
calbuddy editEvent --uid EVENT_UID --title "Dentist moved"
calbuddy deleteEvent --uid EVENT_UID

# Inspect and revert calendar mutations
calbuddy actionLog
calbuddy actionLog --actionID ACTION_ID
calbuddy revertAction --actionID ACTION_ID
calbuddy revertAction --actionID ACTION_ID --force

# Agent-friendly JSON output
calbuddy --json eventsToday
calbuddy --json eventsNow
calbuddy --json eventsFrom:today to:today+7
calbuddy --json calendars
calbuddy --json actionLog

# Full JSON payload (verbose)
calbuddy --json=all eventsToday
calbuddy --json --verbose eventsToday

# Generate completion script for your shell
calbuddy completion zsh
```

## Shell Completions

Generate completion scripts:

```bash
calbuddy completion bash
calbuddy completion zsh
calbuddy completion fish
```

Generate all scripts into `./completions`:

```bash
make completions
```

Install completions locally:

```bash
make install-completions-local
```

Installed paths:

- Bash: `~/.local/share/bash-completion/completions/calbuddy`
- Zsh: `~/.zsh/completions/_calbuddy`
- Fish: `~/.config/fish/completions/calbuddy.fish`

## Options

| Short | Long | Description |
|-------|------|-------------|
| `-df` | `--dateFormat` | strftime date format (default: `%Y-%m-%d %A`) |
| `-tf` | `--timeFormat` | strftime time format (default: `%H:%M`) |
| `-ic` | `--includeCals` | Include only these calendars (comma-separated) |
| `-ec` | `--excludeCals` | Exclude these calendars (comma-separated) |
| `-sc` | `--separateByCalendar` | Group by calendar |
| `-sd` | `--separateByDate` | Group by date |
| `-b`  | `--bullet` | Bullet string (default: `• `) |
| `-nc` | `--noCalendarNames` | Omit calendar names |
| `-ea` | `--excludeAllDayEvents` | Skip all-day events |
| `-n`  | `--includeOnlyEventsFromNowOn` | Only future events |
| `-eep`| `--excludeEventProps` | Exclude properties |
| `-iep`| `--includeEventProps` | Include only properties |
| `-li` | `--limitItems` | Max items |
| `-uid`| `--showUIDs` | Show event UIDs |
| `-eed`| `--excludeEndDates` | Don't show end times |
| `-sed`| `--showEmptyDates` | Show empty date sections |
| `-f`  | `--formatOutput` | ANSI colors |
|       | `--json` | Compact JSON output for `eventsToday`, `eventsNow`, `eventsFrom:*`, and `calendars` |
| `-v`  | `--verbose` | Verbose output (with `--json`, includes extended fields) |
| `-V`  | `--version` | Version |
|       | `--actionLogDB` | Override action log SQLite database path |
|       | `--actionID` | Action ID for `actionLog` show and `revertAction` |
|       | `--force` | Force `revertAction` through conflict checks |

Properties: `title`, `datetime`, `location`, `notes`, `url`, `attendees`

## Immutable Action Log

Every mutating calendar command appends an immutable SQLite action-log entry before returning successfully. Existing entries are append-only: corrections and reverts are represented by new entries, never by editing or deleting earlier ones.

Default database path:

```bash
~/Library/Application Support/calbuddy/action-log.sqlite3
```

Override precedence:

1. `--actionLogDB PATH`
2. `CALBUDDY_ACTION_LOG_DB`
3. default path above

Logged mutators:

- `addEvent` stores `before = null`, `after = created event`, and can be reverted by deleting the created event.
- `editEvent` stores full before/after event snapshots and can be reverted by restoring the before snapshot.
- `deleteEvent` stores `before = deleted event`, `after = null`, and can be reverted by recreating the event.
- `revertAction` is itself logged and linked to the original action.

Conflict behavior:

- Reverts are exact by default. If the current calendar item no longer matches the logged after-state, `revertAction` refuses to run.
- `--force` applies the stored inverse despite conflicts.
- Deleting events with unsupported restorable state, such as recurrence rules, attendees, or absolute alarms, is refused because CalBuddy cannot guarantee a perfect recreate.

## Compatibility Notes

`uncompletedTasks` has been removed from CalBuddy. For Apple Reminders CLI workflows, use `remindctl`: https://github.com/steipete/remindctl
