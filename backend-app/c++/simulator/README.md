# A.W.E.S.O.M.E.

The Advanced Web-Enabled Solver Of Math Equations (AWESOME) is an educational program that solves a simple partial differential equation over a two-dimensional rectangular domain:
```
.... TODO: figure out how to put some basic formulas here
```
### Quick Build (install is not done yet)

AWESOME requires C++-2011 compiler and CMake 3.9.
The documentation requires Doxygen (tested with 1.8.13) with dot component.
Performing out-of-source CMake build:
```
  mkdir Build
  cd Build
  cmake <options> <path-to-awesome-folder>
  make
  make test          (optional: requires enabled testing)
  make AWESOME_docs  (optional: requires enabled Doxygen and graphviz)
  make AWESOME_coverage (optional: requires gcovr and gnu compilers)
```

Available AWESOME CMake options:
```
  -D AWESOME_ENABLE_TESTING=<ON/OFF>  (build the tests, strongly recommended)
  -D AWESOME_ENABLE_DOXYGEN=<ON/OFF>  (build the documentation, requires Doxygen)
  -D AWESOME_ENABLE_PYTHON=<ON/OFF>   (configure the python plotter script to off-line testing)
  -D AWESOME_ENABLE_GCOV=<ON/OFF>     (build target AWESOME_coverage to produce html coverage report)
```

Example CMake command:
```
  cmake \
        -D CMAKE_BUILD_TYPE=Debug \
        -D CMAKE_CXX_FLAGS="-O3" \
        -D BUILD_SHARED_LIBS=ON \
        -D AWESOME_ENABLE_TESTING=ON \
        -D AWESOME_ENABLE_DOXYGEN=ON \
        -D DOXYGEN_INTERNAL_DOCS=YES \
        -D AWESOME_ENABLE_PYTHON=ON \
        -D AWESOME_ENABLE_GCOV=ON \
        <path-to-awesome-folder>
```
* note: a shared library is probably required to interface with the rest of the project, certainly so for python.

### Basic usage:

See Python/plotter.py, which gets configured in the Python sub-folder of the CMake build tree.
Runs the script to see a picture of a Bull's Eye.
```
  python Python/plotter.py   (must be inside the CMake build folder)
```
