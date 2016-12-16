#!/bin/bash

source "$(iai path bash/abc-call_trace.bash)"

# emulates some call_traces with hops to test log machinery
a-trace(){ b; }; b(){ c; }; c(){ call_trace; }
x-trace() { y; } ; y() { z; } ; z() { call_trace; }

A=$(a-trace); echo -e "example trace 1:\n$A"
B=$(x-trace); echo -e "example trace 2:\n$B"

diff <(echo "$A") <(echo "$B")

