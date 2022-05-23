#!/bin/env nu

def build [] {
    cd bin
    odin run ../src/game -debug -o:minimal -show-timings -thread-count:8 -use-separate-modules
}

def run [] {
    ./bin/game.bin
}

def main [] {
    mkdir bin

    build
    # let output = (build)
    # if ($output.stderr | size).bytes == 0 {
    #     #run
    # } else {
    #     echo $output.stderr
    # }

}

