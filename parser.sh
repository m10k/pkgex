#!/bin/bash

main() {
	local input_file
	local input
	local tokens

	opt_add_arg "i" "input-file" "rv" "" "Input file"

	if ! opt_parse "$@"; then
		return 1
	fi

	input_file=$(opt_get "input-file")
	input=$(<"$input_file")

	readarray -t tokens < <(tokenize "$input")

	if (( ${#tokens[@]} == 0 )); then
		log_error "No tokens"
		return 1
	fi

	parse "${tokens[@]}"
}

{
	if ! . toolbox.sh ||
	   ! include "log" "opt" "tokenize" "parse"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
