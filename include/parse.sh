__init() {
	if ! include "node" "log"; then
		return 1
	fi

	return 0
}

parse() {
	local tokens=("$@")

	parse_rule_list "${tokens[@]}"
	return "$?"
}

parse_rule_list() {
	local tokens=("$@")

	local rule_list
	local -i used_tokens

	used_tokens=0

	while (( used_tokens < ${#tokens[@]} )); do
		local rule
		local data

		if ! rule=$(parse_rule "${tokens[@]:$used_tokens}"); then
			log_error "Expected rule near \"${tokens[$used_tokens]}\""
			return 1
		fi

		(( used_tokens += $(node_get_num_tokens "$rule") ))

		data=$(json_object "rule" "$rule"     \
		                   "next" "$rule_list")

		rule_list=$(node_new "$used_tokens" "rule_list" "$data")
	done

	echo "$rule_list"
	return 0
}

parse_rule() {
	local tokens=("$@")

	local repository
	local colon
	local logical_or_pkgex
	local semicolon
	local -i used_tokens

	if ! repository=$(parse_identifier "${tokens[@]}"); then
		log_error "Expected identifier near \"${tokens[0]}\""
		return 1
	fi

	used_tokens=1
	colon="${tokens[$used_tokens]}"
	(( ++used_tokens ))

	if [[ "$colon" != "COLON::" ]]; then
		log_error "Expected ':' near \"$colon\""
		return 1
	fi

	if ! logical_or_pkgex=$(parse_logical_or_pkgex "${tokens[@]:$used_tokens}"); then
		log_error "Expected logical-OR-pkgex near \"${tokens[$used_tokens]}\""
		return 1
	fi

	(( used_tokens += $(node_get_num_tokens "$logical_or_pkgex") ))
	semicolon="${tokens[$used_tokens]}"
	(( ++used_tokens ))

	if [[ "$semicolon" != "SEMICOLON:;" ]]; then
		log_error "Expected ';' near \"$semicolon\""
		return 1
	fi

	data=$(json_object "repository" "$repository"       \
	                   "colon"      "$colon"            \
	                   "pkgex"      "$logical_or_pkgex" \
	                   "semicolon"  "$semicolon")

	node_new "$used_tokens" "rule" "$data"
	return "$?"
}

parse_logical_or_pkgex() {
	local tokens=("$@")

	local -i used_tokens
	local logical_or_pkgex

	used_tokens=0
	logical_and_pkgex=""

	while true; do
		local logical_and_pkgex
		local operator
		local data

		if ! logical_and_pkgex=$(parse_logical_and_pkgex "${tokens[@]:$used_tokens}"); then
			log_error "Expected logical-AND-pkgex near \"${tokens[$used_tokens]}\""
			return 1
		fi

		(( used_tokens += $(node_get_num_tokens "$logical_and_pkgex") ))
		operator="${tokens[$used_tokens]}"

		data=$(json_object "right_child" "$logical_and_pkgex" \
		                   "operator"    "$operator"          \
		                   "left_child"  "$logical_or_pkgex")

		logical_or_pkgex=$(node_new "$used_tokens" "logical_or_pkgex" "$data")

		if [[ "$operator" != "OR:||" ]]; then
			break
		fi

		(( ++used_tokens ))
	done

	echo "$logical_or_pkgex"
	return 0
}

parse_logical_and_pkgex() {
	local tokens=("$@")

	local -i used_tokens
	local logical_and_pkgex

	used_tokens=0
	logical_and_pkgex=""

	while true; do
		local primary_pkgex
		local operator
		local data

		if ! primary_pkgex=$(parse_primary_pkgex "${tokens[@]:$used_tokens}"); then
			log_error "Expected primary-pkgex near \"${tokens[$used_tokens]}\""
			return 1
		fi

		(( used_tokens += $(node_get_num_tokens "$primary_pkgex") ))
		operator="${tokens[$used_tokens]}"

		data=$(json_object "right_child" "$primary_pkgex"    \
		                   "operator"    "$operator"         \
		                   "left_child"  "$logical_and_pkgex")

		logical_and_pkgex=$(node_new "$used_tokens" "logical_and_pkgex" "$data")

		if [[ "$operator" != "AND:&&" ]]; then
			break
		fi

		(( ++used_tokens ))
	done

	echo "$logical_and_pkgex"
	return 0
}

parse_primary_pkgex() {
	local tokens=("$@")

	local -i tokens_used
	local data

	if [[ "${tokens[0]}" == "LPAREN:(" ]]; then
		# primary-pkgex = '(' logical-OR-pkgex ')'

		local lparen
		local pkgex
		local rparen

		lparen="${tokens[0]}"
		tokens_used=1

		if ! pkgex=$(parse_logical_or_pkgex "${tokens[@]:$tokens_used}"); then
			log_error "Expected logical-OR-pkgex near \"${tokens[*]:$tokens_used:1}\""
			return 1
		fi

		(( tokens_used += $(node_get_num_tokens "$pkgex") ))
		rparen="${tokens[$tokens_used]}"

		if [[ "$rparen" != "RPAREN:)" ]]; then
			log_error "Expected ')', found \"$rparen\""
			return 1
		fi

		data=$(json_object "lparen" "$lparen" \
		                   "child"  "$pkgex"  \
		                   "rparen" "$rparen")
		(( tokens_used++ ))
	else
		# primary-pkgex = property operator identifier

		local property
		local operator
		local identifier

		if ! property=$(parse_literal "${tokens[@]}"); then
			log_error "Expected literal, found \"${tokens[0]}\""
			return 1
		fi

		tokens_used=1
		if ! operator=$(parse_operator "${tokens[$tokens_used]}"); then
			log_error "Expected operator, found \"${tokens[$tokens_used]}\""
			return 1
		fi
		(( tokens_used++ ))

		if ! identifier=$(parse_identifier "${tokens[$tokens_used]}"); then
			log_error "Expected identifier, found \"${tokens[$tokens_used]}\""
			return 1
		fi
		(( tokens_used++ ))

		data=$(json_object "property"   "$property"  \
		                   "operator"   "$operator"  \
		                   "identifier" "$identifier")
	fi

	node_new "$tokens_used" "primary-pkgex" "$data"
}


parse_operator() {
	local token="$1"

	if [[ "${token%%:*}" != "RELOP" ]]; then
		return 1
	fi

	node_new 1 "RELOP" "${token#*:}"
	return "$?"
}

parse_string() {
	local token="$1"

	if [[ "${token%%:*}" != "STRING" ]]; then
		return 1
	fi

	node_new 1 "STRING" "s:${token#*:}"
	return "$?"
}

parse_literal() {
	local token="$1"

	if [[ "${token%%:*}" != "LITERAL" ]]; then
		return 1
	fi

	node_new 1 "LITERAL" "s:${token#*:}"
	return "$?"
}

parse_identifier() {
	local tokens=("$@")

	if ! parse_string "${tokens[@]}" &&
	   ! parse_literal "${tokens[@]}"; then
		return 1
	fi

	return 0
}
