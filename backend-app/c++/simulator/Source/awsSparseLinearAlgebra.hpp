#ifndef __AWS_SPARSE_LINEAR_ALGEBRA_HPP
#define __AWS_SPARSE_LINEAR_ALGEBRA_HPP

#include <numeric>

#include "awsCoreSparseLinearSolvers.hpp"
#include "awsCoreMatrixOperations.hpp"

namespace AWSM{
//!
//! \file awsSparseLinearAlgebra.hpp
//! \brief AWESOME Sparse Linear Algebra
//! \author Miroslav Stoyanov
//! \copyright ???
//! \ingroup AwesomeSLA
//!
//! Realizes the solver templates using the matrix operations
//!

template<typename typeFP, typename typeIdx = int>
unsigned
int solveCGILU(typeFP tolerance, unsigned int max_iterations,
                const std::valarray<typeIdx> &pntr, const std::valarray<typeIdx> &indx, const std::valarray<typeFP> &vals,
                const std::valarray<typeIdx> &diag, const std::valarray<typeFP> &ilu,
                const std::valarray<typeFP> &b, std::valarray<typeFP> &x){
//! \brief Conjugate-Gradient solver with pre-computed ILU preconditioner
//! \ingroup AwesomeSLA

//! Solves \f$ A x = b \f$ using the Conjugate-Gradient method and Incomplete LU preconditioner.
//! - \b typeFP is a floating point type, e.g., \b float or \b double
//! - \b typeIdx is the signed integer indexing type, e.g., \b int or \b long long
//! - the matrix is stored in row-compressed format in \b pntr, \b indx, \b vals
//! - the ILU factor is stored in \b diag and \b ilu
//! - \b b is the right-hand side of the equation
//! - \b x is the initial guess of the iteration and the final solution
//! - returns the number of iterations, i.e., number of matrix-vector multiplications

    return solveCGtemp<typeFP, std::valarray<typeFP>>(
            // description of the operators
            [&](const std::valarray<typeFP> &lx, std::valarray<typeFP> &lr) -> void{ // preconditioner
                 if (lr.size() != lx.size()) lr.resize(lx.size());
                 spApplyILU<typeFP, typeIdx>(pntr, indx, diag, ilu, lx, lr);
             },
             [&](const std::valarray<typeFP> &lx, std::valarray<typeFP> &lr) -> void{ // matrix vector product
                 lr.resize(lx.size());
                 spMatVec<typeFP, typeIdx>(1.0, pntr, indx, vals, lx, 0.0, lr);
             },
             b, x, // right-hand-side and the solution
             // description of the vector space
             [&](const typeFP &num, const typeFP &denom, typeFP &ratio) -> void{ ratio = num / denom; }, // scalar division
             [&](const typeFP &src, typeFP &dest) -> void{ dest = src; },                                // scalar move
             [&](const std::valarray<typeFP> &src, std::valarray<typeFP> &dest) -> void{ dest = src; },      // vector copy
             [&](const typeFP &la, std::valarray<typeFP> &ly) -> void{ ly *= la; },          // vector scale
             [&](int dir, const std::valarray<typeFP> &lx, std::valarray<typeFP> &ly) -> void{           // vector add or sub
                 if (dir > 0){
                     ly += lx;
                 }else{
                     ly -= lx;
                 }},
             [&](int dir, const typeFP &la, const std::valarray<typeFP> &lx, std::valarray<typeFP> &ly) -> void{ // vector scaled add/sub
                 if (dir > 0){
                     ly += la * lx;
                 }else{
                     ly -= la * lx;
                 }},
             [&](const std::valarray<typeFP> &lx, const std::valarray<typeFP> &ly, typeFP &la) -> void{  // vector dot-product
                    la = std::inner_product(std::begin(lx), std::end(lx), std::begin(ly), 0.0);
                 },
             [&](unsigned int iterations, const std::valarray<typeFP> &res) -> bool{  // check convergence
                    typeFP norm = 0.0;
                    for(auto r : res) norm += r * r;
                    return ((sqrt(norm) < tolerance) || (iterations >= max_iterations));
                 });
}

template<typename typeFP, typename typeIdx = int>
unsigned
int solveCGILU(typeFP tolerance, unsigned int max_iterations,
                const std::valarray<typeIdx> &pntr, const std::valarray<typeIdx> &indx, const std::valarray<typeFP> &vals,
                const std::valarray<typeFP> &b, std::valarray<typeFP> &x){
//! \brief Conjugate-Gradient solver with pre-computed ILU preconditioner
//! \ingroup AwesomeSLA

//! Solves \f$ A x = b \f$ using the Conjugate-Gradient method and Incomplete LU preconditioner.
//! - computes the preconditioner and calls AWSM::solveCGILU()

    std::valarray<typeIdx> diag;
    std::valarray<typeFP> ilu;
    spFactorizeILU<typeFP, typeIdx>(pntr, indx, vals, diag, ilu);

    return solveCGILU<typeFP, typeIdx>(tolerance, max_iterations, pntr, indx, vals, diag, ilu, b, x);
}

}

#endif
