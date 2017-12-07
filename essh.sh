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

injection () {
	local injection n=$'\n'

	if [[ -n ${ESSH_FUNCTIONS// } ]]; then
		functions="$(declare -f $ESSH_FUNCTIONS | sed 's/\\/\\\\/g;s/\$/\\$/g;s/"/\\"/g')""$n" # Declare the functions on the remote end
	fi

	if [[ -n ${ESSH_ALIASES// } ]]; then
		aliases="$(alias $ESSH_ALIASES | sed 's/\$/\\$/g;s/"/\\"/g')""$n"
	fi

	injection+="export init=\"ESSH_FUNCTIONS='$ESSH_FUNCTIONS'"$'\n'
	injection+="ESSH_ALIASES='$ESSH_ALIASES';"$'\n'
	injection+="$functions$n$aliases\";"$'\n'
	
	injection+="if [[ \$BASH_VERSINFO -lt 4 ]]; then"$'\n'
	injection+="echo 'execute: eval \"\$init\" (quotes are important)'"$'\n'
	injection+="exec \$SHELL"$'\n'
	injection+="fi"$'\n'
	
	if [[ $1 == "-r" ]]; then
		injection+='exec $SHELL --rcfile '
	elif [[ $1 == "-l" ]]; then
		injection+="$SHELL --rcfile "
	else
		return 1;
	fi

	injection+="<("
	injection+=" cat ~/.bashrc;"
	injection+=" echo; echo \"\$init\"; "
	injection+=")"
	
	echo "$injection"
}


essh () { #DOC: Like ssh but make available some function you have declared. Note that this will suppress the motd.
	if [[ -n $@ ]]; then
		ssh -t "$@" "$(injection -r)"
	else
		ssh
	fi
}