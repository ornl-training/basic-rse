#ifndef __AWS_CORE_MATRIX_OPS_HPP
#define __AWS_CORE_MATRIX_OPS_HPP

#include <valarray>

namespace AWSM{
//!
//! \file awsCoreMatrixOperations.hpp
//! \brief AWESOME Core Matrix Operations
//! \author Miroslav Stoyanov
//! \copyright ???
//! \ingroup AwesomeSLA
//!
//! Contains the Matrix operations
//!

template<typename typeFP, typename typeIdx = int>
void spMatVec(typeFP alpha, const std::valarray<typeIdx> &pntr, const std::valarray<typeIdx> &indx, const std::valarray<typeFP> &vals,
                     const std::valarray<typeFP> &x, typeFP beta, std::valarray<typeFP> &r){
//! \brief Sparse Matrix-Vector multiplication, using row-compressed format
//! \ingroup AwesomeSLA

//! Computes \f$ r = \alpha A x + \beta r \f$, i.e., sparse matrix defined by (pntr, indx, vals) by dense vector x
//! - the matrix is stored in row-compressed format
//! - \b typeFP is a floating point type, e.g., \b float or \b double
//! - \b typeIdx is the signed integer indexing type, e.g., \b int or \b long \b long

    typeIdx num_rows = (typeIdx) (pntr.size() - 1); // the loop below can be parallelized, but some OpenMP implementations require signed indexing
    for(typeIdx i = 0; i<num_rows; i++){ // can use OpenMP
        typeFP sum = 0.0;
        for(typeIdx j = pntr[i]; j<pntr[i+1]; j++){
            sum += vals[j] * x[indx[j]];
            //std::cout << vals[j] << "  " << x[indx[j]] << std::endl;
        }
        r[i] = alpha * sum + beta * r[i];
    }
}

template<typename typeFP, typename typeIdx = int>
void spFactorizeILU(const std::valarray<typeIdx> &pntr, const std::valarray<typeIdx> &indx, const std::valarray<typeFP> &vals, std::valarray<typeIdx> &diag, std::valarray<typeFP> &ilu){
//! \brief Factorize a sparse row-compressed matrix using Incomplete LU
//! \ingroup AwesomeSLA

//! Incomplete LU factorization (implemented here) uses the same Gaussian elimination procedure used in the simple (non-pivoted) LU factorization,
//! but the process ignores all entries that do not coincide with non-zeros of the original sparse matrix. The result is a lower and an upper triangular
//! sparse matrices with combined pattern that matches the original matrix.
//! - \b pntr, \b indx and \b vals describe a row-compressed matrix
//! - \b diag will hold the offsets of the diagonal entreis of the original matrix
//! - \b ilu will hold the values of the upper and lower factors
    typeIdx num_rows = (typeIdx) (pntr.size() - 1);
    diag.resize((size_t) num_rows);
    for(typeIdx i = 0; i<num_rows; i++){ // can use OpenMP
        typeIdx j = pntr[i];
        while(indx[j] < i) j++;
        diag[i] = j;
    }

    ilu = vals; // copy values to the factor
    for(typeIdx i=0; i<num_rows; i++){
        typeFP pivot = ilu[diag[i]];
        for(typeIdx j=i+1; j<num_rows; j++){ // can use OpenMP
            typeIdx jc = pntr[j];
            while(indx[jc] < i) jc++; // find the column index of the beginning of the j-th row

            if (indx[jc] == i){ // if inside the pattern, update the row
                ilu[jc] /= pivot;
                typeFP jpivot = ilu[jc];

                // basically row_j = row_j - jpivot * row_i, but consider only when non-zeros coincide
                typeIdx ik = diag[i]+1; // k-index loops over the i-th and j-th row
                typeIdx jk = jc+1;
                while((ik<pntr[i+1]) && (jk<pntr[j+1])){
                    if (indx[ik] == indx[jk]){ // pattern match, update the entry
                        ilu[jk] -= jpivot * ilu[ik];
                        ik++; jk++;
                    }else if (indx[ik] < indx[jk]){ // otherwise ignore the zero entries
                        ik++;
                    }else{
                        jk++;
                    }
                }
            }
        }
    }
}

template<typename typeFP, typename typeIdx = int>
void spApplyILU(const std::valarray<typeIdx> &pntr, const std::valarray<typeIdx> &indx, const std::valarray<typeIdx> &diag, const std::valarray<typeFP> &ilu,
                const std::valarray<typeFP> &b, std::valarray<typeFP> &x){
//! \brief Apply the Incomplete LU factor
//! \ingroup AwesomeSLA
//!
//! Solves \f$ P x = b \f$ where \b P is an ILU factor
    typeIdx num_rows = (typeIdx) (pntr.size() - 1);
    for(typeIdx i=0; i<num_rows; i++){ // solve using the lower factor
        typeFP sum = b[i];
        for(typeIdx j=pntr[i]; j<diag[i]; j++)
            sum -= ilu[j] * x[indx[j]];
        x[i] = sum;
    }
    for(typeIdx i=num_rows-1; i>=0; i--){ // solve using the upper factor
        typeFP sum = x[i];
        for(typeIdx j=diag[i]+1; j<pntr[i+1]; j++)
            sum -= ilu[j] * x[indx[j]];
        x[i] = sum / ilu[diag[i]];
    }
}

}

#endif
