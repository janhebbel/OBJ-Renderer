@echo off

odin build src -out:bin/flightsim-debug.exe -debug -vet -vet-style -vet-semicolon -subsystem:windows
