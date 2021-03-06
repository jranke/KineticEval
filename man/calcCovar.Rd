% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/KinEval.r
\name{calcCovar}
\alias{calcCovar}
\title{Estimate Covariance Matrix with Boundaries}
\usage{
calcCovar(par, f, fval, lb, ub, ...)
}
\arguments{
\item{par}{parameter vector}

\item{f}{the residual function}

\item{fval}{current value}

\item{lb}{lower bounds}

\item{ub}{upper bounds}
}
\value{
a covariance matrix
}
\description{
Calculating Covariance when LM returns non-positive definite Hessian
}
\details{
Details
}
\author{
Zhenglei Gao
}

