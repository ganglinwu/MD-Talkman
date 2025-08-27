#!/bin/bash

POOL_SIZE=5
LAST_USED_INDEX=0

function get_next_pool_file() {
	local latest_i=0
	local latest_time=9999999999999999
	for i in $(seq 0 $((POOL_SIZE - 1))); do
		if [ ! -f "test_results_pool_${i}.txt" ]; then
			echo "test_results_pool_${i}.txt"
			LAST_USED_INDEX=i
			return
		fi
	done
	for i in $(seq 0 $((POOL_SIZE - 1))); do
		local timestamp=$(stat -f "%m" "test_results_pool_${i}.txt")
		if [ $timestamp -lt $latest_time ]; then
			latest_time=timestamp
			latest_i=i
		fi
	done
	rm "test_results_pool_${latest_i}.txt"
	echo "test_results_pool_${latest_i}.txt"
	LAST_USED_INDEX=i
	return
}

show_pool_status() {
	echo "Last used test result file: test_results_pool_${LAST_USED_INDEX}.txt"
	return
}

run_tests() {
	local pool_file=$(get_next_pool_file)
	xcodebuild test -scheme "MD TalkMan" -destination 'platform=iOS Simulator,name=iPhone 16' >"$pool_file" 2>&1
	return
}

case "${1:-run}" in
"status") show_pool_status ;;
"run") run_tests ;;
esac
