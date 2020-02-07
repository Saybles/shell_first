#!/bin/bash
#
# Search for special keyword in syslog file & filter logs between a time range.

TO_BE_PARSED='/var/log/syslog'
OUTPUT_DIR='/home/ITRANSITION.CORP/d.uzky/dev/devops/shell_first/output/parse_syslog'
TIMESTAMP_TEMPLATE="^([0-1][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])$"
KW_ARGS_COUNT=3
HOLD_COUNT=3

WRONG_COUNT_MSG="Wrong number of arguments. You should pass 3 arguments. Use --help to see usage."
WRONG_KEY_MSG="Wrong argument key. Use --help to see usage."
WRONG_TIMESTAMP_MSG="Wrong timestamp format. Should be the following HH:MM:SS."
WRONG_TIMERANGE_MSG="Wrong timerange. Check timestamps are correct."
# CANT_ACCESS_DIR_MSG="Directory doesn't exist or can't be accessed."
NO_MATCH_FOUND_MSG="No matches found for the given keyword. 0 output logfiles created."

current_month=$(LANG=en_us_88591; date +'%b')
current_day=$(date "+%-d")
logfiles_to_compress=()


get_logs_by_keyword_and_timedelta() {
  awk -v k="$sought_for" \
      -v m="$current_month" \
      -v d="$current_day" \
      -v start="$start_time" \
      -v end="$end_time" \
      '$0 ~ k && $1 == m && $2 == d && $3 >= start && $3 <= end { print $0 }' \
      $TO_BE_PARSED
}

get_last_range_hour() {
  (( ! ("$end_m" + "$end_s") )) && last_h=$(( end_h - 1 )) || last_h=$end_h
}

divide_logs_by_hours() {
  logs=$1
  if [[ $logs ]]; then
    get_last_range_hour
    for h in $(seq "$start_h" "$last_h" ); do
      logs_by_hour=$(echo "$1" | awk -v h="^$h" '$3 ~ h { print $0 }')

      [[ $logs_by_hour ]] && prefix="" || prefix="empty_"
      postfix="${current_day}_${h}"

      logfile="${OUTPUT_DIR}/${prefix}${name_template}${postfix}"
      echo "$logs_by_hour" > "${logfile}"

      if [[ $(( h + HOLD_COUNT )) -le $last_h ]]; then
        logfiles_to_compress+=( $(basename "$logfile") )
      fi
    done
    return 0
  else
    show_info "$NO_MATCH_FOUND_MSG"; return 1
  fi
}

compress_old_logfiles() {
  archive_name="${name_template}old.tar"
  if [[ $logfiles_to_compress ]]; then
    cd ${OUTPUT_DIR}
    {
      tar cvf "$archive_name" "${logfiles_to_compress[@]}"
      rm "${logfiles_to_compress[@]}"
      chmod 700 "$archive_name"
      sudo chown root:root "$archive_name"
      cd -
    } >> /dev/null
  fi
}


validate_args_count() {
  [[ $# -eq 1 ]] && [[ $1 =~ ^-h|--help$ ]] && return 0
  [[ $# -eq $((KW_ARGS_COUNT * 2 )) ]] && return 0 || return 1
}

validate_timestamp() {
  [[ $1 =~ $TIMESTAMP_TEMPLATE ]] && return 0 || return 1
}

validate_timerange() {
  [[ "$1" < "$2" ]] && return 0 || return 1
}

show_info() {
  echo "$1"
}

show_help () {
  printf "
Usage: %s [OPTIONS]
Options:
  -h, --help    Show help text
  -rs           Set timerange start timestamp
  -re           Set timerange end timestamp
  -k            Set keyword to search for
  " "$(basename "$0")"
  echo ""
}

parse_args() {
  if validate_args_count "$@"; then
    while (( $# > 0 )); do
      case $1 in
        -rs) 
            if validate_timestamp "$2"; then
              start_time=$2; shift 2
            else
			        show_info "$WRONG_TIMESTAMP_MSG"; return 1
            fi
            ;; 
        -re) 
            if validate_timestamp "$2"; then
              end_time=$2; shift 2
            else
				      show_info "$WRONG_TIMESTAMP_MSG"; return 1
            fi
            ;;
        -k) 
           sought_for=$2
           name_template="syslog_${sought_for}_"
           shift 2
           ;;

        -h|--help) show_help; return 1;;

        *) show_info "$WRONG_KEY_MSG"; return 1;;
      esac
    done
    if validate_timerange "$start_time" "$end_time"; then
      start_h=$( date --date="$start_time" "+%H" )
      end_h=$( date --date="$end_time" "+%H" )
      end_m=$( date --date="$end_time" "+%M" )
      end_s=$( date --date="$end_time" "+%S" )
      return 0
    else
      show_info "$WRONG_TIMERANGE_MSG"; return 1
    fi
  else
    show_info "$WRONG_COUNT_MSG"; return 1
  fi
}


main() {
  if parse_args "$@"; then
    divide_logs_by_hours "$(get_logs_by_keyword_and_timedelta)" &&
    compress_old_logfiles
  fi
}

main "$@"