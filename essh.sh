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

# Prepare the script to be executed on the remote system.
injection () {
	local injection n=$'\n' scripts functions aliases



	# Get the function definitions as they are currently known by the running bash.
	# This means that we do not read from a file and can perform this step again
	# on the remote host to transfer the functions a second time to the next hop.
	if [[ -n ${ESSH_FUNCTIONS// } ]]; then
		functions="$(declare -f $ESSH_FUNCTIONS)""$n"
	fi

	# Get the alias definitions
	if [[ -n ${ESSH_ALIASES// } ]]; then
		aliases="$(alias $ESSH_ALIASES)""$n"
	fi

	for script in "${ESSH_SCRIPTS[@]}"; do
		file=${script##*/}
		escapedFile=${file//./_}
		scripts+="$escapedFile=\"$(__ESSH_ESCAPE_FILES "$script")\"$n"
		scripts+="alias $file='bash -c \"\$$escapedFile\" $file'$n"
		ESSH_ALIASES+=" $file"
	done

	# This part tells the remote end to store the definitions of the functions in a variable
	# This is usefull if the remote end has a bash version older than 4 and has the
	# pipe sourcing bug.
	injection+="export init=\"ESSH_FUNCTIONS='$ESSH_FUNCTIONS'"$'\n'
	injection+="ESSH_ALIASES='$ESSH_ALIASES';"$'\n'
	injection+=$(__ESSH_ESCAPE "$scripts")
	injection+=$(__ESSH_ESCAPE "$n$functions")
	injection+=$(__ESSH_ESCAPE "$n$aliases")
	injection+="\";"$'\n'

	# If the version of the remote bash has the pipe sourcing bug, tell the user to manually
	# run the script in the $init variable and define the function on that end.
	injection+="if [[ \$BASH_VERSINFO -lt 4 ]]; then"$'\n'
	injection+="echo 'execute: eval \"\$init\" (quotes are important)'"$'\n'
	injection+="exec \$SHELL"$'\n'
	injection+="fi"$'\n'

	# rcfile option instructs the remote bash to read the initialization script (.bashrc)
	# from the pipe instead of from the regular location.
	if [[ $1 == "-r" ]]; then
		injection+='exec $SHELL --rcfile '
	elif [[ $1 == "-l" ]]; then
		injection+="$SHELL --rcfile "
	else
		return 1;
	fi

	# Construct the pipe
	injection+="<("
	# Read the original bashrc
	injection+=" cat ~/.bashrc;"
	# Append the prepared init script
	injection+=" echo; echo \"\$init\"; "
	injection+=")"

	echo "$injection"
}


essh () { #DOC: Like ssh but make available some function you have declared. Note that this will suppress the motd.
	if [[ -n $* ]]; then
		# Start an ssh session and run the commands prepared by injection()
		ssh -t "$@" "$(injection -r)"
	else
		# In case the user did not provide any argument, just run ssh to show the help message.
		ssh
	fi
}
