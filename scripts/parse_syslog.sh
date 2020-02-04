#!/bin/bash
#
# Search for special keyword in syslog file & filter logs between a time range.

TO_BE_PARSED='/var/log/syslog'
OUTPUT_DIR='/home/ITRANSITION.CORP/d.uzky/dev/devops/shell_first/output/parse_syslog'
DEFAULT_SOUGHT_FOR='systemd'
LOGGING_RANGES=(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23)
HOLD_COUNT=3

start_date=$1
end_date=$2
sought_for=${3-$DEFAULT_SOUGHT_FOR}
name_template="syslog_${sought_for}_"

get_logs_by_keyword() {
	logs=$( grep "${sought_for}" $TO_BE_PARSED )
	echo "$logs"
}

divide_logs_by_hours() {
	logs=$1
	current_month=$(LANG=en_us_88591; date +"%b")
	current_day=$(date "+%-d")
	for h in "${LOGGING_RANGES[@]}"; do
		if [[ $h -ge $start_date ]] && [[ $h -lt $end_date ]]; then
			logfile="${OUTPUT_DIR}/${name_template}${h}"
			$logs | grep "${current_month}  ${current_day} ${h}:" >> "${logfile}"
		fi
	done
}

compress_old_logfiles() {
	archive_name="${name_template}old.tar"

	cd ${OUTPUT_DIR}

	old_logs=( syslog_${sought_for}_* )
	IFS=$'\n'
	old_logs=( $( sort -V <<< "${old_logs[*]}" ) )
	unset IFS
	old_logs=( ${old_logs[@]:0:$(( ${#old_logs[@]} - HOLD_COUNT))} )

	tar cvf "$archive_name" $(printf "%q " "${old_logs[@]}") \
		>> /dev/null
	rm "${old_logs[@]}"

	# chmod 700 "$archive_name"
	# sudo chown root:root "$archive_name"

	cd - >> /dev/null
}

divide_logs_by_hours get_logs_by_keyword
compress_old_logfiles
