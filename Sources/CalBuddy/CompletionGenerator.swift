import Foundation

func generateCompletionScript(for shell: String) -> String? {
    switch shell {
    case "bash":
        return bashCompletionScript
    case "zsh":
        return zshCompletionScript
    case "fish":
        return fishCompletionScript
    default:
        return nil
    }
}

private let bashCompletionScript = """
_calbuddy_completion() {
    local cur prev cmd
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local commands="eventsToday eventsToday+N eventsNow eventsFrom:START calendars uncompletedTasks addEvent editEvent completion"
    local global_opts="-df --dateFormat -tf --timeFormat -ic --includeCals -ec --excludeCals -sc --separateByCalendar -sd --separateByDate -b --bullet -nc --noCalendarNames -ea --excludeAllDayEvents -n --includeOnlyEventsFromNowOn -eep --excludeEventProps -iep --includeEventProps -li --limitItems -uid --showUIDs -eed --excludeEndDates -sed --showEmptyDates -f --formatOutput -V --version"
    local add_edit_opts="--title --calendar --start --end --duration --allday --alarm --location --notes --url --uid"
    local shells="bash zsh fish"

    case "$prev" in
        completion|completions)
            COMPREPLY=( $(compgen -W "$shells" -- "$cur") )
            return 0
            ;;
        -df|--dateFormat|-tf|--timeFormat|-ic|--includeCals|-ec|--excludeCals|-b|--bullet|-eep|--excludeEventProps|-iep|--includeEventProps|-li|--limitItems|--title|--calendar|--start|--end|--duration|--alarm|--location|--notes|--url|--uid)
            return 0
            ;;
    esac

    cmd=""
    local i
    for ((i=1; i<${#COMP_WORDS[@]}; i++)); do
        if [[ "${COMP_WORDS[i]}" != -* ]]; then
            cmd="${COMP_WORDS[i]}"
            break
        fi
    done

    if [[ -z "$cmd" ]]; then
        COMPREPLY=( $(compgen -W "$commands $global_opts" -- "$cur") )
        return 0
    fi

    case "$cmd" in
        addEvent|editEvent)
            COMPREPLY=( $(compgen -W "$global_opts $add_edit_opts" -- "$cur") )
            ;;
        completion|completions)
            COMPREPLY=( $(compgen -W "$shells" -- "$cur") )
            ;;
        *)
            COMPREPLY=( $(compgen -W "$global_opts" -- "$cur") )
            ;;
    esac
}

complete -F _calbuddy_completion calbuddy
"""

private let zshCompletionScript = """
#compdef calbuddy

_calbuddy() {
    local -a commands global_opts add_edit_opts value_flags shells
    commands=(
        "eventsToday"
        "eventsToday+N"
        "eventsNow"
        "eventsFrom:START"
        "calendars"
        "uncompletedTasks"
        "addEvent"
        "editEvent"
        "completion"
    )
    global_opts=(
        "-df" "--dateFormat"
        "-tf" "--timeFormat"
        "-ic" "--includeCals"
        "-ec" "--excludeCals"
        "-sc" "--separateByCalendar"
        "-sd" "--separateByDate"
        "-b" "--bullet"
        "-nc" "--noCalendarNames"
        "-ea" "--excludeAllDayEvents"
        "-n" "--includeOnlyEventsFromNowOn"
        "-eep" "--excludeEventProps"
        "-iep" "--includeEventProps"
        "-li" "--limitItems"
        "-uid" "--showUIDs"
        "-eed" "--excludeEndDates"
        "-sed" "--showEmptyDates"
        "-f" "--formatOutput"
        "-V" "--version"
    )
    add_edit_opts=(
        "--title" "--calendar" "--start" "--end" "--duration"
        "--allday" "--alarm" "--location" "--notes" "--url" "--uid"
    )
    value_flags=(
        "-df" "--dateFormat" "-tf" "--timeFormat" "-ic" "--includeCals" "-ec" "--excludeCals"
        "-b" "--bullet" "-eep" "--excludeEventProps" "-iep" "--includeEventProps" "-li" "--limitItems"
        "--title" "--calendar" "--start" "--end" "--duration" "--alarm" "--location" "--notes" "--url" "--uid"
    )
    shells=("bash" "zsh" "fish")

    if (( CURRENT > 2 )) && [[ "${words[CURRENT-1]}" == "completion" || "${words[CURRENT-1]}" == "completions" ]]; then
        compadd -- $shells
        return
    fi

    local flag
    for flag in $value_flags; do
        if [[ "${words[CURRENT-1]}" == "$flag" ]]; then
            return
        fi
    done

    local cmd=""
    local i=2
    while (( i < CURRENT )); do
        if [[ "${words[i]}" != -* ]]; then
            cmd="${words[i]}"
            break
        fi
        (( i++ ))
    done

    if [[ -z "$cmd" ]]; then
        compadd -- $commands $global_opts
        return
    fi

    case "$cmd" in
        addEvent|editEvent)
            compadd -- $global_opts $add_edit_opts
            ;;
        completion|completions)
            compadd -- $shells
            ;;
        *)
            compadd -- $global_opts
            ;;
    esac
}

_calbuddy "$@"
"""

private let fishCompletionScript = """
complete -c calbuddy -f

set -l calbuddy_commands eventsToday eventsToday+N eventsNow eventsFrom:START calendars uncompletedTasks addEvent editEvent completion

complete -c calbuddy -n "not __fish_seen_subcommand_from $calbuddy_commands" -a "eventsToday eventsToday+N eventsNow eventsFrom:START calendars uncompletedTasks addEvent editEvent completion"
complete -c calbuddy -n "__fish_seen_subcommand_from completion completions" -a "bash zsh fish"

complete -c calbuddy -o df -l dateFormat -r -d "Date format"
complete -c calbuddy -o tf -l timeFormat -r -d "Time format"
complete -c calbuddy -o ic -l includeCals -r -d "Include calendars (comma-separated)"
complete -c calbuddy -o ec -l excludeCals -r -d "Exclude calendars (comma-separated)"
complete -c calbuddy -o sc -l separateByCalendar -d "Group output by calendar"
complete -c calbuddy -o sd -l separateByDate -d "Group output by date"
complete -c calbuddy -o b -l bullet -r -d "Bullet prefix"
complete -c calbuddy -o nc -l noCalendarNames -d "Hide calendar names"
complete -c calbuddy -o ea -l excludeAllDayEvents -d "Skip all-day events"
complete -c calbuddy -o n -l includeOnlyEventsFromNowOn -d "Only future events"
complete -c calbuddy -o eep -l excludeEventProps -r -d "Exclude properties"
complete -c calbuddy -o iep -l includeEventProps -r -d "Include only properties"
complete -c calbuddy -o li -l limitItems -r -d "Max items"
complete -c calbuddy -o uid -l showUIDs -d "Show event UIDs"
complete -c calbuddy -o eed -l excludeEndDates -d "Hide end dates"
complete -c calbuddy -o sed -l showEmptyDates -d "Show empty date groups"
complete -c calbuddy -o f -l formatOutput -d "ANSI color formatting"
complete -c calbuddy -o V -l version -d "Print version"

complete -c calbuddy -n "__fish_seen_subcommand_from addEvent editEvent" -l title -r -d "Event title"
complete -c calbuddy -n "__fish_seen_subcommand_from addEvent editEvent" -l calendar -r -d "Calendar name"
complete -c calbuddy -n "__fish_seen_subcommand_from addEvent editEvent" -l start -r -d "Start datetime"
complete -c calbuddy -n "__fish_seen_subcommand_from addEvent editEvent" -l end -r -d "End datetime"
complete -c calbuddy -n "__fish_seen_subcommand_from addEvent editEvent" -l duration -r -d "Duration (minutes)"
complete -c calbuddy -n "__fish_seen_subcommand_from addEvent editEvent" -l allday -d "All-day event"
complete -c calbuddy -n "__fish_seen_subcommand_from addEvent editEvent" -l alarm -r -d "Alarm minutes before"
complete -c calbuddy -n "__fish_seen_subcommand_from addEvent editEvent" -l location -r -d "Location"
complete -c calbuddy -n "__fish_seen_subcommand_from addEvent editEvent" -l notes -r -d "Notes"
complete -c calbuddy -n "__fish_seen_subcommand_from addEvent editEvent" -l url -r -d "URL"
complete -c calbuddy -n "__fish_seen_subcommand_from editEvent" -l uid -r -d "Event UID"
"""
