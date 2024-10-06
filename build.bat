@echo off

odin build src -collection:pkg=pkg -out:bin/flightsim-debug.exe -debug -vet -vet-style -vet-semicolon -subsystem:console
