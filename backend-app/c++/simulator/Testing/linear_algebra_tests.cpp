#include <iostream>

#include "awsTestingCommon.hpp"

using std::cout;
using std::endl;

template <typename typeFP> void test_matvec();
template<typename typeFP> void test_factorILU();
template<typename typeFP> void test_solveCG();

int main(void){

    cout << endl << "    AWESOME: Sparse Linear Algebra Tests" << endl << endl;

    test_matvec<float>();
    test_matvec<double>();
    test_factorILU<float>();
    test_factorILU<double>();
    test_solveCG<float>();
    test_solveCG<double>();

    cout << endl << "    AWESOME: All Tests Succeeded." << endl << endl;

    return 0;
}

template <typename typeFP> void test_matvec(){
//! \internal
//! \brief Test the matrix vector product with 2 matrices and 3 vectors chosen to minimize the chance of double-error cancellation
//! \ingroup AwesomeTesting
    typeFP tol = (sizeof(typeFP) > 4) ? 1.E-13 : 1.E-6;
    std::valarray<int> pntr = {0, 3, 7, 10, 11, 14, 17};
    std::valarray<int> indx = {0, 1, 4, 0, 1, 4, 5, 1, 2, 5, 1, 2, 4, 5, 0, 3, 5};
    std::valarray<typeFP> vals(1.0, 17);
    std::valarray<typeFP> x = {1.0, 2.0, 4.0, 8.0, 16.0, 32.0};
    std::valarray<typeFP> true_r = {19.0, 51.0, 38.0, 2.0, 52.0, 41.0};
    std::valarray<typeFP> r(6);

    AWSM::spMatVec<typeFP>(1.0, pntr, indx, vals, x, 0.0, r);

    typeFP err = diffnorm1(r, true_r);
    if (err > tol) throw std::runtime_error("test_matvec() failed case 1");

    vals = {1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0, 1024.0, 2048.0, 4096.0, 8192.0, 16384.0, 32768.0, 65536.0};
    x = {1.0, 0.0, 1.0, 0.0, 1.0, 0.0};
    true_r = {5.0, 40.0, 256.0, 0.0, 6144.0, 16384.0};
    AWSM::spMatVec<typeFP>(1.0, pntr, indx, vals, x, 0.0, r);
    err = diffnorm1(r, true_r);
    if (err > tol) throw std::runtime_error("test_matvec() failed case 2");

    x = {0.0, 1.0, 0.0, 1.0, 0.0, 1.0};
    r = {32.0, 16.0, 8.0, 4.0, 2.0, 1.0};
    true_r = {36.0, 176.0, 1288.0, 2052.0, 16386.0, 196609.0};
    AWSM::spMatVec<typeFP>(2.0, pntr, indx, vals, x, 1.0, r);
    err = diffnorm1(r, true_r);
    if (err > tol) throw std::runtime_error("test_matvec() failed case 3");

    reportPass<typeFP>("test_matvec");
}

template<typename typeFP> void test_factorILU(){
//! \internal
//! \brief Test the Incomplete LU factorization.
//! \ingroup AwesomeTesting
    typeFP tol = (sizeof(typeFP) > 4) ? 1.E-13 : 1.E-6;
    std::valarray<int> pntr = {0, 3, 6, 9};
    std::valarray<int> indx = {0, 1, 2, 0, 1, 2, 0, 1, 2};
    std::valarray<typeFP> vals = {3.0, 2.0, 1.0, 2.0, 4.0, 3.0, 2.0, 1.0, 6.0};

    std::valarray<int> diag;
    std::valarray<typeFP> ilu;

    std::valarray<int> true_diag = {0, 4, 8};
    std::valarray<typeFP> true_ilu = {3.0, 2.0, 1.0, 2.0/3.0, 8.0/3.0, 7.0/3.0, 2.0/3.0, -0.125, 5.625};

    AWSM::spFactorizeILU<typeFP, int>(pntr, indx, vals, diag, ilu);
    if (diag.size() != 3) throw std::runtime_error("test_factorILU() failed to resize diag");
    true_diag -= diag;
    if (true_diag.sum() > 0) throw std::runtime_error("test_factorILU() failed to compute the diag");

    typeFP err = diffnorm1(ilu, true_ilu);
    if (err > tol) throw std::runtime_error("test_factorILU() failed to factorize");

    std::valarray<typeFP> x = {1.0, 2.0, 3.0}, r(3);
    std::valarray<typeFP> true_r = {1.0/9.0, 1.0/9.0, 4.0/9.0};
    AWSM::spApplyILU<typeFP, int>(pntr, indx, diag, ilu, x, r);

    err = diffnorm1(r, true_r);
    if (err > tol) throw std::runtime_error("test_factorILU() failed to apply the factor");

    reportPass<typeFP>("test_factorILU");
}

template<typename typeFP> void test_solveCG(){
//! \internal
//! \brief Test the Conjugate-Gradient Solver.
//! \ingroup AwesomeTesting
    typeFP tol = (sizeof(typeFP) > 4) ? 5.E-8 : 5.E-4;
    std::valarray<int> pntr = {0, 2, 5, 8, 11, 13};
    std::valarray<int> indx = {0, 1, 0, 1, 2, 1, 2, 3, 2, 3, 4, 3, 4};
    std::valarray<typeFP> vals = {2.0, 1.0, 1.0, 2.0, 1.0, 1.0, 2.0, 1.0, 1.0, 2.0, 1.0, 1.0, 2.0};

    std::valarray<typeFP> true_x = {1.0, 2.0, 3.0, 4.0, 5.0};
    std::valarray<typeFP> b(5), x(0.0, 5);
    AWSM::spMatVec<typeFP>(1.0, pntr, indx, vals, true_x, 0.0, b);

    AWSM::solveCGILU<typeFP, int>((typeFP) ((sizeof(typeFP) > 4) ? 1.E-9 : 1.E-4), // tolerance
                                  std::numeric_limits<unsigned int>::max(), // iterate forever
                                  pntr, indx, vals, b, x);

    for(auto s : x) if (std::isnan(s)) throw std::runtime_error("test_solveCG() failed, returned 'nan' values");
    for(auto s : x) if (std::isinf(s)) throw std::runtime_error("test_solveCG() failed, returned 'inf' values");

    typeFP err = diffnorm1(x, true_x);
    if (err > tol) throw std::runtime_error("test_solveCG() failed exact solution");

    // approx solution (new matrix)
    pntr = {0, 3, 6, 9, 12, 15};
    indx = {0, 1, 4, 0, 1, 2, 1, 2, 3, 2, 3, 4, 0, 3, 4};
    vals = {2.0, 1.0, 1.0, 1.0, 2.0, 1.0, 1.0, 2.0, 1.0, 1.0, 2.0, 1.0, 1.0, 1.0, 2.0};

    AWSM::spMatVec<typeFP>(1.0, pntr, indx, vals, true_x, 0.0, b); // new right-hand-side

    x = {1.0, 3.0, -4.0, -7.0, 11.0}; // garbage initial guess

    AWSM::solveCGILU<typeFP, int>((typeFP) ((sizeof(typeFP) > 4) ? 1.E-9 : 1.E-4), // tolerance
                                  std::numeric_limits<unsigned int>::max(), // iterate forever
                                  pntr, indx, vals, b, x);

    for(auto s : x) if (std::isnan(s)) throw std::runtime_error("test_solveCG() failed, returned 'nan' values");
    for(auto s : x) if (std::isinf(s)) throw std::runtime_error("test_solveCG() failed, returned 'inf' values");

    err = diffnorm1(x, true_x);
    if (err > tol) throw std::runtime_error("test_solveCG() failed approximate solution");

    reportPass<typeFP>("test_solveCG");
}