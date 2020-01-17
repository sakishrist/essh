#!/bin/bash

# Declare the following two variables before executing essh to let it know what
# to transfer to the remote machine

#
# List all the functions that you want to inject on the remote system.
# essh is usually desireble to be able to hop arround and have your functions with you.
#
# ESSH_FUNCTIONS="essh bin2int int2bin sshrm ts ts2 injection"

#
# List the aliases to inject.
#
# ESSH_ALIASES="chn gtree srsync wget openports"
# ESSH_SCRIPTS=("/home/user/script.sh")

__ESSH_ESCAPE () {
  echo -n "$1" | sed 's/\\/\\\\/g;s/\$/\\$/g;s/"/\\"/g'
}

__ESSH_QUOTE () {
  echo -n "\""
  cat
  echo -n "\""
}

__ESSH_ESCAPE_ARGS () {
  local res

  for i in "$@"; do
    res+="${res:+ }"
    res+="$(__ESSH_ESCAPE "$i" | __ESSH_QUOTE)"
  done

  echo "$res";
}

__ESSH_ESCAPE_FILES () {
	sed 's/\\/\\\\/g;s/\$/\\$/g;s/"/\\"/g' "$@"
}

__ESSH_GET_CODE_TEXT () {
  local scripts functions aliases esshDependencies

  # Add all essh and sgo functions to the list
  esshDependencies="essh injection __ESSH_PREAMBLE __ESSH_GET_CODE_TEXT __ESSH_ESCAPE_FILES __ESSH_ESCAPE_ARGS __ESSH_QUOTE __ESSH_ESCAPE"
  esshDependencies+=" __SGO_PARSE_RULE __SGO_HANDLE sgoInit __SGO_DEBUG __SGO_DEBUG_END sgo"


  # Get the function definitions as they are currently known by the running bash.
  # This means that we do not read from a file and can perform this step again
  # on the remote host to transfer the functions a second time to the next hop.
  if [[ -n ${ESSH_FUNCTIONS// } ]]; then
    functions="$(declare -f $ESSH_FUNCTIONS $esshDependencies)""$n"
  fi

  # Get the alias definitions
  if [[ -n ${ESSH_ALIASES// } ]]; then
    aliases="$(alias $ESSH_ALIASES)""$n"
  fi

  # for script in "${ESSH_SCRIPTS[@]}"; do
  #   file=${script##*/}
  #   escapedFile=${file//./_}
  #   scripts+="$escapedFile=\"$(__ESSH_ESCAPE_FILES "$script")\"$n"
  #   scripts+="alias $file='bash -c \"\$$escapedFile\" $file'$n"
  #   ESSH_ALIASES+=" $file"
  # done

  echo "ESSH_FUNCTIONS='$ESSH_FUNCTIONS'"
  echo "ESSH_ALIASES='$ESSH_ALIASES';"
  #echo "$scripts"
  echo "$n$functions"
  echo "$n$aliases"
}

__ESSH_PREAMBLE () {
  # If the version of the remote bash has the pipe sourcing bug, tell the user to manually
  # run the script in the $init variable and define the function on that end.
  echo "if [[ \$BASH_VERSINFO -lt 4 ]]; then"
  echo "echo 'execute: eval \"\$init\" (quotes are important)'"
  echo "exec \$SHELL"
  echo "fi"

  # rcfile option instructs the remote bash to read the initialization script (.bashrc)
  # from the pipe instead of from the regular location.
  if [[ $1 == "-r" ]]; then
    echo -n 'exec $SHELL --rcfile '
  elif [[ $1 == "-l" ]]; then
    echo -n "$SHELL --rcfile "
  fi

  # Construct the pipe
  echo -n "<("
  # Read the original bashrc
  echo -n " cat ~/.bashrc;"
  # Append the prepared init script
  echo -n " echo; echo \"\$init\"; "
  echo ");"
}

# Prepare the script to be executed on the remote system.
injection () {
	local injection n=$'\n' codeText

	if ! [[ $1 =~ ^-(n|l|r)$ ]]; then
		return 1
	fi

	# This part tells the remote end to store the definitions of the functions in a variable
	# This is usefull if the remote end has a bash version older than 4 and has the
	# pipe sourcing bug.
  codeText="$(__ESSH_GET_CODE_TEXT)"

	if [[ $1 != "-n" ]]; then
    injection+="export init=\"$(__ESSH_ESCAPE "$codeText")\";"$'\n'
    injection+="$(__ESSH_PREAMBLE $1)"
	else
		echo "$codeText"
		return 0
	fi

	echo "$injection"
}


essh () { #DOC: Like ssh but make available some function you have declared. Note that this will suppress the motd.
	sgoInit '![1|2|4|6|A|a|C|f|G|g|K|k|M|N|n|q|s|T|t|V|v|X|x|Y|y]
	         !{b|c|D|E|e|F|I|i|L|l|m|O|o|p|Q|R|S|W|w}';
	sgo "$@"
	shift $__SGO_SHIFT;
	args=("$__SGO_IGNORE")
  host="$1"
  shift
  cmd="$(__ESSH_ESCAPE_ARGS "$@")"
	if [[ -n $host && $# -eq 0 ]]; then
		# Start an ssh session and run the commands prepared by injection()
    if [[ -n $args ]]; then
      ssh -t "$args" "$host" "$(injection -r)"
    else
      ssh -t "$host" "$(injection -r)"
    fi
  elif [[ -n $host && $# -gt 0 ]]; then
    if [[ -n $args ]]; then
      ssh "$args" "$host" "$(injection -n) "$'\n'"$cmd"
    else
      ssh "$host" "$(injection -n) "$'\n'"$cmd"
    fi
	else
		# In case the user did not provide any argument, just run ssh to show the help message.
		ssh
	fi
}
