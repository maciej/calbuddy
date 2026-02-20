# CalBuddy

A modern replacement for icalBuddy, built with Swift and EventKit.

## Build

```bash
make build
```

## Install

```bash
make install   # copies to /opt/homebrew/bin/calbuddy
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

# Uncompleted reminders
calbuddy uncompletedTasks
```

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
| `-V`  | `--version` | Version |

Properties: `title`, `datetime`, `location`, `notes`, `url`, `attendees`
