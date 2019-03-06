# Doxygen


Link: http://www.doxygen.nl/

Having the proper Application Programming Interface (API) documentation in a portable format (`e.g.` pdf, html) enhances the interaction between a user and a product. In order to fill deliverable content, Doxygen is the de-facto tool to generate documentation for C++ source code, not it's not required to have it in a separate location enchancing the user and developer experience. It also supports other languages (see website for more details). 

The basic idea is to document your class, functions and members declarations in *.h (not definitions in .cpp) as comments in a format that the doxygen tool can parse and understand to generate a variety of portable formats.

Doxygen's goal is to have a high-level description of your source code in a human-readable way. It allows you to document function arguments, return types, and possible exceptions before looking at any line of code. In addition, it will also generate a class tree hierarchy and relational graphs (requires graphviz). 

Below is an example illustrating doxygen's format in a class:

```
/** @brief defines class ADIOS as the initial point of the ADIOS2 library */
class ADIOS
{

public:
    /**
     * Starting point for MPI apps. Creates an ADIOS object
     * @param comm defines domain scope from application
     * @param debugMode true: extra user-input debugging information, false: run
     * without checking user-input (stable workflows)
     * @exception std::invalid_argument in debugMode = true if user input is
     * incorrect
     */
    ADIOS(MPI_Comm comm, const bool debugMode = true);

    /**
     * Starting point for MPI apps. Creates an ADIOS object allowing a
     * runtime config file.
     * @param configFile runtime config file
     * @param comm defines domain scope from application
     * @param debugMode true: extra user-input debugging information, false:
     * run without checking user-input (stable workflows)
     * @exception std::invalid_argument in debugMode = true if user input is
     * incorrect
     */
    ADIOS(const std::string &configFile = "", MPI_Comm comm = MPI_COMM_SELF,
          const bool debugMode = true);

    /**
     * Declares a new IO class object
     * @param name unique IO name identifier within current ADIOS object
     * @return reference to newly created IO object inside current ADIOS
     * object
     * @exception std::invalid_argument if IO with unique name is already
     * declared, in ADIOS debug mode only
     */
    IO DeclareIO(const std::string name);
    
    ...

};
```

In addition, Doxygen is nicely integrated into several IDEs (`e.g.` Eclipse eclox) to facilitate automatic generation of the doxygen format once a signature declaration is defined. That way, the developer will just focus on documentation content rather than formatting. 

Example:

Initially, attempting to add doxygen formatted comments with `/**`

```

	/**
	IO DeclareIO(const std::string name);
```

will autocomplete to:

```
    /**
     * 
     * @param name 
     * @return
     */
    IO DeclareIO(const std::string name);
```
        