#!/bin/bash
#
# Search for special keyword in syslog file & filter logs between a time range.

TO_BE_PARSED='/var/log/syslog'
OUTPUT_DIR='/home/ITRANSITION.CORP/d.uzky/dev/devops/shell_first/output/parse_syslog'
DEFAULT_SOUGHT_FOR='systemd'
HOLD_COUNT=3

start_time=$1
start_h=$( date --date="$start_time" "+%H" )
# start_m=$( date --date="$start_time" "+%M" )
# start_s=$( date --date="$start_time" "+%S" )
end_time=$2
end_h=$( date --date="$end_time" "+%H" )
end_m=$( date --date="$end_time" "+%M" )
# end_s=$( date --date="$end_time" "+%S" )
sought_for=${3-$DEFAULT_SOUGHT_FOR}
name_template="syslog_${sought_for}_"

get_logs_by_keyword_and_timedelta() {
	current_month=$(LANG=en_us_88591; date +"%b")
	current_day=$(date "+%-d")
	logs=$( grep "${sought_for}" $TO_BE_PARSED | \
						awk -v start_time="$start_time" -v end_time="$end_time" \
						'($3 >= start_time && $3 <= end_time) { print $0 }')
	echo "$logs"
}

get_last_range_hour() {
	if [[ $end_m -eq '00' ]]; then
		last_h=$(( end_h - 1 ))
	else
		last_h=$end_h
	fi
}

divide_logs_by_hours() {
	logs=$1
	current_month=$(LANG=en_us_88591; date +"%b")
	current_day=$(date "+%-d")
	get_last_range_hour
	for h in $(seq $start_h $last_h ); do
		logfile="${OUTPUT_DIR}/${name_template}${current_day}_${h}"
		$logs | grep "${current_month}  ${current_day} ${h}:" > "${logfile}"
	done
}

get_old_logfiles() {
	get_last_range_hour
	if [[ $(( last_h - start_h )) -gt $HOLD_COUNT ]]; then
		logfiles_to_compress=()
		current_day=$(date "+%-d")
		for h in $(seq $start_h $(( last_h - HOLD_COUNT)) ); do
			logfiles_to_compress+=( "${name_template}${current_day}_${h}" )
		done
		echo "${logfiles_to_compress[@]}"
	else
		echo ''
	fi
}

compress_old_logfiles() {
	archive_name="${name_template}old.tar"

	old_logs=$(get_old_logfiles)
	if [[ $old_logs ]]; then
		cd ${OUTPUT_DIR}
		tar cvf "$archive_name" ${old_logs} >> /dev/null
		rm ${old_logs[@]} >> /dev/null

		# chmod 700 "$archive_name"
		# sudo chown root:root "$archive_name"
		cd - >> /dev/null
	fi
}

main() {
	if [[ "$end_time" > "$start_time" ]]; then
		divide_logs_by_hours get_logs_by_keyword_and_timedelta
		compress_old_logfiles
	else
		echo 'Wrong timestamps. Try again'
	fi
}

main "$@"