__init() {
	if ! include "json"; then
		return 1
	fi

	return 0
}

node_new() {
	local -i num_tokens="$1"
	local type="$2"
	local data="$3"

	local node

	if ! node=$(json_object "num_tokens" "$num_tokens" \
				"type"       "$type"       \
				"data"       "$data"); then
		return 1
	fi

	echo "$node"
	return 0
}

node_get_type() {
	local node="$1"

	if ! jq -r -e '.type' <<< "$node"; then
		return 1
	fi

	return 0
}

node_get_data() {
	local node="$1"

	if ! jq -r -e '.data' <<< "$node"; then
		return 1
	fi

	return 0
}

node_get_child() {
	local node="$1"
	local child="$2"

	if ! jq -r -e ".data.$child" <<< "$node"; then
		return 1
	fi

	return 0
}

node_get_num_tokens() {
	local node="$1"

        if ! jq -e '.num_tokens' <<< "$node"; then
		return 1
	fi

	return 0
}

node_next_token_value() {
	local node="$1"
	local tokens=("${@:2}")

	local -i num_tokens
	local next_token
	local next_token_value

	if ! num_tokens=$(node_get_num_tokens "$node"); then
		return 1
	fi

	next_token="${tokens[$num_tokens]}"
	next_token_value="${next_token#*:}"

	if [[ -z "$next_token_value" ]]; then
		return 1
	fi

	echo "$next_token_value"
	return 0
}
