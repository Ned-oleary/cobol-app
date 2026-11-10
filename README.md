# cobol-app

A COBOL application built with [GnuCOBOL](https://gnucobol.sourceforge.io/).

## Prerequisites

- GnuCOBOL 3.x (`cobc`)
  - macOS: `brew install gnucobol`
  - Debian/Ubuntu: `sudo apt install gnucobol`

## Usage

```sh
make        # build to build/cobol-app
make run    # build and run
make test   # build and run tests
make clean  # remove build output
```

## Layout

```
src/     COBOL sources (free-format, .cbl); main.cbl is the entry point
tests/   test scripts
build/   compiled output (git-ignored)
```
