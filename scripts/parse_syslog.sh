#!/bin/bash
#
# Search for special keyword in syslog file & filter logs between a time range.


TO_BE_PARSED='/var/log/syslog'
OUTPUT_DIR='output/parse_syslog'
TIMESTAMP_TEMPLATE="^([0-1][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])$"
KW_ARGS_COUNT=3
HOLD_COUNT=3

CURRENT_MONTH=$(LANG=en_us_88591; date +'%b')
CURRENT_DAY=$(date "+%-d")

EMPTY_LOGFILE_PREFIX='empty'
ARCHIVE_POSTFIX='old'

WRONG_COUNT_MSG="Wrong number of arguments. You should pass ${KW_ARGS_COUNT} arguments, got %s. Use --help to see usage."
WRONG_KEY_MSG="Wrong argument key: %s. Use --help to see usage."
WRONG_TIMESTAMP_MSG="Wrong timestamp format for %s. Should be the following: HH:MM:SS."
WRONG_TIMERANGE_MSG="Wrong timerange - %s can't be lower then %s, but it should. Ensure timestamps are correct."
# CANT_ACCESS_DIR_MSG="Directory %s doesn't exist or can't be accessed."
NO_MATCH_FOUND_MSG="No matches found for the %s keyword. No output logfiles created."


get_logs_by_keyword_and_timedelta() {
  local start_time=$1
  local end_time=$2
  local sought_for=$3

  awk -v k="$sought_for" \
      -v m="$CURRENT_MONTH" \
      -v d="$CURRENT_DAY" \
      -v start="$start_time" \
      -v end="$end_time" \
      '$0 ~ k && $1 == m && $2 == d && $3 >= start && $3 <= end { print $0 }' \
      $TO_BE_PARSED
}

get_last_range_hour() {
  local end_time=$1

  local end_h
  local end_m
  local end_s

  end_h=$( date --date="$end_time" "+%H" )
  end_m=$( date --date="$end_time" "+%M" )
  end_s=$( date --date="$end_time" "+%S" )

  (( "$end_m" + "$end_s" )) && echo "$end_h" || echo "(( $end_h - 1 ))"
}

compress_old_logfiles() {
  local logfiles_to_compress=( "$@" )
  local archive_name="${NAME_TEMPLATE}_${CURRENT_DAY}_${ARCHIVE_POSTFIX}.tar"

  {
    cd ${OUTPUT_DIR} || return 1
    tar cvf "$archive_name" "${logfiles_to_compress[@]}"
    rm "${logfiles_to_compress[@]}"
    # chmod 700 "$archive_name"
    # sudo chown root:root "$archive_name"
    cd - || return 1
  } >> /dev/null
}

write_logs_to_file() {
  local logs=$1
  local hour=$2

  local prefix
  local postfix
  local logfile

  [[ $logs ]] && prefix="" || prefix="${EMPTY_LOGFILE_PREFIX}_"
  postfix="_${CURRENT_DAY}_${hour}"
  logfile="${OUTPUT_DIR}/${prefix}${NAME_TEMPLATE}${postfix}"

  echo "$logs" > "${logfile}"

  echo "$logfile"
}

divide_logs_by_hours() {
  local logs=$1
  local first_hour=$2
  local last_hour=$3

  local logs_by_hour
  local logfile

  local to_compress=()

  if [[ $logs ]]; then
    for h in $(seq "$first_hour" "$last_hour" ); do
      logs_by_hour=$(echo "$1" | awk -v h="^$h:" '$3 ~ h { print $0 }')

      logfile=$( write_logs_to_file "$logs_by_hour" "$h" )

      if [[ $(( h + HOLD_COUNT )) -le $last_hour ]]; then
        to_compress+=( "$( basename "$logfile" )" )
      fi
    done
    (( ${#to_compress[@]} )) && compress_old_logfiles "${to_compress[@]}"
    return 0
  else
    show_info "$NO_MATCH_FOUND_MSG" "$sought_for"; return 1
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
  printf "$1" "${@:2}"; echo "" 
}

show_help() {
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
              show_info "$WRONG_TIMESTAMP_MSG" "$2"; return 1
            fi
            ;; 
        -re) 
            if validate_timestamp "$2"; then
              end_time=$2; shift 2
            else
              show_info "$WRONG_TIMESTAMP_MSG" "$2"; return 1
            fi
            ;;
        -k) 
           sought_for=$2
           shift 2
           ;;

        -h|--help) show_help; return 1;;

        *) show_info "$WRONG_KEY_MSG" "$1"; return 1;;
      esac
    done
    if validate_timerange "$start_time" "$end_time"; then
      return 0
    else
      show_info "$WRONG_TIMERANGE_MSG" "$start_time" "$end_time"; return 1
    fi
  else
    show_info "$WRONG_COUNT_MSG" $(( $# / 2 )); return 1
  fi
}


main() {
  if parse_args "$@"; then
    NAME_TEMPLATE="syslog_${sought_for}"

    first_hour=$( date --date="$start_time" "+%H" )
    last_hour=$( get_last_range_hour "$end_time" )

    mkdir -p "$OUTPUT_DIR"

    divide_logs_by_hours \
      "$( get_logs_by_keyword_and_timedelta "$start_time" \
                                            "$end_time" \
                                            "$sought_for" )" \
      "$first_hour" \
      "$last_hour"
  fi
}

main "$@"