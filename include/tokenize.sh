__init() {
	return 0
}

tokenize() {
	local input="$1"

	case "${input:0:1}" in
		'<'|'>'|'!')
			tokenize_cmp_op "${input:0:1}" "${input:1}"
		        ;;

		'=')
			tokenize_eq_op "${input:0:1}" "${input:1}"
			;;

		'"')
			tokenize_string "" "${input:1}"
			;;

		'&'|'|')
			tokenize_log_op "${input:0:1}" "${input:1}"
			;;

		':')
			echo "COLON::"
			tokenize "${input:1}"
			;;

		';')
			echo "SEMICOLON:;"
			tokenize "${input:1}"
			;;

		'(')
			echo "LPAREN:("
			tokenize "${input:1}"
			;;

		')')
			echo "RPAREN:)"
			tokenize "${input:1}"
			;;

		' '|$'\t'|$'\n')
			tokenize "${input:1}"
			;;

		[0-9a-zA-Z._])
			tokenize_literal "${input:0:1}" "${input:1}"
			;;
	esac

	return "$?"
}

tokenize_cmp_op() {
	local read="$1"
	local input="$2"

	if [[ "${input:0:1}" == "=" ]]; then
		echo "RELOP:$read${input:0:1}"
		tokenize "${input:1}"
	else
		echo "RELOP:$read"
		tokenize "$input"
	fi

	return "$?"
}

tokenize_eq_op() {
	local read="$1"
	local input="$2"

	case "${input:0:1}" in
		'='|'~')
			echo "RELOP:$read${input:0:1}"
			tokenize "${input:1}"
			;;

		*)
			echo "RELOP:$read"
			tokenize "$input"
			;;
	esac

	return "$?"
}

tokenize_log_op() {
	local read="$1"
	local input="$2"

	local head
	local -A type

	type["&&"]="AND"
	type["||"]="OR"

	head="${input:0:1}"

	if [[ "$head" == "$read" ]]; then
		echo "${type[$read$head]}:$read$head"
		tokenize "${input:1}"
	else
		echo "Could not parse token \"$read$head\"" 1>&2
		return 1
	fi

	return "$?"
}

tokenize_string_escape() {
	local read="$1"
	local input="$2"

	if [[ "${input:0:1}" == '=' ]]; then
		read+='"'
	elif [[ "${input:0:1}" != '\\' ]]; then
		read+='\\'
	fi

	tokenize_string "$read${input:0:1}" "${input:1}"
	return 0
}

tokenize_string() {
	local read="$1"
	local input="$2"

	if (( ${#input} == 0 )); then
		echo "Unterminated string (token=\"$read\")" 1>&2
		return 1
	fi

	case "${input:0:1}" in
		'"')
			echo "STRING:$read"
			tokenize "${input:1}"
			;;

		'\\')
			tokenize_string_escape "$read" "${input:1}"
			;;

		*)
			tokenize_string "$read${input:0:1}" "${input:1}"
			;;
	esac

	return "$?"
}

tokenize_literal() {
	local read="$1"
	local input="$2"

	if [[ "${input:0:1}" =~ [0-9a-zA-Z._] ]]; then
		tokenize_literal "$read${input:0:1}" "${input:1}"
	else
		echo "LITERAL:$read"
		tokenize "$input"
	fi

	return "$?"
}
