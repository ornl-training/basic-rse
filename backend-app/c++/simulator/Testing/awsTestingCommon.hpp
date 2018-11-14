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

using namespace AWSM;

using std::cout;
using std::cerr;
using std::endl;
using std::setw;
using std::string;

//! \internal
//! \brief Outputs the \b test_name + <float/double> + Pass, e.g., "test_matvec<float>() Pass" (used for linear algebra testing)
//! \ingroup AwesomeTesting
template<typename typeFP>
void reportPass(const string &test_name){
    std::string result(test_name);
    result += "<";
    result += ((sizeof(typeFP) > 4) ? "double" : "float");
    result += ">()";
    cout  << setw(45) << result << setw(5) << "Pass" << endl;
}

//! \internal
//! \brief Write out in consistent formatting \b boundary_value + \b boundary_type + \b error_type + Pass (used for PDE testing)
//! \ingroup AwesomeTesting
template<bool steady = true>
void reportPDEPass(const char *boundary_type, const char *boundary_value, const char *error_type){
    cout << setw(10) << boundary_value << setw(12) << boundary_type << setw(8) << error_type << setw(10) << "Pass" << endl;
}

//! \internal
//! \brief Compute the 1-norm of the difference between the two vectors.
//! \ingroup AwesomeTesting
template<typename typeFP>
typeFP diffnorm1(const std::valarray<typeFP> &x, const std::valarray<typeFP> &y){

    if (x.size() != y.size()) return 1.E+5; // enough to fail any test
    typeFP err = 0.0;
    for(size_t i = 0; i < x.size(); i++) err += (typeFP) fabs(x[i] - y[i]);
    return err;
}

//! \internal
//! \brief Compute the 1-norm of the vector.
//! \ingroup AwesomeTesting
template<typename typeFP>
typeFP norm1(const std::valarray<typeFP> &x){

    typeFP err = 0.0;
    for(auto &v : x) err += fabs(v);
    return err;
}

//! \internal
//! \brief Compute the approximate max-norm of the function represented by **state** and the given **solution()** (considers only the nodes)
//! \ingroup AwesomeTesting
template<typename typeFP, typename typeIdx = int>
typeFP continuousNorm1(const std::valarray<typeFP> &state, typeIdx num_x, typeIdx num_y,
                       std::function<typeFP(typeFP x, typeFP y)> solution){

    typeFP dx = 1.0 / ((typeFP) (num_x - 1)), dy = 1.0 / ((typeFP) (num_y - 1));

    typeFP nodey = 0.0, nrm = 0.0;

    for(typeIdx i=0; i<num_x; i++){
        typeFP nodex = 0.0;
        for(typeIdx j=0; j<num_y; j++){
            nrm += fabs(state[(size_t)(i * num_x + j)] - solution(nodex, nodey));
            nodex += dx;
        }
        nodey += dy;
    }

    return nrm * dx * dy;
}

//! \internal
//! \brief Compute the approximate max-norm of the function represented by **state** and the given **solution()** (considers only the nodes)
//! \ingroup AwesomeTesting
template<typename typeFP, typename typeIdx = int>
typeFP continuousNormInfty(const std::valarray<typeFP> &state, typeIdx num_x, typeIdx num_y,
                           std::function<typeFP(typeFP x, typeFP y)> solution){

    typeFP dx = 1.0 / ((typeFP) (num_x - 1)), dy = 1.0 / ((typeFP) (num_y - 1));

    typeFP nodey = 0.0, nrm = 0.0;

    for(typeIdx i=0; i<num_x; i++){
        typeFP nodex = 0.0;
        for(typeIdx j=0; j<num_y; j++){
            typeFP err = fabs(state[(size_t)(i * num_x + j)] - solution(nodex, nodey));
            if (nrm < err) nrm = err;
            nodex += dx;
        }
        nodey += dy;
    }

    return nrm;
}

//! \internal
//! \brief Returns the relative deviation between the observed convergence rate and the expected rate of 2.0, assumes that the mesh density doubles from one \b error to the next
//! \ingroup AwesomeTesting
template<typename typeFP>
typeFP convergenceRateDeviation(const std::valarray<typeFP> &error, typeFP expected_rate = 2.0){

    std::valarray<typeFP> convergence_rate(0.0, error.size() - 1);
    for(size_t i=0; i<error.size()-1; i++)
        convergence_rate[i] = log(error[i] / error[i+1]) / log(2.0); // the two comes from the ratios of delta-x

    std::valarray<typeFP> erate(expected_rate, convergence_rate.size());

    // apparently valarray can use abs() but not fabs(), and valarray is supposed to be a good structure for floating point operations!?
    erate -= convergence_rate;
    for(auto &r : erate) r = fabs(r);

    return erate.max() / expected_rate;
}

#endif
