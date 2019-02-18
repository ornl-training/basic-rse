# Coding Standards


Coding standards should be seen as a communication tool among team collaborators. The important aspect of coding standards is the adoption and enforcement of a coding standard that fits the project's needs. 


A few recommendations when adopting a standard:

1.  Focus on your project needs first, not the standard itself. 

2.  Make sure everyone follows, enforce it through checks if necessary (part of continuous integration).

3.  While coding style, formatting and standards can be intermixed, standards are a larger set of rules.

4.	Pick and existing standard rather than create your own. Existing standards come with tooling around a format (e.g. clang-format) that can be integrated into an IDE (e.g. Eclipse CppStyle).

5.  From time to time have code reviews with your peers and discuss adopting new rules in the development process. Remember, the goal is so code is written in a way all team members understand. 
 

Many existing coding standards were fomulated to satisfy project specific requirements at a certain time. Not all of them might make sense for the nature of your project, please review their design philosophy and goals before picking a standard. 
The following is a (short) list of well-known projects' coding standards:	

C++
	
- https://github.com/isocpp/CppCoreGuidelines/blob/master/CppCoreGuidelines.md

- https://clang.llvm.org/docs/ClangFormat.html

- https://google.github.io/styleguide/cppguide.html

- https://github.com/Microsoft/GSL

- http://astyle.sourceforge.net/

C

- https://www.kernel.org/doc/html/v4.10/process/coding-style.html

Python

- https://www.python.org/dev/peps/pep-0008/ 

Java

- https://google.github.io/styleguide/javaguide.html

- https://www.oracle.com/technetwork/java/codeconventions-150003.pdf (from 1997)

Fortran

- http://www.cesm.ucar.edu/working_groups/Software/dev_guide/dev_guide/node7.html#SECTION00071000000000000000