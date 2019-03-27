# Static Analysis

Static analysis complement the job of the compiler providing extra information, only known at compile time (without executing the code), to improve the code quality. While compilers can add extra ({\it e.g.} gcc -Wextra) checks, they are required to pass all warnings if code is correct and meets the language standards. 


Common types of advice is related to:
1. Unused variables
2. Possible memory corruption (leaks, out of bounds access)
3. Missing return objects
4. Unintialized variables 
 
Some commonly used product for C++:

- clang-analyzer

http://clang-analyzer.llvm.org/available_checks.html

- Eclipse CDT

https://wiki.eclipse.org/CDT/designs/StaticAnalysis

- Codacy

https://www.codacy.com/

- Klockwork

https://www.roguewave.com/products-services/klocwork/static-code-analysis

- Visual Studio

https://docs.microsoft.com/en-us/visualstudio/code-quality/code-analysis-for-managed-code-overview?view=vs-2017
