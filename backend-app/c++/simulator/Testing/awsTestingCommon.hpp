#ifndef __AWS_TESTING_COMMON_HPP
#define __AWS_TESTING_COMMON_HPP

//! \internal
//! \file awsTestingCommon.hpp
//! \brief Common includes for testing and few helper templates.
//! \author Miroslav Stoyanov
//! \ingroup AwesomeTesting

//! \internal
//! \defgroup AwesomeTesting Testing for the AWESOME library.
//!
//! \par Testing
//! Tests the various components of the library. There are several helper functions, e.g., compute the norm
//! of a vector, and several **test_** functions that test the specific functionality.

#include "Awesome.hpp" // main header

#include <limits> // for max-int
#include <cmath>

#include <ostream>   // consistent I/O definitions
#include <string>
#include <iomanip>

using std::cout;
using std::cerr;
using std::endl;
using std::setw;
using std::string;

const int wfirst = 30;
const int wsecond = 8;

template<typename typeFP>
void reportPass(const string &test_name){
//! \internal
//! \brief Outputs the test_name + <float/double> + Pass, e.g., "test_matvec<float>() Pass"
//! \ingroup AwesomeTesting
    std::string result(test_name);
    result += "<";
    result += ((sizeof(typeFP) > 4) ? "double" : "float");
    result += ">()";
    cout  << setw(wfirst) << result << setw(wsecond) << "Pass" << endl;
}

template<typename typeFP>
typeFP diffnorm1(const std::valarray<typeFP> &x, const std::valarray<typeFP> &y){
//! \internal
//! \brief Compute the 1-norm of the difference between the two vectors.
//! \ingroup AwesomeTesting
    if (x.size() != y.size()) return 1.E+5; // enough to fail any test
    typeFP err = 0.0;
    for(size_t i = 0; i < x.size(); i++) err += fabs(x[i] - y[i]);
    return err;
}

template<typename typeFP>
typeFP norm1(const std::valarray<typeFP> &x){
//! \internal
//! \brief Compute the 1-norm of the vector.
//! \ingroup AwesomeTesting
    typeFP err = 0.0;
    for(auto &v : x) err += fabs(v);
    return err;
}

#endif
