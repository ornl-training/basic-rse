find_package(Doxygen OPTIONAL_COMPONENTS dot)

if (NOT DOXYGEN_FOUND)
    # normally missing packages should generate an error
    message(WARNING "AWESOME could not find Doxygen, skipping documentation")
    return()
endif()

set(DOXYGEN_GENERATE_HTML      "YES")
set(DOXYGEN_DISABLE_INDEX       "NO")
set(DOXYGEN_GENERATE_TREEVIEW  "YES") # left-hand index
set(DOXYGEN_SORT_GROUP_NAMES    "NO") # use the order in the source files (logical order)
set(DOXYGEN_SORT_BRIEF_DOCS     "NO")
set(DOXYGEN_SORT_MEMBER_DOCS    "NO")

set(DOXYGEN_HTML_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/../html/") # this is the main build folder, must change to install

set(DOXYGEN_HTML_EXTRA_STYLESHEET  ${CMAKE_CURRENT_SOURCE_DIR}/awesome.css)
set(DOXYGEN_FORMULA_FONTSIZE "18") # must be large since Doxygen is not using vector graphics which gives horrible font aliasing
set(DOXYGEN_HTML_COLORSTYLE_HUE    "330") # purple-ish pages, with box color rgb(248,241,245)
set(DOXYGEN_HTML_COLORSTYLE_SAT    "100")
set(DOXYGEN_HTML_COLORSTYLE_GAMMA  "200")

# The default project name and number do not look official enough
set(DOXYGEN_PROJECT_NAME   "AWESOME: Advanced Web-Enabled Solver Of Math Equations v${AWESOME_VERSION_MAJOR}.${AWESOME_VERSION_MINOR}")
set(DOXYGEN_PROJECT_NUMBER "")

# Use the existing markdown main page
set(DOXYGEN_USE_MDFILE_AS_MAINPAGE "${CMAKE_CURRENT_SOURCE_DIR}/../README.md")

doxygen_add_docs(AWESOME_docs
                 ${CMAKE_CURRENT_SOURCE_DIR}/../README.md
                 ${CMAKE_CURRENT_SOURCE_DIR}/../Source/awsCoreMatrixOperations.hpp
                 ${CMAKE_CURRENT_SOURCE_DIR}/../Source/awsCoreSparseLinearSolvers.hpp
                 ${CMAKE_CURRENT_SOURCE_DIR}/../Source/awsSparseLinearAlgebra.hpp
                 ${CMAKE_CURRENT_SOURCE_DIR}/../Testing/awsTestingCommon.hpp
                 ${CMAKE_CURRENT_SOURCE_DIR}/../Testing/linear_algebra_tests.cpp
                 WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
                 COMMENT "Building the AWESOME documentation")

#add_custom_target(AWESOME_doxygen ALL DEPENDS AWESOME_docs) # this will include the documentation in make all
