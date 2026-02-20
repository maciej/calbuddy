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
