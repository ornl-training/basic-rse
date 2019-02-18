# Code Coverage


Code coverage measures the lines of code that are actually touched by your testing bedframe.
Measuring code coverage allows you to identify:

1.	Representative sets of tests in your framework (what lines of code are used the most)

2.	Areas in your code that lack coverage

3.	New test that would trigger coverage of untested lines of code

4. 	Percentage of your code that is being covered (75% overall, critical parts 99%)

5.	Come up with acceptable quality metrics for your tests

---
**NOTE**

Introduce code coverage early on your project so encourage a test driven approach

---


Common code coverage tools: https://stackify.com/code-coverage-tools/

Common open-source ones:

C++ : 

-	https://gcc.gnu.org/onlinedocs/gcc/Gcov.html 

Python

-	https://coverage.readthedocs.io/en/v4.5.x/

## Gcov

Gcov, and its graphical frontend Lcov, is the default gnu (free as is freedom) coverage tool for C and C++ code. It works only if your source code is compiled with the gcc/g++ compiler.

    
Please check the AWESOME test for an example of how to integrate gcov with cmake's ctest