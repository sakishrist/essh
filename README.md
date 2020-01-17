# Extended SSH

An ssh wrapper that transfers functions and aliases to the remote machine without littering and creating additional files.

## Features

- Transfer defined functions to remote machine
- Transfer defined aliases to remote machine
- User instructions for old bash versions
- Carry the functions and aliases when using multiple hops
- Execute functions with `esudo <functionx> [args]`

## Limitations

- On remote versions of bash that are earlier than 4, there is a bug that prevents sourcing non-regular files and using them with the *--rcfile* option. For this reason, the user is instructed how to perform the initialization.
- Running an interactive shell through sudo does not carry the functions.
- ~~The function currently does not support commands or distinguishing them and will act unpredictably if provided with anything other than ssh options. If you need to specify a command to be executed on the remote end, use ssh instead as essh is only useful for interactive sessions.~~ This is now implemented and functions can be used as commands directly: `essh host int2bin 123`

## Usage

Source the script in your bashrc file and define the ESSH_FUNCTIONS and ESSH_ALIASES to list the items you want defined at the remote end. Do not include any of the essh functions; they are included by default and hopping via several nodes will work out of the box.

```sh
ESSH_FUNCTIONS="bin2int int2bin sshrm ts ts2"
ESSH_ALIASES="chn gtree srsync wget openports"

. essh/essh.sh
```

Then you can login to the remote machine by just running:

```sh
essh remote
```

At this stage, you will have all the listed functions on the remote end.

All ssh options are supported.

### Versions earlier than Bash 4

In case of running a version that has the pipe sourcing bug, a message will be displayed upon login instructing you to run the following:

```sh
eval "$init"
```

After this manual intervention, the behavior is the same.