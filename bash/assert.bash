source "bash/abc.bash"
source "bash/basic-str.bash"

##
# General use assert-failed action: Use "fail" to report error and exit
#TODO descriptive exit codes?
assert_e () {
  ! is_int $1 && fail "assertion error: $@";
  local c=$1; shift; emsg "assertion error: $@"; exit $c
}

#TODO assert_var_set: http://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash

##
# String assertions
assert_str () { [[ -n "$1" ]] || assert_e "'$1' must be an string"; }

##
# Integer assertions
assert_int () { is_int $1 || assert_e "'$1' must be an integer"; }
# Asserts $1 is an even integer. From http://stackoverflow.com/q/15659848/1894803
# NOTE: Observe aritmetic expression has exit status 1 if result = 0. Learn: `help "(("`
assert_int_par () { { ! (( ${1} % 2 )); } || assert_e "'$1' must be an even integer"; }
assert_int_odd () { (( ${1} % 2 )) || assert_e "'$1' must be an odd integer"; }

assert_e_ENOENT () { assert_e  "'$@' does not exist"; }
assert_dir_exists () { [[ -d "$1" ]] || assert_e_ENOENT "$1"; }
assert_file_exists () { [[ -f "$1" ]] || assert_e_ENOENT "$1"; }

##
# Asserts global variable scope is writable ($BASH_SUBHELL=0)
# - arg $1: optional error message to replace the default message
assert_global_scope () {
  if [[ $BASH_SUBSHELL != 0 ]]; then
    local msg=${1:-'Write access to the global variable scope is required'}
    read line fn file <<< $(caller 1) # omit the assert call from trace
    assert_e "$msg:\nAt (file:line) $file:$line\n'$fn' runs in a lvl $BASH_SUBSHELL bash subshell." 
    # fail performs an exit, so while loop below never runs
    # TODO would be awesome to stop the main process at subshell 0,
    # IS POSSIBLE? HOW?
    while [[ $BASH_SUBSHELL != 0 ]]; do exit 1; done
  fi
}

##
# Asserts previous command exit code ($?) was '$1'
# - exit codes with special meanings http://www.tldp.org/LDP/abs/html/exitcodes.html
assert_code () {
  local xcode=$?; if test "$xcode" -eq "$1"; then return 0; fi
  local ecode=$((xcode+1));
  case "$xcode" in 255) ecode=$xcode ;; esac
  assert_e $ecode "exit code was $xcode, while expecting $1."
}

assert_function () {
  assert_str "$1"
  is_function "$1" || assert_e "'$1' does not pass is_function test"
}

##
# util to test that two sources output the same
# diff quick reference:  `diff --help`
# TODO refactor the ansi thing.
BASHIDO_ASSERT_RESET=""  # "reset attributes" to default
BASHIDO_ASSERT_BEGIN=""  # signals a literal value display start
BASHIDO_ASSERT_TRAIL=""  # signals a literal value display finish
BASHIDO_ASSERT_ACTUAL="" # part of "actual" value that was not expected
BASHIDO_ASSERT_EXPECT="" # part of "expected" value not found within actual
BASHIDO_ASSERT_FCOLOR=""
BASHIDO_ASSERT_BCOLOR=""
diff_test () {
  local source1="${1:?"$FUNCNAME: missing source 1 (arg='$@')"}"
  local source2="${2:?"$FUNCNAME: missing source 2 (arg='$@')"}"
cat <<DEBUG >/dev/null
  $FUNCNAME (called at $(caller 0))
	source1=$source1
	source2=$source2
DEBUG
  # side-by-side mode is not enough to ease viewing trailing spaces
	# TODO side-by-side ignores colorizing.
	# Consider alternatives, see http://stackoverflow.com/questions/8800578/colorize-diff-on-the-command-line
	# when sources are files, use cat -A to ease viewing non-printing characters
	if [ -a "$source1" ] && { [ -a "$source2" ] || test "$source2" == "-"; }
	then
		#local dlf="%c'^'%l%c'$'%c'\012'" # diff line format
		local old="$(tput setab 3)"
		local new="$(tput setab 2)"
		local clr="$(tput sgr0)"
		local all="$(tput setab 7)$(tput setaf 0)"
		local w=$(tput cols) bar="|"
		if ! (( w % 2 )); then bar="||"; fi # TODO configurable bar means if bar is odd too
		w=$(( (w - ${#bar}) / 2 )) # odd column number requires an odd-lengthed bar
		local n=0 prev=""
		while IFS= read line; do
			if (( ++n % 2 )); then prev="$line"; continue; fi
			# at even lines, $line is expected (new), $prev is actual (old)
			local c=0; while test $c -lt ${#line}; do
				test "${prev:$c:1}" != "${line:$c:1}" && break
				((c++))
			done
			printf -v actual '^%s%b%s%b' "${prev:0:$c}" "$old" "${prev:$c}" "$all"
			local wa="$(str_ansifilter "$actual")"; wa=$(( w + ${#actual} - ${#wa} ))
			printf -v expect '%s%b%s%b$' "${line:0:$c}" "$new" "${line:$c}" "$all"
			local we="$(str_ansifilter "$expect")"; we=$(( w + ${#expect} - ${#we} ))
			printf "%b%${wa}s%b%s%b%-${we}s%b\n" "$all" "$actual" "$clr" "$bar" "$all" "$expect" "$clr"
			# seems better using diff to 
		done	< <(diff --unchanged-line-format='' "$source1" "$source2")
		test $n -eq 0; return $?
	fi
	fail "$FUNCNAME: assert equality for non-files not implemented yet"
}

##
# assertion helpers for TDD (should not been used for implementations)

##
# asserts that command line ($1) exit status code is equal to $2
# - stdout/stderr from `eval $1` are preserved/ignored depending on $2 value
# - When $2==0 stdout is ignored and stderr is preserved
# - When $2>=1 stdout is ignored and stderr is ignored too.
# - An assertion error raises when exit code does not match
# IMPORTANT
# - $1 is executed with `eval` to research the exit code
# - `eval` is used for a sake of simplicity, althought it's not "elegant"
# - this function is only for writing test cases
# REFERENCE
# - http://mywiki.wooledge.org/BashFAQ/050
assert_1_returns_2 () {
  assert_str $1 ; assert_int $2
  if test $2 -eq 0
  then ( eval $1 ) 1>/dev/null ; # ignore stdout
  else ( eval $1 ) &>/dev/null ; # ignore stdout and stderr
  fi # eval in subshell to avoid premature exit triggered by eval'ed code
  local xcode=$?; if test "$xcode" -eq "$2"; then return 0; fi
  assert_e "After running '$1' exit code was $xcode, while expecting $2."
  # Code match implies success, elsecase it's failure (even when xcode=0)
}

##
# asserts that command line ($1) stdout is as described in $2
# TODO
# - The procedure should be writen to compare-by-character?
#   Using `diff` because the output from `cmp` is not descriptive enought
assert_1_outputs_2 () {
# - should use --suppress-common-lines too?
  diff --width=$(tput cols) --color=always <(eval $1) <(echo "$2")
}
##
# vim modeline
# /* vim: set filetype=sh shiftwidth=2 ts=2: */
