##' Fit a kinetic model using the NLS or WNLS algorithm.
##'
##' KinGUI2
##' version of \code{\link{mkinfit}}. This function uses the Flexible Modelling
##' Environment package \code{\link{FME}} to create a function calculating the
##' model cost with weigths, which is then minimised , using the specified
##' initial or fixed parameters and starting values. This is deprecated!
##' Use \code{\link{mkinfit.full}} instead.
##'
## ##' @aliases mkinfit.gui
##' @param mkinmodini A list of class
##' \code{mkinmod.full}, containing the kinetic model to be fitted to the
##' data, and the initial parameter values, the observed data.
##' @param eigen If TRUE, the solution of the
##' system of differential equations should be based on the spectral
##' decomposition of the coefficient matrix in cases that this is possible.
##' @param plot If TRUE,the observed values
##' and the numerical solutions should be plotted at each stage of the
##' optimization.
##' @param plottitle The title of the
##' plot for visualizing the optimization process.
##' @param quiet If TRUE, suppress printing
##' out the current model cost after each(>1) improvement.
##' @param err Either \code{NULL}, or the name
##' of the column with the \emph{error} estimates, used to weigh the residuals
##' (see details of \code{\link{modCost}}); if \code{NULL}, then the residuals
##' are not weighed.  In the GUI version, there is no need to consider this
##' argument since a default weight one matrix is setup in
##' \code{mkinmod.gui}. The err argument turned into 'err' automatically
##' in the codes.
##' @param weight only if
##' \code{err}=\code{NULL}: how to weigh the residuals, one of "none", "std",
##' "mean", see details of \code{\link{modCost}}.
##' @param scaleVar Will be passed to
##' \code{\link{modCost}}. Default is not to scale Variables according to the
##' number of observations.
##' @param ctr A list of control values for the
##' estimation algorithm to replace the default values including maximum
##' iterations and absolute error tolerance.  Defaults to the output of
##' \code{\link{kingui.control}}.
##' @param update An object either of class \code{kingui} or a vector of to be optimized parameters
##' @param \dots Further arguments that will
##' be passed to \code{\link{modFit}}.
##' @return  A list with "kingui", "mkinfit" and "modFit" in the class
##' attribute. A summary can be obtained by \code{\link{summary.kingui}}.
##' @author Zhenglei Gao
##' @seealso \code{\link{mkinfit}}
##' @keywords Kinetic-Evaluations
##' @export
##' @examples
##' \dontrun{
##' guitest <- mkinmod.full(
##'     parent = list(
##'       time = c(     0,      3,      7,     14,     30,     62,     90,    118),
##'    residue = c(101.24,  99.27,  90.11,  72.19,  29.71,   5.98,   1.54,  NA),
##'     weight = c(     1,      1,      1,      1,      1,      1,      1,      1),
##'                   sink  = TRUE,
##'       type = "SFO",
##'          k = list(ini   = 0.040,
##'                   fixed = 0,
##'                   lower = 0.0,
##'                   upper = Inf),
##'         M0 = list(ini   = 100.15,
##'                   fixed = 0,
##'                   lower = 0.0,
##'                   upper = Inf)),
##'          inpartri='default',outpartri='default' )
##'  Fit    <- IRLSkinfit.full(
##'            guitest,
##'               plot      = TRUE,
##'               quiet     = TRUE,
##'              ctr       = kingui.control(
##'                               method = 'solnp',
##'                            submethod = 'Port',
##'                              maxIter = 100,
##'                            tolerance = 1E-06,
##'                            odesolver = 'lsoda'),
##'            irls.control = list(
##'                              maxIter = 10,
##'                            tolerance = 0.001))
##'}
##'
mkinfit.full <- function(mkinmodini,
  eigen = FALSE,
  plot = FALSE, plottitle='',quiet = FALSE,
  err = NULL, weight = "none", scaleVar = FALSE,
  ctr=kingui.control(),update=NULL,...)
{
    ## Get the parametrization.
    inpartri <- mkinmodini$inpartri
    outpartri <- mkinmodini$outpartri
    #### Control parameters ####
    method <- ctr$method
    odesolver <- ctr$odesolver
    atol <- ctr$atol
    rtol <- ctr$rtol
    control <- ctr$control
    marqctr <- ctr$marqctr
    goMarq <- ctr$goMarq
    submethod <- ctr$submethod
    Hmethod1 <- ctr$Hmethod1
    Hmethod2 <- ctr$Hmethod2
    ## mkinmodini is an object by mkinmod.full
    parms.ini <- mkinmodini$parms.ini
    state.ini <- mkinmodini$state.ini
    lower <- mkinmodini$lower
    upper <- mkinmodini$upper
    fixed_parms <- mkinmodini$fixed_parms
    fixed_initials <- mkinmodini$fixed_initials
    mod_vars <- names(mkinmodini$diffs)
    observed <-  mkin_wide_to_long(mkinmodini$residue,time='time')
    observed$err <-c(as.matrix(mkinmodini$weightmat))
    ## Subset dataframe with mapped (modelled) variables
    observed <- subset(observed, name %in% names(mkinmodini$map))
    ## Get names of observed variables
    obs_vars = unique(as.character(observed$name))

    ## Name the parameters if they are not named yet
    if(is.null(names(parms.ini))) names(parms.ini) <- mkinmodini$parms

    ## Name the inital parameter values if they are not named yet
    if(is.null(names(state.ini))) names(state.ini) <- mod_vars

    ## Parameters to be optimised
    parms.fixed <- parms.ini[fixed_parms]
    optim_parms <- setdiff(names(parms.ini), fixed_parms)
    parms.optim <- parms.ini[optim_parms]

    ## # ### ### ### ### ###
    state.ini.fixed <- state.ini[fixed_initials]
    optim_initials <- setdiff(names(state.ini), fixed_initials)
    state.ini.optim <- state.ini[optim_initials]
    state.ini.optim.boxnames <- names(state.ini.optim)
    state.ini.fixed.boxnames <- names(state.ini.fixed)
    if(length(state.ini.optim) > 0) {
        names(state.ini.optim) <- paste('M0',names(state.ini.optim),  sep="_")
    }
    if(length(state.ini.fixed) > 0) {
        names(state.ini.fixed) <- paste('M0',names(state.ini.fixed), sep="_")
    }

    ## ####################################################################
    ## # If updating from previous fit or new starting point.####
    if(!is.null(update)){
        parms.optim <- update$par[optim_parms]
        state.ini.optim <-update$par[names(state.ini.optim)]
        if(!is.null(update$ctr)){
            ctr <- update$ctr
            ## Control parameters ####

            method <- ctr$method
            odesolver <- ctr$odesolver
            atol <- ctr$atol
            rtol <- ctr$rtol
            control <- ctr$control
        }
    }

    ## ##### ### #####
    ## Decide if the solution of the model can be based on a simple analytical
    ## formula, the spectral decomposition of the matrix (fundamental system)
    ## or a numeric ode solver from the deSolve package
    if (length(mkinmodini$map) == 1) {
        solution = "analytical"
    } else {
        if (is.matrix(mkinmodini$coefmat) & eigen) solution = "eigen"
        else solution = "deSolve"
    }

    ## Create a function calculating the differentials specified by the model
    ## if necessary
    if(solution == "deSolve") {
        mkindiff <- function(t, state, parms) {
            time <- t
            diffs <- vector()
            for (box in mod_vars)
            {
                diffname <- paste("d", box, sep="_")
                diffs[diffname] <- with(as.list(c(time,state, parms)),
                                        eval(parse(text=mkinmodini$diffs[[box]])))
            }
            return(list(c(diffs)))
        }
    }


    cost.old <- 1e100
    calls <- 0
    out_predicted <- NA

    ## Define the model cost function
    cost <- function(P)
    {
                                        #names(P) <- pnames
        assign("calls", calls+1, inherits=TRUE)
        if(length(state.ini.optim) > 0) {
            odeini <- c(P[1:length(state.ini.optim)], state.ini.fixed)
            names(odeini) <- c(state.ini.optim.boxnames,state.ini.fixed.boxnames)
        } else {
            odeini <- state.ini.fixed
            names(odeini) <- c( state.ini.fixed.boxnames)
        }
        ## has to change the odeini order since it is different from the mod_vars order.
        odeini <- odeini[mod_vars]
        if(length(parms.optim)>0) {
          odeparms <- c(P[(length(state.ini.optim) + 1):length(P)], parms.fixed)
        }else{
          odeparms <- parms.fixed
        }##odeparms <- c(P[(length(state.ini.optim) + 1):length(P)], parms.fixed)

        outtimes = unique(observed$time)
        evalparse <- function(string)
        {
            eval(parse(text=string), as.list(c(odeparms, odeini)))
        }

        ## Solve the system
        if (solution == "analytical") {
            parent.type = names(mkinmodini$map[[1]])[1]
            parent.name = names(mkinmodini$diffs)[[1]]
            o <- switch(parent.type,
                        SFO = SFO.solution(outtimes,
                        evalparse(parent.name),
                        evalparse(paste("k", parent.name,  sep="_"))),
                        FOMC = FOMC.solution(outtimes,
                        evalparse(parent.name),
                        evalparse(paste("alpha", parent.name,  sep="_")), evalparse(paste("beta", parent.name,  sep="_"))),
                        DFOP = DFOP.solution(outtimes,
                        evalparse(parent.name),
                        evalparse(paste("k1", parent.name,  sep="_")), evalparse(paste("k2", parent.name,  sep="_")),evalparse(paste("g", parent.name,  sep="_"))),
                        HS = HS.solution(outtimes,
                        evalparse(parent.name),
                        evalparse(paste("k1", parent.name,  sep="_")),evalparse(paste("k2", parent.name,  sep="_")),evalparse(paste("tb", parent.name,  sep="_"))),
                        SFORB = SFORB.solution(outtimes,
                        evalparse(parent.name),
                        evalparse(paste("k", parent.name, "bound", sep="_")),
                        evalparse(paste("k", sub("free", "bound", parent.name), "free", sep="_")),
                        evalparse(paste("k", parent.name, "sink", sep="_")))
                        )
            out <- cbind(outtimes, o)
            dimnames(out) <- list(outtimes, c("time", sub("_free", "", parent.name)))
        }
        if (solution == "eigen") {
            coefmat.num <- matrix(sapply(as.vector(mkinmodini$coefmat), evalparse),
                                  nrow = length(mod_vars))
            e <- eigen(coefmat.num)
            zz.ev <- e$values
            if(min(zz.ev)[1]<0){

                warning("\'coefmat is not positive definite!\n")
                solution <- 'deSolve' ## switch to deSolve methods
                if(solution == "deSolve") {
                    mkindiff <- function(t, state, parms) {
                        time <- t
                        diffs <- vector()
                        for (box in mod_vars)
                        {
                            diffname <- paste("d", box, sep="_")
                            diffs[diffname] <- with(as.list(c(time,state, parms)),
                                                    eval(parse(text=mkinmodini$diffs[[box]])))
                        }
                        return(list(c(diffs)))
                    }
                }
            }else{
                cc <- solve(e$vectors, odeini)
                f.out <- function(t) {
                    e$vectors %*% diag(exp(e$values * t), nrow=length(mod_vars)) %*% cc
                }
                o <- matrix(mapply(f.out, outtimes),
                            nrow = length(mod_vars), ncol = length(outtimes))
                dimnames(o) <- list(mod_vars, outtimes)
                out <- cbind(time = outtimes, t(o))
            }
        }
        if (solution == "deSolve")
        {
            out <- ode(
                       y = odeini,
                       times = outtimes,
                       func = mkindiff,
                       parms = odeparms,
                       atol = atol,
                       rtol = rtol,
                       method=odesolver
                       )
            ## #sink("NUL")
            ## if(diagnostics(out)$istate[1]!=2)
            ##     {
            ##         #browser()
            ##          out <- ode(
            ##                     y = odeini,
            ##                     times = outtimes,
            ##                     func = mkindiff,
            ##                     parms = odeparms,
            ##                     atol = atol,
            ##                     rtol = rtol,
            ##                     method='ode45'
            ##                     )

            ##     }
            ## #sink()
        }

        ## Output transformation for models with unobserved compartments like SFORB
        out_transformed <- data.frame(time = out[,"time"])
        for (var in names(mkinmodini$map)) {
            if((length(mkinmodini$map[[var]]) == 1) || solution == "analytical") {
                out_transformed[var] <- out[, var]
            } else {
                out_transformed[var] <- rowSums(out[, mkinmodini$map[[var]]])
            }
        }
        assign("out_predicted", out_transformed, inherits=TRUE)
        if(sum(apply(out_transformed,2,function(x) sum(is.nan(x))>nrow(out_transformed)-2))>0)
        {
                                        #browser()
            warning('Integration not completed')
            out_transformed <- apply(out_transformed,2,function(x) {if(sum(is.nan(x))>nrow(out_transformed)-2) x <- rep(Inf,nrow(out_transformed)) else x <- x})
        }
        if(nrow(out_transformed)<length(outtimes))
        {
            tmp <- matrix(0,length(outtimes),ncol(out_transformed)-1)
            tmpnames <-names(out_transformed)
            out_transformed <- data.frame(time=outtimes,tmp)
            names(out_transformed) <- tmpnames
        }
        ##browser()
        mC <- modCost(out_transformed, observed, y = "value",
                      err = 'err', weight = weight, scaleVar = scaleVar)

        ## Report and/or plot if the model is improved
        if (cost.old-mC$model > ctr$quiet.tol) {
            if(!quiet) cat("Model cost at call ", calls, ": ", mC$model, "\n")

                                        # Plot the data and current model output if requested
            if(plot) {
                outtimes_plot = seq(min(observed$time), max(observed$time), length.out=100)
                if (solution == "analytical") {
                    o_plot <- switch(parent.type,
                                     SFO = SFO.solution(outtimes_plot,
                                     evalparse(parent.name),
                                     evalparse(paste("k", parent.name,  sep="_"))),
                                     FOMC = FOMC.solution(outtimes_plot,
                                     evalparse(parent.name),
                                     evalparse(paste("alpha", parent.name,  sep="_")),evalparse(paste("beta", parent.name,  sep="_"))),
                                     DFOP = DFOP.solution(outtimes_plot,
                                     evalparse(parent.name),
                                     evalparse(paste("k1", parent.name,  sep="_")),evalparse(paste("k2", parent.name,  sep="_")),evalparse(paste("g", parent.name,  sep="_"))),
                                     HS = HS.solution(outtimes_plot,
                                     evalparse(parent.name),
                                     evalparse(paste("k1", parent.name,  sep="_")),evalparse(paste("k2", parent.name,  sep="_")),evalparse(paste("tb", parent.name,  sep="_"))),
                                     SFORB = SFORB.solution(outtimes_plot,
                                     evalparse(parent.name),
                                     evalparse(paste("k", parent.name, "bound", sep="_")),
                                     evalparse(paste("k", sub("free", "bound", parent.name), "free", sep="_")),
                                     evalparse(paste("k", parent.name, "sink", sep="_")))
                                     )
                    out_plot <- cbind(outtimes_plot, o_plot)
                    dimnames(out_plot) <- list(outtimes_plot, c("time", sub("_free", "", parent.name)))
                }
                if(solution == "eigen") {
                    o_plot <- matrix(mapply(f.out, outtimes_plot),
                                     nrow = length(mod_vars), ncol = length(outtimes_plot))
                    dimnames(o_plot) <- list(mod_vars, outtimes_plot)
                    out_plot <- cbind(time = outtimes_plot, t(o_plot))
                }
                if (solution == "deSolve") {
                    out_plot <- ode(
                                    y = odeini,
                                    times = outtimes_plot,
                                    func = mkindiff,
                                    parms = odeparms)
                }
                out_transformed_plot <- data.frame(time = out_plot[,"time"])
                for (var in names(mkinmodini$map)) {
                    if((length(mkinmodini$map[[var]]) == 1) || solution == "analytical") {
                        out_transformed_plot[var] <- out_plot[, var]
                    } else {
                        out_transformed_plot[var] <- rowSums(out_plot[, mkinmodini$map[[var]]])
                    }
                }

                plot(0, type="n",
                     xlim = range(observed$time), ylim = range(observed$value, na.rm=TRUE),
                     xlab = "Time", ylab = "Observed",main=plottitle)
                col_obs <- pch_obs <- 1:length(obs_vars)
                names(col_obs) <- names(pch_obs) <- obs_vars
                for (obs_var in obs_vars) {
                    points(subset(observed, name == obs_var, c(time, value)),
                           pch = pch_obs[obs_var], col = col_obs[obs_var])
                }
                matlines(out_transformed_plot$time, out_transformed_plot[-1])
                legend("topright", inset=c(0.05, 0.05), legend=obs_vars,
                       col=col_obs, pch=pch_obs, lty=1:length(pch_obs))
            }

            assign("cost.old", mC$model, inherits=TRUE)
        }
        return(mC)
    }
    if(plot) x11()
    ## if(method=='trust') {
    ##     outtimes <-unique(observed$time)
    ##     fit <- modFit1(cost1, c(state.ini.optim, parms.optim), lower = lower, upper = upper, method=method,control=control, state.ini.optim,state.ini.fixed,state.ini.optim.boxnames, state.ini.fixed.boxnames,parms.fixed,outtimes,mkindiff,mkinmodini,observed,err,weight,scaleVar) }else  fit <- modFit1(cost, c(state.ini.optim, parms.optim), lower = lower, upper = upper, method=method,control=control,...)
    #browser()
    ##method <- 'solnp'
    optimmethod <- method
    if(method=='solnp')
    {
        pnames=names(c(state.ini.optim, parms.optim))
        fn <- function(P){
            names(P) <- pnames
            FF<<-cost(P)
            return(FF$model)}
        a <- try(fit <- solnp(c(state.ini.optim, parms.optim),fun=fn,LB=lower,UB=upper,control=control),silent=TRUE)
        flag <- 1
                                        #browser()
        if(class(a) == "try-error")
        {
                                        #print('solnp fails, try hee other algorithm by users choice, might take longer time. Do something else!')
            warning('solnp fails, switch to  PORT or other algorithm by users choice')
            fit <- modFit1(cost, c(state.ini.optim, parms.optim), lower = lower, upper = upper, method=submethod,control=kingui.control(method=submethod,tolerance=ctr$control$tol)$control)
            flag <- 0
            optimmethod <-c(optimmethod,submethod)
        }else{

            ## # other list need to be attached to fit to give comparable results as in modFit.
            fit$ssr <- fit$values[length(fit$values)]
            fit$residuals <-FF$residual$res
                                        ## mean square per varaible
            if (class(FF) == "modCost") {
                names(fit$residuals)  <- FF$residuals$name
                fit$var_ms            <- FF$var$SSR/FF$var$N
                fit$var_ms_unscaled   <- FF$var$SSR.unscaled/FF$var$N
                fit$var_ms_unweighted <- FF$var$SSR.unweighted/FF$var$N
                names(fit$var_ms_unweighted) <- names(fit$var_ms_unscaled) <-
                    names(fit$var_ms) <- FF$var$name
            } else fit$var_ms <- fit$var_ms_unweighted <- fit$var_ms_unscaled <- NA
            np <- length(c(state.ini.optim, parms.optim))
            fit$rank <- np
            fit$df.residual <- length(fit$residuals) - fit$rank
            ## ######### Calculating the unscaled covariance ###########
            covar <- try(solve(0.5*fit$hessian), silent = TRUE)   # unscaled covariance
            ## If a covar is an identity matrix or not numeric, need to calculate..

            if(!is.numeric(covar) || (sum(covar==diag(np))==np*np)){
                if(flag==1){
                    ##message <- "Cannot estimate covariance directly from hessian of the optimization"
                    ##warning(message)
                    print('Now we need to estimate the Hessian matrix to get the confidence intervals since the first optimization did not give us a valid one. This may take a while depending on the problem(Please be patient!)')
                    solnp.hessian <- fit$hessian
                    solnp.covar <- covar

                    ## jac <- NULL
                    ## fn1 <- function(P,...)
                    ## {
                    ##     FF<<-cost(P)
                    ##     return(FF$residuals$res)
                    ## }
                    ## if (! is.null(jac))Jac <- jac(res$par)else Jac <- gradient(fn1, fit$par, centered = TRUE, ...)
                    ## fit$hessian <- 2 * t(Jac) %*% Jac
                    ## covar <- try(solve(0.5*fit$hessian), silent = TRUE)
                    if(!is.numeric(covar)){
                        message <- "Cannot estimate covariance from hessian calculated by gradient, do a local optimization"
                        warning(message)
                        ##fit$Jac <- Jac
                        fit <- modFit1(cost, fit$par, lower = lower, upper = upper, method=Hmethod1,control=list())
                        optimmethod <-c(optimmethod,submethod,Hmethod1)
                        covar <- fit$covar
                        if(!is.numeric(covar)){
                            fit <- modFit1(cost, fit$par, lower = lower, upper = upper, method=Hmethod2,control=list())
                            covar <- fit$covar
                            optimmethod <-c(optimmethod,Hmethod2)
                        }
                                        #covar <- matrix(data = NA, nrow = np, ncol = np)
                    }

                }else{
                    message <- "ok"
                }
            }
            rownames(covar) <- colnames(covar) <-pnames
            fit$covar <- covar
        }

    }else{### method not solnp
        ##fit <- modFit1(cost, fit$par, lower = lower, upper = upper, method=Hmethod1,control=list())
        fit <- modFit1(cost, c(state.ini.optim, parms.optim), lower = lower, upper = upper, method=method,control=control)
         covar <- fit$covar
        if(!is.numeric(covar)){
            fit <- modFit1(cost, fit$par, lower = lower, upper = upper, method=Hmethod1,control=list())
            covar <- fit$covar
            optimmethod <-c(optimmethod,Hmethod1)
            if(!is.numeric(covar)){
                fit <- modFit1(cost, fit$par, lower = lower, upper = upper, method=Hmethod2,control=list())
                covar <- fit$covar
                optimmethod <-c(optimmethod,Hmethod2)

        }
        }

    }

    fit$optimmethod <- optimmethod
    ## We need to return some more data for summary and plotting
    fit$solution <- solution
    if (solution == "eigen") {
        fit$coefmat <- mkinmodini$coefmat
    }
    if (solution == "deSolve") {
        fit$mkindiff <- mkindiff
    }

    ## We also need various other information for summary and plotting
    fit$map <- mkinmodini$map
    fit$diffs <- mkinmodini$diffs
    fit$observed <- mkinmodini$residue
    if(method=='trust'){
        P <- fit$par
        if (length(state.ini.optim) > 0) {
            odeini <- c(P[1:length(state.ini.optim)], state.ini.fixed)
            names(odeini) <- c(state.ini.optim.boxnames, state.ini.fixed.boxnames)
        }
        else odeini <- state.ini.fixed
        odeparms <- c(P[(length(state.ini.optim) + 1):length(P)],
            parms.fixed)
        #outtimes = unique(observed$time)
        out <- ode(y = odeini, times = outtimes, func = mkindiff,
            parms = odeparms)
        out_transformed <- data.frame(time = out[, "time"])
        for (var in names(mkinmodini$map)) {
            if (length(mkinmodini$map[[var]]) == 1) {
                out_transformed[var] <- out[, var]
            }
            else {
                out_transformed[var] <- rowSums(out[, mkinmodini$map[[var]]])
            }
        }
        assign("out_predicted", out_transformed, inherits = TRUE)
    }
    predicted_long <- mkin_wide_to_long(out_predicted, time = "time")
    fit$predicted <- out_predicted

    ## Collect initial parameter values in two dataframes
        ##
    if(outpartri=='default'){
        if(length(state.ini.optim)>0){
            fit$start0 <- data.frame(initial=state.ini.optim,type=rep("state", length(state.ini.optim)),lower=lower[1:length(state.ini.optim)],upper=upper[1:length(state.ini.optim)])}else{
                fit$start0 <- data.frame(initial=state.ini.optim,type=rep("state", length(state.ini.optim)),lower=numeric(0),upper=numeric(0))
            }
        start0 <- mkinmodini$start[mkinmodini$start$fixed==0,]
        fit$start0 <- rbind(fit$start0,data.frame(initial=start0$initial,type=start0$type,lower=start0$lower,upper=start0$upper,row.names =rownames(start0)))
        fit$fixed0 <- data.frame(value = state.ini.fixed,type=rep("state", length(state.ini.fixed)),by=rep("user", length(state.ini.fixed)))
        fixed0 <- mkinmodini$start[mkinmodini$start$fixed==1,]
        if(nrow(fixed0)>0) fit$fixed0 <- rbind(fit$fixed0,data.frame(value=fixed0$initial,type=fixed0$type,by=rep('user',nrow(fixed0)),row.names=rownames(fixed0)))
    }else{
        fit$start0 <- NULL
        fit$fixed0 <- NULL
    }
        fit$start <- data.frame(initial = c(state.ini.optim, parms.optim))
        fit$start$type = c(rep("state", length(state.ini.optim)), rep("deparm", length(parms.optim)))
        fit$start$lower <- lower
        fit$start$upper <- upper

        fit$fixed <- data.frame(value = c(state.ini.fixed, parms.fixed))
        fit$fixed$type = c(rep("state", length(state.ini.fixed)), rep("deparm", length(parms.fixed)))
        fit$fixed$by <- c(rep("user", length(state.ini.fixed)), mkinmodini$fixed_flag)

    ## Calculate chi2 error levels according to FOCUS (2006)
    ## 0 values at sample time 0 should not be used.
    observed1 <- observed
    observed1 <- observed[!(observed$time==0 & observed$value==0),]
    means <- aggregate(value ~ time + name, data = observed1, mean, na.rm=TRUE)##using the mean of repeated measurements.
    ## browser()

    errdata <- merge(means, predicted_long, by = c("time", "name"), suffixes = c("_mean", "_pred"))

    errdata <- errdata[order(errdata$time, errdata$name), ]
    errobserved <- merge(observed, predicted_long, by = c("time", "name"), suffixes = c("_obs", "_pred"))
    errmin.overall <- chi2err(errdata, length(parms.optim) + length(state.ini.optim),errobserved)    #errmin.overall <- chi2err(errdata, length(parms.optim) + length(state.ini.optim))
    errmin <- data.frame(err.min = errmin.overall$err.min,
                         n.optim = errmin.overall$n.optim, df = errmin.overall$df,err.sig = errmin.overall$err.sig,RMSE=errmin.overall$RMSE,EF=errmin.overall$EF,R2=errmin.overall$R2)
    rownames(errmin) <- "All data"
    ## browser()
    for (obs_var in obs_vars)
    {
        errdata.var <- subset(errdata, name == obs_var)
        errobserved.var <- subset(errobserved, name == obs_var)
        if(outpartri=='default'){
            ##n.k.optim <- (paste("k", obs_var, sep="_")) %in% (names(parms.optim))+length(grep(paste("f", obs_var,'to', sep="_"), names(parms.optim)))
            n.k.optim <- (paste("k", obs_var, sep="_")) %in% (names(parms.optim))+length(grep(paste("f",'.*','to',obs_var,sep="_"), names(parms.optim)))
         }
        if(outpartri=='water-sediment'){
            n.k.optim <- length(grep(paste("k_", obs_var, '_',sep=""), names(parms.optim)))
        }
        n.initials.optim <- as.numeric((paste('M0_',obs_var, sep="")) %in% (names(state.ini.optim)))#n.initials.optim <- length(grep(paste('M0_',obs_var, sep=""), names(state.ini.optim)))
        n.optim <- n.k.optim + n.initials.optim
        ## ## added
        k1name <- paste("k1", obs_var,  sep="_")
        k2name <- paste("k2", obs_var,  sep="_")
        gname <- paste("g", obs_var,  sep="_")
        tbname <- paste("tb", obs_var,  sep="_")
        alphaname <- paste("alpha", obs_var,  sep="_")
        betaname <- paste("beta", obs_var,  sep="_")
        ## #
        ## if ("alpha" %in% names(parms.optim)) n.optim <- n.optim + 1
        ## if ("beta" %in% names(parms.optim)) n.optim <- n.optim + 1
        ## if ("k1" %in% names(parms.optim)) n.optim <- n.optim + 1
        ## if ("k2" %in% names(parms.optim)) n.optim <- n.optim + 1
        ## if ("g" %in% names(parms.optim)) n.optim <- n.optim + 1
        ## if ("tb" %in% names(parms.optim)) n.optim <- n.optim + 1
        ## #
        if (alphaname %in% names(parms.optim)) n.optim <- n.optim + 1
        if (betaname %in% names(parms.optim)) n.optim <- n.optim + 1
        if (k1name %in% names(parms.optim)) n.optim <- n.optim + 1
        if (k2name %in% names(parms.optim)) n.optim <- n.optim + 1
        if (gname %in% names(parms.optim)) n.optim <- n.optim + 1
        if (tbname %in% names(parms.optim)) n.optim <- n.optim + 1

        ## errmin.tmp <- mkinerrmin(errdata.var, n.optim)
        errmin.tmp <- chi2err(errdata.var, n.optim,errobserved.var)#errmin.tmp <- chi2err(errdata.var, n.optim)
        errmin[obs_var, c("err.min", "n.optim", "df",'err.sig','RMSE','EF','R2')] <- errmin.tmp
    }
    fit$errmin <- errmin

    ## Calculate dissipation times DT50 and DT90 and formation fractions
    parms.all = c(fit$par, parms.fixed)
    fit$distimes <- data.frame(DT50 = rep(NA, length(obs_vars)), DT90 = rep(NA, length(obs_vars)),Kinetic=rep(NA,length(obs_vars)),row.names = obs_vars)
     if(mkinmodini$outpartri=='default'){
        ## Now deals with formation fractions in case the outpartri is 'default'##
        ## Keep the original IRLSkinfit.gui codes ##
         fit$ff <- vector()
         ff_names = names(mkinmodini$ff)
         for (ff_name in ff_names)
         {
             fit$ff[[ff_name]] =
                 eval(parse(text = mkinmodini$ff[ff_name]), as.list(parms.all))
         }
         ## ###

         for (obs_var in obs_vars) {
             f_tot <- grep(paste(obs_var, "_",sep=''), names(fit$ff), value=TRUE)
             f_exp <- grep(paste(obs_var, "to",obs_var,sep='_'), names(fit$ff), value=TRUE)
             f_exp1 <- grep(paste(obs_var, "to",'sink',sep='_'), names(fit$ff), value=TRUE)
             ##fit$ff[[paste(obs_var,'to', "sink", sep="_")]] = 1 - sum(fit$ff[f_tot])+sum(fit$ff[f_exp])
             fit$ff[[paste(obs_var,'to', "sink", sep="_")]] = 1 - sum(fit$ff[f_tot])+sum(fit$ff[f_exp])+sum(fit$ff[f_exp1])
             type = names(mkinmodini$map[[obs_var]])[1]
             k1name <- paste("k1", obs_var,  sep="_")
             k2name <- paste("k2", obs_var,  sep="_")
             gname <- paste("g", obs_var,  sep="_")
             tbname <- paste("tb", obs_var,  sep="_")
             alphaname <- paste("alpha", obs_var,  sep="_")
             betaname <- paste("beta", obs_var,  sep="_")
             if (type == "SFO") {
                 ##k_names = grep(paste("k", obs_var, sep="_"), names(parms.all), value=TRUE)
                 ##k_tot = sum(parms.all[k_names])
                 k_name <- paste("k", obs_var,sep="_")
                 k_tot <- parms.all[k_name]
                 DT50 = log(2)/k_tot
                 DT90 = log(10)/k_tot
                 ## for (k_name in k_names)
                 ## {
                 ##   fit$ff[[sub("k_", "", k_name)]] = parms.all[[k_name]] / k_tot
                 ## }
             }
             if (type == "FOMC") {
                 ## alpha = parms.all["alpha"]
                 ## beta = parms.all["beta"]
                 alpha = parms.all[alphaname]
                 beta = parms.all[betaname]
                 DT50 = beta * (2^(1/alpha) - 1)
                 DT90 = beta * (10^(1/alpha) - 1)
                 ## ff_names = names(mkinmodini$ff)
                 ## for (ff_name in ff_names)
                 ## {
                 ##   fit$ff[[paste(obs_var, ff_name, sep="_")]] =
                 ##     eval(parse(text = mkinmodini$ff[ff_name]), as.list(parms.all))
                 ## }
                 ## fit$ff[[paste(obs_var, "sink", sep="_")]] = 1 - sum(fit$ff)
             }
             if (type == "DFOP") {
                 ## k1 = parms.all["k1"]
                 ## k2 = parms.all["k2"]
                 ## g = parms.all["g"]
                 k1 = parms.all[k1name]
                 k2 = parms.all[k2name]
                 g = parms.all[gname]
                 f <- function(t, x) {
                     ((g * exp( - k1 * t) + (1 - g) * exp( - k2 * t)) - (1 - x/100))^2
                 }
                 ##browser()
                 ## shouldn't have a greater than slow phase DT50, need to double check
                 DTmax1 <- log(2)/min(k1,k2)
                 if(DTmax1==Inf) DTmax1 <- .Machine$double.xmax
                 DTmax <- 1000
                 DT50.o <- optimize(f, c(0, DTmax), x=50)$minimum
                 DT50.o1 <- optimize(f, c(0, DTmax1), x=50)$minimum
                 DT50.o <- ifelse(f(DT50.o,50)>f(DT50.o1,50), DT50.o1,DT50.o)
                 DT50 = ifelse(DTmax - DT50.o < 0.1, NA, DT50.o)
                 DT90.o <- optimize(f, c(0, DTmax), x=90)$minimum
                 DTmax1 <- log(10)/min(k1,k2)
                 if(DTmax1==Inf) DTmax1 <- .Machine$double.xmax
                 DT90.o1 <- optimize(f, c(0, DTmax1), x=90)$minimum
                 DT90.o <- ifelse(f(DT90.o,50)>f(DT90.o1,50), DT90.o1,DT90.o)
                 DT90 = ifelse(DTmax - DT90.o < 0.1, NA, DT90.o)
             }
             if (type == "HS") {
                 ## k1 = parms.all["k1"]
                 ## k2 = parms.all["k2"]
                 ## tb = parms.all["tb"]
                 k1 = parms.all[k1name]
                 k2 = parms.all[k2name]
                 tb = parms.all[tbname]
                 f <- function(t, x) {
                     fraction = ifelse(t <= tb, exp(-k1 * t), exp(-k1 * tb) * exp(-k2 * (t - tb)))
                     (fraction - (1 - x/100))^2
                 }
                 ##DT50=1
                 ##DT90=2
                 DTmax <- 1000
                 ##DT50 <- nlm(f, 0.0001, x=50)$estimate
                 ##DT90 <- nlm(f, 0.0001, x=90)$estimate
                 hso1 <- nlminb(0.0001,f, x=50)
                 hso2 <- nlminb(tb,f, x=50)
                 DT50.o <- ifelse(hso1$objective<=hso2$objective,hso1$par,hso2$par)
                 DT50 = ifelse(DTmax - DT50.o < 0.1, NA, DT50.o)

                 hso1 <- nlminb(0.0001,f, x=90)
                 hso2 <- nlminb(tb,f, x=90)
                 DT90.o <- ifelse(hso1$objective<=hso2$objective,hso1$par,hso2$par)
                 DT90 = ifelse(DTmax - DT90.o < 0.1, NA, DT90.o)
                 ########################################

             }

             if (type == "SFORB") {
                 ## FOCUS kinetics (2006), p. 60 f
                 k_out_names = grep(paste("k", obs_var, "free", sep="_"), names(parms.all), value=TRUE)
                 k_out_names = setdiff(k_out_names, paste("k", obs_var, "free", "bound", sep="_"))
                 k_1output = sum(parms.all[k_out_names])
                 k_12 = parms.all[paste("k", obs_var, "free", "bound", sep="_")]
                 k_21 = parms.all[paste("k", obs_var, "bound", "free", sep="_")]

                 sqrt_exp = sqrt(1/4 * (k_12 + k_21 + k_1output)^2 + k_12 * k_21 - (k_12 + k_1output) * k_21)
                 b1 = 0.5 * (k_12 + k_21 + k_1output) + sqrt_exp
                 b2 = 0.5 * (k_12 + k_21 + k_1output) - sqrt_exp

                 SFORB_fraction = function(t) {
                     ((k_12 + k_21 - b1)/(b2 - b1)) * exp(-b1 * t) +
                         ((k_12 + k_21 - b2)/(b1 - b2)) * exp(-b2 * t)
                 }
                 f_50 <- function(t) (SFORB_fraction(t) - 0.5)^2
                 max_DT <- 1000
                 DT50.o <- optimize(f_50, c(0.01, max_DT))$minimum
                 if (abs(DT50.o - max_DT) < 0.01) DT50 = NA else DT50 = DT50.o
                 f_90 <- function(t) (SFORB_fraction(t) - 0.1)^2
                 DT90.o <- optimize(f_90, c(0.01, 1000))$minimum
                 if (abs(DT90.o - max_DT) < 0.01) DT90 = NA else DT90 = DT90.o
                 for (k_out_name in k_out_names)
                 {
                     fit$ff[[sub("k_", "", k_out_name)]] = parms.all[[k_out_name]] / k_1output
                 }
             }
             fit$distimes[obs_var, ] = c(ifelse(is.na(DT50),NA,formatC(DT50,4,format='f')), ifelse(is.na(DT90),NA,formatC(DT90,4,format='f')),type)#c(DT50, DT90,type)
         }
     }
    if(mkinmodini$outpartri=='water-sediment'){
        ## Now deals with multiple ks and additionally calculate formation fractions in case the outpartri is 'water-sediment'##
        fit$ff <- vector() ## for FOMC, HS, DFOP, they might still use formation fractions.
        ##ff_names = names(mkinmodini$ff)
        ##for (ff_name in ff_names)
        ##{
        ##   fit$ff[[ff_name]] =
        ##      eval(parse(text = mkinmodini$ff[ff_name]), as.list(parms.all))
        ##}
        ## ###
        ##browser()
        for (obs_var in obs_vars) {
            ##f_tot <- grep(paste(obs_var, "_",sep=''), names(fit$ff), value=TRUE)
            ##f_exp <- grep(paste(obs_var, "to",obs_var,sep='_'), names(fit$ff), value=TRUE)
            ##f_exp1 <- grep(paste(obs_var, "to",'sink',sep='_'), names(fit$ff), value=TRUE)
            ##fit$ff[[paste(obs_var,'to', "sink", sep="_")]] = 1 - sum(fit$ff[f_tot])+sum(fit$ff[f_exp])+sum(fit$ff[f_exp1])
            type = names(mkinmodini$map[[obs_var]])[1]
            k1name <- paste("k1", obs_var,  sep="_")
            k2name <- paste("k2", obs_var,  sep="_")
            gname <- paste("g", obs_var,  sep="_")
            tbname <- paste("tb", obs_var,  sep="_")
            alphaname <- paste("alpha", obs_var,  sep="_")
            betaname <- paste("beta", obs_var,  sep="_")
            if (type == "SFO") {
                k_names = grep(paste("k_", obs_var,'_', sep=""), names(parms.all), value=TRUE)
                k_tot = sum(parms.all[k_names])
                DT50 = log(2)/k_tot
                DT90 = log(10)/k_tot
                for (k_name in k_names){
                    fit$ff[[sub("k_", "", k_name)]] = parms.all[[k_name]] / k_tot
                }
            }
            if (type == "FOMC") {
                alpha = parms.all[alphaname]
                beta = parms.all[betaname]
                DT50 = beta * (2^(1/alpha) - 1)
                DT90 = beta * (10^(1/alpha) - 1)
                ff_names = names(mkinmodini$ff)
                for (ff_name in ff_names){
                    fit$ff[[paste(obs_var, ff_name, sep="_")]] =
                        eval(parse(text = mkinmodini$ff[ff_name]), as.list(parms.all))
                }
                fit$ff[[paste(obs_var, "sink", sep="_")]] = 1 - sum(fit$ff)
            }
            if (type == "DFOP") {
                k1 = parms.all[k1name]
                k2 = parms.all[k2name]
                g = parms.all[gname]
                f <- function(t, x) {
                    ((g * exp( - k1 * t) + (1 - g) * exp( - k2 * t)) - (1 - x/100))^2
                }
                DTmax1 <- log(2)/min(k1,k2)
                DTmax <- 1000
                DT50.o <- optimize(f, c(0, DTmax), x=50)$minimum
                DT50.o1 <- optimize(f, c(0, DTmax1), x=50)$minimum
                DT50.o <- ifelse(f(DT50.o,50)>f(DT50.o1,50), DT50.o1,DT50.o)
                DT50 = ifelse(DTmax - DT50.o < 0.1, NA, DT50.o)
                DT90.o <- optimize(f, c(0, DTmax), x=90)$minimum
                DTmax1 <- log(10)/min(k1,k2)
                DT90.o1 <- optimize(f, c(0, DTmax1), x=90)$minimum
                DT90.o <- ifelse(f(DT90.o,90)>f(DT90.o1,90), DT90.o1,DT90.o)
                DT90 = ifelse(DTmax - DT90.o < 0.1, NA, DT90.o)
            }
            if (type == "HS") {
                k1 = parms.all[k1name]
                k2 = parms.all[k2name]
                tb = parms.all[tbname]
                f <- function(t, x) {
                    fraction = ifelse(t <= tb, exp(-k1 * t), exp(-k1 * tb) * exp(-k2 * (t - tb)))
                    (fraction - (1 - x/100))^2
                }
                DTmax <- 1000
                ##DT50 <- nlm(f, 0.0001, x=50)$estimate
                ##DT90 <- nlm(f, 0.0001, x=90)$estimate
                hso1 <- nlminb(0.0001,f, x=50)
                hso2 <- nlminb(tb,f, x=50)
                DT50.o <- ifelse(hso1$objective<=hso2$objective,hso1$par,hso2$par)
                DT50 = ifelse(DTmax - DT50.o < 0.1, NA, DT50.o)

                hso1 <- nlminb(0.0001,f, x=90)
                hso2 <- nlminb(tb,f, x=90)
                DT90.o <- ifelse(hso1$objective<=hso2$objective,hso1$par,hso2$par)
                DT90 = ifelse(DTmax - DT90.o < 0.1, NA, DT90.o)

            }

            if (type == "SFORB") {
                                        # FOCUS kinetics (2006), p. 60 f
                k_out_names = grep(paste("k", obs_var, "free", sep="_"), names(parms.all), value=TRUE)
                k_out_names = setdiff(k_out_names, paste("k", obs_var, "free", "bound", sep="_"))
                k_1output = sum(parms.all[k_out_names])
                k_12 = parms.all[paste("k", obs_var, "free", "bound", sep="_")]
                k_21 = parms.all[paste("k", obs_var, "bound", "free", sep="_")]

                sqrt_exp = sqrt(1/4 * (k_12 + k_21 + k_1output)^2 + k_12 * k_21 - (k_12 + k_1output) * k_21)
                b1 = 0.5 * (k_12 + k_21 + k_1output) + sqrt_exp
                b2 = 0.5 * (k_12 + k_21 + k_1output) - sqrt_exp

                SFORB_fraction = function(t) {
                    ((k_12 + k_21 - b1)/(b2 - b1)) * exp(-b1 * t) +
                        ((k_12 + k_21 - b2)/(b1 - b2)) * exp(-b2 * t)
                }
                f_50 <- function(t) (SFORB_fraction(t) - 0.5)^2
                max_DT <- 1000
                DT50.o <- optimize(f_50, c(0.01, max_DT))$minimum
                if (abs(DT50.o - max_DT) < 0.01) DT50 = NA else DT50 = DT50.o
                f_90 <- function(t) (SFORB_fraction(t) - 0.1)^2
                DT90.o <- optimize(f_90, c(0.01, 1000))$minimum
                if (abs(DT90.o - max_DT) < 0.01) DT90 = NA else DT90 = DT90.o
                for (k_out_name in k_out_names)
                {
                    fit$ff[[sub("k_", "", k_out_name)]] = parms.all[[k_out_name]] / k_1output
                }
            }
            fit$distimes[obs_var, ] =c(ifelse(is.na(DT50),NA,formatC(DT50,4,format='f')), ifelse(is.na(DT90),NA,formatC(DT90,4,format='f')),type)# c(DT50, DT90,type)
        }

    }

                                        #browser()
    ## Collect observed, predicted and residuals
    observed0 <-  mkin_wide_to_long(mkinmodini$data0,time='time')
    observed0$err <- observed$err
    data <- merge(observed, predicted_long, by = c("time", "name"))
    data0 <- merge(observed0, predicted_long, by = c("time", "name"))
    names(data) <- c("time", "variable", "observed","weight","predicted")
    names(data0) <- c("time", "variable", "observed","weight", "predicted")
    data$residual <- data$observed - data$predicted
    data$variable <- ordered(data$variable, levels = obs_vars)
    data0$residual <- data$residual
    data0$variable <- data$variable
    tmpid <- is.na(data0$residual) & !is.na(data0$observed)
    data0$weight[tmpid] <- 0
    fit$data <- data[order(data$variable, data$time), ]
    fit$data0 <- data0[order(data0$variable, data0$time), ]
    fit$atol <- atol
    fit$inpartri <- inpartri
    fit$outpartri <- outpartri
    class(fit) <- c('kingui',"mkinfit", "modFit")
    return(fit)
}

