
####
# "log" api: helper functions that write to stderr
####
# eche: Same as `echo`, but write to stderr
eche () { >&2 echo "$@"; }
# _log: Same as `eche`, preceding output with `[$$]#$BASH_SUBSHELL ($1): `
# TODO
# - test it is working as expected
# - support multiple flags on same call. Actually only 1 flag (per call) is supported
_log () {
  #TODO assert arguments length >= 2, assert $1 is one of V[1-9], II, WW, EE
  local stamp="[$$]#$BASH_SUBSHELL (${1?'log level is required'}): " flags="" args="${@:2}"
  if [[ $2 == '-n' ]]; then flags="-n "; args="${@:3}"; fi
  # re-format multiline messages to maintain visual consistency
  # Reformating multiline outputs is NOT NECCESARY if -e is not set
  if [[ $2 == '-e' ]]; then flags="-e "; args="${@:3}"; args=${args//\n/\n${stamp}+i: }; fi
  # TODO pretty formating with asscii for multiline (instead '+i: ')
  eche ${flags}${stamp}"${args}"
  # do not quote, or flags become part of the message
}
# info: logs an informational message
info () { _log II $@; }
# warn: logs a warning message
warn () { _log WW $@; }
# emsg: logs an error message
emsg () { _log EE $@; }
# TODO
# - verb: logs a verbose message
# - dlog: echoes the name action to use for verbose messages?
# - noop: empty function that does nothing
# - verbosity levels (V0 to V9), VV = all

####
# fail: same as `emsg`, but also writes a call trace and exits with code=1
# `fail` allows [fail early] "exit code catchs" like:
#     `( false ) || { echo "error description"; exit 1; }`
#     `(exit -1) || { code=$?; echo "catched code $code"; exit $code; }`
# as:
#     `( false ) || fail "error description"`
#     `(exit -1) || fail "catched code $?"`
#
# Helper function to [fail early](http://stackoverflow.com/a/2807375/1894803)
# Aditionally adds a call trace.
# TODO optional exit status code?
####
fail () { emsg $@; call_trace 0 >&2; exit 1; }

##
# abc sources by default abc-*.bash
# TODO ugly hardcoded source calls. Fix and use glob pattern
# ls -l bash/*.bash
source "bash/abc-call_trace.bash" || exit
source "bash/abc-is.bash" || exit
