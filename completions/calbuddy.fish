function __calbuddy_should_offer_completions_for_flags_or_options -a expected_commands
    set -l non_repeating_flags_or_options $argv[2..]

    set -l non_repeating_flags_or_options_absent 0
    set -l positional_index 0
    set -l commands
    __calbuddy_parse_tokens
    test "$commands" = "$expected_commands"; and return $non_repeating_flags_or_options_absent
end

function __calbuddy_should_offer_completions_for_positional -a expected_commands expected_positional_index positional_index_comparison
    if test -z $positional_index_comparison
        set positional_index_comparison -eq
    end

    set -l non_repeating_flags_or_options
    set -l non_repeating_flags_or_options_absent 0
    set -l positional_index 0
    set -l commands
    __calbuddy_parse_tokens
    test "$commands" = "$expected_commands" -a \( "$positional_index" "$positional_index_comparison" "$expected_positional_index" \)
end

function __calbuddy_parse_tokens -S
    set -l unparsed_tokens (__calbuddy_tokens -pc)
    set -l present_flags_and_options

    switch $unparsed_tokens[1]
    case 'calbuddy'
        __calbuddy_parse_subcommand -r 1 'dateFormat=' 'timeFormat=' 'includeCals=' 'excludeCals=' 'separateByCalendar' 'separateByDate' 'b/bullet=' 'noCalendarNames' 'excludeAllDayEvents' 'n/includeOnlyEventsFromNowOn' 'excludeEventProps=' 'includeEventProps=' 'limitItems=' 'showUIDs' 'excludeEndDates' 'showEmptyDates' 'f/formatOutput' 'json' 'v/verbose' 'V/version' 'title=' 'calendar=' 'start=' 'end=' 'duration=' 'allday' 'alarm=+' 'location=' 'notes=' 'url=' 'uid=' 'h/help'
        switch $unparsed_tokens[1]
        case 'help'
            __calbuddy_parse_subcommand -r 1 
        end
    end
end

function __calbuddy_tokens
    if test (string split -m 1 -f 1 -- . "$FISH_VERSION") -gt 3
        commandline --tokens-raw $argv
    else
        commandline -o $argv
    end
end

function __calbuddy_parse_subcommand -S -a positional_count
    argparse -s r -- $argv
    set -l option_specs $argv[2..]

    set -a commands $unparsed_tokens[1]
    set -e unparsed_tokens[1]

    set positional_index 0

    while true
        argparse -sn "$commands" $option_specs -- $unparsed_tokens 2> /dev/null
        set unparsed_tokens $argv
        set positional_index (math $positional_index + 1)

        for non_repeating_flag_or_option in $non_repeating_flags_or_options
            if set -ql _flag_$non_repeating_flag_or_option
                set non_repeating_flags_or_options_absent 1
                break
            end
        end

        if test (count $unparsed_tokens) -eq 0 -o \( -z "$_flag_r" -a "$positional_index" -gt "$positional_count" \)
            break
        end
        set -e unparsed_tokens[1]
    end
end

function __calbuddy_complete_directories
    set -l token (commandline -t)
    string match -- '*/' $token
    set -l subdirs $token*/
    printf '%s\n' $subdirs
end

function __calbuddy_custom_completion
    set -x SAP_SHELL fish
    set -x SAP_SHELL_VERSION $FISH_VERSION

    set -l tokens (__calbuddy_tokens -p)
    if test -z (__calbuddy_tokens -t)
        set -l index (count (__calbuddy_tokens -pc))
        set tokens $tokens[..$index] \'\' $tokens[(math $index + 1)..]
    end
    command $tokens[1] $argv $tokens
end

complete -c 'calbuddy' -f
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" dateFormat df' -o 'df' -l 'dateFormat' -d 'Date format' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" tf timeFormat' -o 'tf' -l 'timeFormat' -d 'Time format' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" ic includeCals' -o 'ic' -l 'includeCals' -d 'Include only these calendars (comma-separated)' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" ec excludeCals' -o 'ec' -l 'excludeCals' -d 'Exclude these calendars (comma-separated)' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" sc separateByCalendar' -o 'sc' -l 'separateByCalendar' -d 'Group output by calendar'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" sd separateByDate' -o 'sd' -l 'separateByDate' -d 'Group output by date'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" b bullet' -s 'b' -l 'bullet' -d 'Bullet prefix' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" nc noCalendarNames' -o 'nc' -l 'noCalendarNames' -d 'Hide calendar names'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" ea excludeAllDayEvents' -o 'ea' -l 'excludeAllDayEvents' -d 'Skip all-day events'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" includeOnlyEventsFromNowOn n' -s 'n' -l 'includeOnlyEventsFromNowOn' -d 'Only include future events'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" eep excludeEventProps' -o 'eep' -l 'excludeEventProps' -d 'Exclude properties' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" iep includeEventProps' -o 'iep' -l 'includeEventProps' -d 'Include only these properties' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" li limitItems' -o 'li' -l 'limitItems' -d 'Max items' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" showUIDs uid' -o 'uid' -l 'showUIDs' -d 'Show event UIDs'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" eed excludeEndDates' -o 'eed' -l 'excludeEndDates' -d 'Hide end dates'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" sed showEmptyDates' -o 'sed' -l 'showEmptyDates' -d 'Show empty date sections'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" f formatOutput' -s 'f' -l 'formatOutput' -d 'ANSI color formatting'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" json' -l 'json' -d 'Output compact JSON (supported by eventsToday, eventsNow, eventsFrom:... and calendars)'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" v verbose' -s 'v' -l 'verbose' -d 'Verbose output. With --json, include extended fields'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" V version' -s 'V' -l 'version' -d 'Print version'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" title' -l 'title' -d 'Event title' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" calendar' -l 'calendar' -d 'Calendar name' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" start' -l 'start' -d 'Start date/time' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" end' -l 'end' -d 'End date/time' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" duration' -l 'duration' -d 'Duration in minutes' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" allday' -l 'allday' -d 'Create/set all-day event'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy"' -l 'alarm' -d 'Alarm minutes before' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" location' -l 'location' -d 'Event location' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" notes' -l 'notes' -d 'Event notes' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" url' -l 'url' -d 'Event URL' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" uid' -l 'uid' -d 'Event UID for editEvent' -rfka ''
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_positional "calbuddy" 1 -ge' -fka 'eventsToday eventsToday+1 eventsNow eventsFrom:today calendars addEvent editEvent completion completions'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_flags_or_options "calbuddy" h help' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'calbuddy' -n '__calbuddy_should_offer_completions_for_positional "calbuddy" 2' -fa 'help' -d 'Show subcommand help information.'
