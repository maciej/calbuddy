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

# Start a foreground local server for Calendar access
calbuddy serve

# Use a custom client/server socket
calbuddy --socket /tmp/calbuddy.sock serve
calbuddy --socket /tmp/calbuddy.sock eventsToday

# Bypass the server and access Calendar directly
calbuddy --direct eventsToday

# Agent-friendly JSON output
calbuddy --json eventsToday
calbuddy --json eventsNow
calbuddy --json eventsFrom:today to:today+7
calbuddy --json calendars

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
|       | `--direct` | Bypass the local server and access Apple Calendar directly |
|       | `--socket` | Unix socket path for client/server mode |
| `-v`  | `--verbose` | Verbose output (with `--json`, includes extended fields) |
| `-V`  | `--version` | Version |

Properties: `title`, `datetime`, `location`, `notes`, `url`, `attendees`

## Client/Server Mode

`calbuddy serve` starts a foreground local server that owns Apple Calendar access through EventKit. Normal calendar commands first try to connect to that server and, if the server socket is unavailable, fall back to direct Calendar access so existing CLI workflows keep working.

```bash
# Terminal 1: grant Calendar access to this long-lived process
calbuddy serve

# Terminal 2: uses the server when it is reachable
calbuddy eventsToday
calbuddy addEvent --title "Dentist" --calendar "Family" --start "2026-02-10 14:00"
```

The default Unix socket is `/tmp/calbuddy-$UID.sock`. Override it with `--socket PATH` or `CALBUDDY_SOCKET`:

```bash
CALBUDDY_SOCKET=/tmp/calbuddy-agent.sock calbuddy serve
CALBUDDY_SOCKET=/tmp/calbuddy-agent.sock calbuddy eventsToday
```

Use `--direct` or `CALBUDDY_DIRECT=1` to bypass the server:

```bash
calbuddy --direct eventsToday
CALBUDDY_DIRECT=1 calbuddy calendars
```

Connection-level failures such as a missing, refused, timed-out, or stale socket fall back to direct mode. A reachable server's command errors, Calendar/API failures, malformed responses, and protocol-version mismatches are reported as server errors.

### Server Protocol

The transport is local Unix-domain socket only. Each message is a 4-byte big-endian payload length followed by UTF-8 JSON. Field names are snake_case.

Request:

```json
{
  "protocol_version": 1,
  "client_version": "1.0.0",
  "request_id": "UUID",
  "argv": ["eventsToday"]
}
```

Response:

```json
{
  "protocol_version": 1,
  "server_version": "1.0.0",
  "request_id": "UUID",
  "exit_code": 0,
  "stdout": "...",
  "stderr": "",
  "error": null
}
```

`argv` uses the same command tokens and options as the CLI, and the server returns the rendered stdout/stderr so existing output behavior remains centralized in CalBuddy.

## Compatibility Notes

`uncompletedTasks` has been removed from CalBuddy. For Apple Reminders CLI workflows, use `remindctl`: https://github.com/steipete/remindctl
