#!/bin/bash
read -p "Please enter the path to the folder log: " log_dir
if [ ! -e "$log_dir" ]; then
	echo "Error. Path '$log_dir' does not exist"
	exit 1
elif [ -f "$log_dir" ]; then 
	echo "Error. '$log_dir' is a file, not a folder"
	exit 1
elif [ -d "$log_dir" ]; then
	echo "Folder exist and directory is valid"
	
	cur_size=$(du -sk "$log_dir" | awk '{print $1}')
	echo "Current size of the folder log: $cur_size kilobytes"
	
	total_memory=$(df -k "$log_dir" | tail -n 1 | awk '{print $2}')
	echo "Current total size of system memory: $total_memory kilobytes"
	if [ -z "$total_memory" ] || [ "$total_memory" -le 0 ]; then
		echo "Error. Total system memory size is 0 or unavailable" 
		exit 1
	fi

	percent_log_of_memory=$(( (cur_size * 100) / total_memory ))
	echo "Folder occupies $percent_log_of_memory% of total system memory"

	echo "Please enter the critical percent (N): "
	echo "If size of folder exceeds the critical percent archivation process will begin"
	read N
	if [[ ! "$N" =~ ^[0-9]+$ ]]; then
   		 echo "Error. Critical percent must be a whole number!"
   		 exit 1
	fi

	if [ $percent_log_of_memory -gt $N ]; then
		echo "Threshold of ${N}% was exceeded. Archivation process starts"
		echo "Please enter how many files to archive (M): "
		read M
		if [[ ! "$M" =~ ^[0-9]+$ ]] || [ "$M" -le 0 ]; then
			echo "Error. Number of files to archive must be a whole number greater than 0!"
			exit 1
		fi

		backup_dir="${BACKUP_DIR:-$(dirname "$log_dir")/backup}"
		mkdir -p "$backup_dir"
		
		cd "$log_dir" || { echo "Error. Cannot enter directory $log_dir"; exit 1; }

		find . -maxdepth 1 -type f -name "*.log" -printf '%T+ %p\n' \
			| sort \
			| head -n "$M" \
			| awk '{print $2}' > .list.tmp

		IFS=$'\n' read -r -d '' -a files_array < .list.tmp
		
		rm -f .list.tmp

		if [ ${#files_array[@]} -gt 0 ]; then
			echo "Found oldest files to archive: ${files_array[*]}"
			
			archive_name="$backup_dir/archive_$(date +%Y%m%d_%H%M%S).tar.gz"
			tar -czf "$archive_name" "${files_array[@]}"
			rm -f "${files_array[@]}" 
			
			echo "old log files successfully filtered and deleted"
		else
			echo "No .log files found for archivation"
		fi

	else
		echo "Threshold of ${N}% was not exceeded. Archivation process skipped"
		exit 0
	fi
else
	echo "Unknown error with the path"
	exit 1
fi

