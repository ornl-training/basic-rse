#ifndef __AWS_CORE_SPARSE_SOLVERS_HPP
#define __AWS_CORE_SPARSE_SOLVERS_HPP

#include <functional>

namespace AWSM{
//!
//! \file awsCoreSparseLinearSolvers.hpp
//! \brief AWESOME Generalized Templated Iterative Linear Solvers
//! \author Miroslav Stoyanov
//! \copyright ???
//! \ingroup AwesomeSLA
//!
//! Contains the Templated Iterative Linear Solvers.
//!

//! \defgroup AwesomeSLA Sparse Linear Algebra
//!
//! \par AWESOME Sparse Linear Algebra
//! Discretization schemes for partial differential equations (PDEs) usually reduce the infinite-dimensional problems
//! to a large (but finite) sparse linear system of equations. The AWESOME library implements several iterative
//! solvers designed to handle different types of sparse matrices.
//!
//! \par Generalized Templates
//! Generalized templates are available for three different solvers:
//! - Preconditioned Conjugate-Gradient (CG) method: designed for symmetric-positive-definite matrices and based on Krylov sub-space prjection
//! - Preconditioned General Minimum Residual (GMRES) method: designed for general matrices and based on Krylov sub-space prjection
//! - Gauss-Seidel (GS) method: designed for diagonally dominant matrices and based on the Fixed-Point-Iteration (a.k.a., contraction approach)
//!
//! \par
//! The generalized templates operate on an abstract math-vector space, which is operated only through a set of \b lambda functions.
//! The advantage of the generalization is that the same solver/template can be easily adjusted to work with vectors implemented
//! using either CPU or GPU memory accross one or more nodes. In addition, the vector data-structures can be also generalized to
//! allow for batch solving, i.e., solve multiple linear systems with either the same or different matrices.
//!
//! \par Matrix Format
//! Currently AWESOME implements only one matrix type using row-compressed format consisting of three arrays:
//! - \b pntr: is an array with the offsets of the indexes of each row and the final entry corresponds to the number of non-zeros
//! - \b indx: is an array with the column indexes of the non-zero entries of the matrix
//! - \b vals: is an array with the numeric values
//!
//! \par
//! The array structures are implemented using \b std::valarray data structures.
//!

//! \brief Iterations for the Preconditioned Conjugate-Gradient method (templated version).
//! \ingroup AwesomeSLA
template<class FPScalar, class FPVector>
unsigned
int solveCGtemp(std::function<void(const FPVector &x, FPVector &r)> apply_preconditioner,
                std::function<void(const FPVector &x, FPVector &r)> apply_operator,
                const FPVector &b, FPVector &x,
                std::function<void(const FPScalar &num, const FPScalar &denom, FPScalar &ratio)> scalar_division,
                std::function<void(FPScalar &src, FPScalar &dest)> scalar_move,
                std::function<void(const FPVector &src, FPVector &dest)> vector_copy,
                std::function<void(const FPScalar &s, FPVector &x)> vector_scale,
                std::function<void(int dir, const FPVector &x, FPVector &y)> vector_xpy,
                std::function<void(int dir, const FPScalar &s, const FPVector &x, FPVector &y)> vector_axpy,
                std::function<void(const FPVector &x, const FPVector &y, FPScalar &s)> vector_dot,
                std::function<bool(int, const FPVector &)> check_converged){
//! Solves \f$ A x = b \f$ using preconditioner **apply_preconditioner()**;
//! effectively solves \f$ E^{-1} A E^{-T} \hat x = E^{-1} b \f$ where the **E** and **A** are linear operators,
//! and returns \f$ x = E^{-T} \hat x \f$; note that **apply_preconditioner()** works with the product \f$ E E^T \f$ only.
//!
//! The solver operates on a general (abstract) vector space, where the vector and scalar operations are defined
//! using the \b lambdas. The vector generalization allows to use one template with vectors allocated on the CPU or GPU
//! or even distributed across a network. The scalar generalization allows for easy implementation of batch solvers,
//! where scalars are vectors, vectors are matrices, and matrices have 3-dimensional structure.
//!
//! The \b FPScalar and \b FPVector classes must have default empty constructors and a default vector must be
//! a valid entry for \b dest, \b r, and \b ratio variable in calls to \b apply_operator(), \b vector_copy(),
//! \b scalar_move(), \b scalar_division(), and \b vector_dot(). For example, if \b FPVector is \b std::vector<double>
//! then \b apply_operator() must call \b resize() on the vector.
//!
//! - \b scalar_division() takes numerator and denominator and returns the ratio.
//! - \b scalar_move() will assign the value of \b src to \b dest, the \b src will only be used as output variable of future calls.
//! - \b vector_copy() assign the value of \b src to the \b dest, but does not alter the source.
//! - \b vector_scale() scale the vector by a scalar
//! - \b vector_xpy() and \b vector_axpy() performs scaled addition, i.e., `y += dir * s * x`, where \b dir is +1 or -1 and indicates only a direction.
//! - \b vector_dot() computes the vector dot-product.
//! - \b check_converged() takes the current iteration count and the residual vector and must return \b True when the iteration should be
//!   terminated, e.g., when the desired tolerance is reached or when the maximum number of iteration is exceeded.

    FPVector r, p, Ap, z;
    FPScalar zr, nzr, a;

    vector_copy(b, r);
    apply_operator(x, p);
    vector_xpy(-1, p, r); // r = b - A x

    apply_preconditioner(r, z); // z = E^-T E^-1 r

    vector_copy(z, p); // p = z

    vector_dot(r, z, zr); // zr = <r, z>

    unsigned int iterations = 1; // applied one Ax with preconditioner
    bool iterate = true;

    while(iterate){
        apply_operator(p, Ap); // Ap = A * p
        iterations++;

        vector_dot(p, Ap, nzr);
        scalar_division(zr, nzr, a); // the correction term alpha = <r, z> / <p, A p>

        vector_axpy( 1, a,  p, x); // x += a * p, x is the new solution state
        vector_axpy(-1, a, Ap, r); // r -= a * ap, r is the new residual

        iterate = !check_converged(iterations, r); // if not converged, keep going

        if (iterate){ // skip this part of done already
            apply_preconditioner(r, z); // z = E^-T E^-1 r

            // keep the new zr = dot(r, z), and get p = z - beta * p, where beta = new_zr / old_zr
            vector_dot(r, z, nzr);
            scalar_division(nzr, zr, a); // p-correction alpha = new <r, z> / old <r, z>

            vector_scale(a, p);
            vector_xpy(1, z, p); // p = z + a p

            scalar_move(nzr, zr); // keep nzr = <z, r> so we do not recompute the dot-product
        }
    }

    return iterations;
}

//! \brief Iterations for the Gauss–Seidel (GMRES) method.
//! \ingroup AwesomeSLA
template<class FPVector>
int solveGuassSeideltemp(std::function<void(const FPVector &x, FPVector &u)> apply_inner,
                         std::function<void(const FPVector &u, FPVector &r)> solve_outer,
                         FPVector &x,
                         std::function<void(FPVector &u, FPVector &v)> vector_swap,
                         std::function<bool(unsigned int iteration, const FPVector &xnew, FPVector &xold)> converged){
//! Solves \f$ A x = b \f$ where the matrix is split into lower section (including the diagonal entries) and upper section (with zero diagonal).
//! The iteration is split into two stages, first compute \f$ u = b - U x \f$ using **apply_inner()** (here U is the upper section of A),
//! and then compute \f$ r = L^{-1} u \f$ where L is the lower section of A. The convergence criteria usually uses the norm of the difference
//! between successive iterations.

    FPVector r, u;
    unsigned int iteration = 0;
    bool iterate = true;

    while(iterate){
        apply_inner(x, u);
        solve_outer(u, r);
        iteration++;

        iterate = !converged(iteration, r, x);
        vector_swap(r, x);
    }
    return iteration;
}

}

#endif
