@echo off

odin build src -collection:pkg=../../pkg -out:bin/assetpp.exe -debug -vet -vet-style -vet-semicolon -subsystem:console
