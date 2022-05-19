#!/bin/env nu

def main [
    type: string # Whether to build the app executable or game.so
] {
    mkdir bin
    if $type == "app" {
        echo "Error: app is not a valid type anymore"
        # cd bin
        # odin build ../src/app -debug
    } else if $type == "game" {
        cd bin
        odin build ../src/game -debug -o:minimal -show-timings -thread-count:8 -use-separate-modules
        # touch game.so
    } else if $type == "run" {
        .\bin\game.exe
    }
}
