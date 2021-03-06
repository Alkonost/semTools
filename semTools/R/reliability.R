## Title: Reliability of factors
## Author: Sunthud Pornprasertmanit <psunthud@ku.edu>; Yves Rosseel <Yves.Rosseel@UGent.be>
## Description: Find the relability values of each factor
##----------------------------------------------------------------------------##

reliability <- function(object) {
	param <- lavInspect(object, "est")
	ngroup <- lavInspect(object, "ngroups")
	name <- names(param)
	if (ngroup == 1L) {
		ly <- param[name == "lambda"]
	} else {
		ly <- lapply(param, "[[", "lambda")
	}
	ps <- lavInspect(object, "cov.lv")
	if (ngroup == 1L) {
	  ps <- list(ps)
		te <- param[name == "theta"]
	} else {
		te <- lapply(param, "[[", "theta")
	}
	SigmaHat <- lavInspect(object, "cov.ov")
	if (ngroup == 1L) {
	  SigmaHat <- list(SigmaHat)
		tau <- param[name == "tau"]
	} else {
		tau <- lapply(param, "[[", "tau")
	}
	implied <- lavaan::fitted.values(object)[name = "cov"]
	categorical <- (length(tau) > 0) && !is.null(tau[[1]])
	threshold <- NULL
	if (ngroup == 1L) {
    S <- list(lavInspect(object, "sampstat")$cov)
	} else {
		S <- lapply(lavInspect(object, "sampstat"), function(x) x$cov)
	}
	if (categorical) {
		polycor <- polycorLavaan(object)
		if (ngroup == 1L) polycor <- list(polycor)
		S <- lapply(polycor, function(x) x[rownames(ly[[1]]), rownames(ly[[1]])])
		threshold <- getThreshold(object)
		SigmaHat <- thetaImpliedTotalVar(object)
	}
	flag <- FALSE
	result <- list()
	for (i in 1:ngroup) {
		common <- (apply(ly[[i]], 2, sum)^2) * diag(ps[[i]])
		truevar <- ly[[i]]%*%ps[[i]]%*%t(ly[[i]])
		error <- rep(NA, length(common))
		alpha <- rep(NA, length(common))
		total <- rep(NA, length(common))
		omega1 <- omega2 <- omega3 <- rep(NA, length(common))
		impliedTotal <- rep(NA, length(common))
		avevar <- rep(NA, length(common))
		for (j in 1:length(common)) {
			index <- which(ly[[i]][,j] != 0)
			error[j] <- sum(te[[i]][index, index, drop = FALSE])
			sigma <- S[[i]][index, index, drop = FALSE]
			alpha[j] <- computeAlpha(sigma, length(index))
			total[j] <- sum(sigma)
			impliedTotal[j] <- sum(SigmaHat[[i]][index, index, drop = FALSE])
			faccontrib <- ly[[i]][,j, drop = FALSE] %*% ps[[i]][j,j, drop = FALSE] %*% t(ly[[i]][,j, drop = FALSE])
			truefac <- diag(faccontrib[index, index, drop = FALSE])
			commonfac <- sum(faccontrib[index, index, drop = FALSE])
			trueitem <- diag(truevar[index, index, drop = FALSE])
			erritem <- diag(te[[i]][index, index, drop = FALSE])
			if (sum(abs(trueitem - truefac)) < 0.00001) {
				avevar[j] <- sum(trueitem) / sum(trueitem + erritem)
			} else {
				avevar[j] <- NA
			}
			if (categorical) {
				omega1[j] <- omegaCat(truevar = faccontrib[index, index, drop = FALSE],
				                      implied = SigmaHat[[i]][index, index, drop = FALSE],
				                      threshold = threshold[[i]][index],
				                      denom = faccontrib[index, index, drop = FALSE] + te[[i]][index, index, drop = FALSE])
				omega2[j] <- omegaCat(truevar = faccontrib[index, index, drop = FALSE],
				                      implied = SigmaHat[[i]][index, index, drop = FALSE],
				                      threshold = threshold[[i]][index],
				                      denom = SigmaHat[[i]][index, index, drop = FALSE])
				omega3[j] <- omegaCat(truevar = faccontrib[index, index, drop = FALSE],
				                      implied = SigmaHat[[i]][index, index, drop = FALSE],
				                      threshold = threshold[[i]][index],
				                      denom = sigma)
			} else {
				omega1[j] <- commonfac / (commonfac + error[j])
				omega2[j] <- commonfac / impliedTotal[j]
				omega3[j] <- commonfac / total[j]
			}
		}
		alpha <- c(alpha, total = computeAlpha(S[[i]], nrow(S[[i]])))
		names(alpha) <- c(names(common), "total")
		if (categorical) {
			omega1 <- c(omega1, total = omegaCat(truevar = truevar,
			                                     implied = SigmaHat[[i]],
			                                     threshold = threshold[[i]],
			                                     denom = truevar + te[[i]]))
			omega2 <- c(omega2, total = omegaCat(truevar = truevar,
			                                     implied = SigmaHat[[i]],
			                                     threshold = threshold[[i]],
			                                     denom = SigmaHat[[i]]))
			omega3 <- c(omega3, total = omegaCat(truevar = truevar,
			                                     implied = SigmaHat[[i]],
			                                     threshold = threshold[[i]],
			                                     denom = S[[i]]))
		} else {
			omega1 <- c(omega1, total = sum(truevar) / (sum(truevar) + sum(te[[i]])))
			omega2 <- c(omega2, total = sum(truevar) / (sum(SigmaHat[[i]])))
			omega3 <- c(omega3, total = sum(truevar) / (sum(S[[i]])))
		}
		avevar <- c(avevar, total = sum(diag(truevar))/ sum((diag(truevar) + diag(te[[i]]))))
		singleIndicator <- apply(ly[[i]], 2, function(x) sum(x != 0)) %in% 0:1
		result[[i]] <- rbind(alpha = alpha, omega = omega1, omega2 = omega2,
		                     omega3 = omega3, avevar = avevar)[ , !singleIndicator]
	}
	if (flag) warning("The alpha and the average variance extracted are",
	                  " calculated from polychoric (polyserial) correlation not",
	                  " from Pearson's correlation.\n")
	if (ngroup == 1L) {
		result <- result[[1]]
	} else {
		names(result) <- lavInspect(object, "group.label")
	}
	result
}

computeAlpha <- function(S, k) k/(k - 1) * (1.0 - sum(diag(S)) / sum(S))

reliabilityL2 <- function(object, secondFactor) {
	param <- lavInspect(object, "est")
	ngroup <- lavInspect(object, "ngroups")
	name <- names(param)
	if (ngroup == 1L) {
		ly <- param[name == "lambda"]
	} else {
		ly <- lapply(param, "[[", "lambda")
	}
	ve <- lavInspect(object, "cov.lv")
	if (ngroup == 1L) ve <- list(ve)
	if (ngroup == 1L) {
		ps <- param[name == "psi"]
		te <- param[name == "theta"]
		be <- param[name == "beta"]
	} else {
		ps <- lapply(param, "[[", "psi")
		te <- lapply(param, "[[", "theta")
		be <- lapply(param, "[[", "beta")
	}
	SigmaHat <- lavInspect(object, "cov.ov")
	if (ngroup == 1L) {
		SigmaHat <- list(SigmaHat)
		S <- list(lavInspect(object, "sampstat")$cov)
	} else {
		S <- lapply(lavInspect(object, "sampstat"), function(x) x$cov)
	}
	result <- list()
	for (i in 1:ngroup) {

		# Prepare for higher-order reliability
		l2var <- ve[[i]][secondFactor, secondFactor, drop = FALSE]
		l2load <- be[[1]][,secondFactor]
		indexl2 <- which(l2load != 0)
		commonl2 <- (sum(l2load)^2) * l2var
		errorl2 <- sum(ps[[i]][indexl2, indexl2, drop = FALSE])

		# Prepare for lower-order reliability
		indexl1 <- which(apply(ly[[i]][,indexl2], 1, function(x) sum(x != 0)) > 0)
		l1load <- ly[[i]][,indexl2] %*% as.matrix(be[[1]][indexl2, secondFactor, drop = FALSE])
		commonl1 <- (sum(l1load)^2) * l2var
		errorl1 <- sum(te[[i]][indexl1, indexl1, drop = FALSE])
		uniquel1 <- 0
		for (j in seq_along(indexl2)) {
			uniquel1 <- uniquel1 + (sum(ly[[i]][,indexl2[j]])^2) * ps[[i]][indexl2[j], indexl2[j], drop = FALSE]
		}

		# Adjustment for direct loading from L2 to observed variables
		if (any(ly[[i]][,secondFactor] != 0)) {
			indexind <- which(ly[[i]][,secondFactor] != 0)
			if (length(intersect(indexind, indexl1)) > 0)
			  stop("Direct and indirect loadings of higher-order factor to observed",
			       " variables are specified at the same time.")
			commonl2 <- sum(c(ly[[i]][,secondFactor], l2load))^2 * l2var
			errorl2 <- errorl2 + sum(te[[i]][indexind, indexind, drop = FALSE])
			commonl1 <- sum(c(ly[[i]][,secondFactor], l1load))^2 * l2var
			errorl1 <- errorl1 + sum(te[[i]][indexind, indexind, drop = FALSE])
		}

		# Calculate Reliability
		omegaL1 <- commonl1 / (commonl1 + uniquel1 + errorl1)
		omegaL2 <- commonl2 / (commonl2 + errorl2)
		partialOmegaL1 <- commonl1 / (commonl1 + errorl1)
		result[[i]] <- c(omegaL1 = omegaL1, omegaL2 = omegaL2, partialOmegaL1 = partialOmegaL1)
	}
	if (ngroup == 1L) {
		result <- result[[1]]
	} else {
		names(result) <- lavInspect(object, "group.label")
	}
	result
}

omegaCat <- function(truevar, implied, threshold, denom) {
	# denom could be polychoric correlation, model-implied correlation, or model-implied without error correlation
	polyc <- truevar
	invstdvar <- 1 / sqrt(diag(implied))
	polyr <- diag(invstdvar) %*% polyc %*% diag(invstdvar)
	nitem <- ncol(implied)
	denom <- cov2cor(denom)
	sumnum <- 0
	addden <- 0
	for (j in 1:nitem) {
	for (jp in 1:nitem) {
		sumprobn2 <- 0
		addprobn2 <- 0
		t1 <- threshold[[j]]
		t2 <- threshold[[jp]]
		for (c in 1:length(t1)) {
		for (cp in 1:length(t2)) {
			sumprobn2 <- sumprobn2 + p2(t1[c], t2[cp], polyr[j, jp])
			addprobn2 <- addprobn2 + p2(t1[c], t2[cp], denom[j, jp])
		}
		}
		sumprobn1 <- sum(pnorm(t1))
		sumprobn1p <- sum(pnorm(t2))
		sumnum <- sumnum + (sumprobn2 - sumprobn1 * sumprobn1p)
		addden <- addden + (addprobn2 - sumprobn1 * sumprobn1p)
	}
	}
	reliab <- sumnum / addden
	reliab
}


p2 <- function(t1, t2, r) {
	mnormt::pmnorm(c(t1, t2), c(0,0), matrix(c(1, r, r, 1), 2, 2))
}


polycorLavaan <- function(object) {
	ngroups <- lavInspect(object, "ngroups")
	coef <- lavInspect(object, "est")
	targettaunames <- NULL
	if (ngroups == 1L) {
		targettaunames <- rownames(coef$tau)
	} else {
		targettaunames <- rownames(coef[[1]]$tau)
	}
	barpos <- sapply(strsplit(targettaunames, ""), function(x) which(x == "|"))
	varnames <- unique(apply(data.frame(targettaunames, barpos - 1), 1, function(x) substr(x[1], 1, x[2])))
	script <- ""
	for (i in 2:length(varnames)) {
		temp <- paste0(varnames[1:(i - 1)], collapse = " + ")
		temp <- paste0(varnames[i], "~~", temp, "\n")
		script <- paste(script, temp)
	}
	newobject <- refit(script, object)
	if (ngroups == 1L) {
		return(lavInspect(newobject, "est")$theta)
	}
	lapply(lavInspect(newobject, "est"), "[[", "theta")
}

getThreshold <- function(object) {
	ngroups <- lavInspect(object, "ngroups")
	coef <- lavInspect(object, "est")
	result <- NULL
	if (ngroups == 1L) {
		targettaunames <- rownames(coef$tau)
		barpos <- sapply(strsplit(targettaunames, ""), function(x) which(x == "|"))
		varthres <- apply(data.frame(targettaunames, barpos - 1), 1, function(x) substr(x[1], 1, x[2]))
		result <- list(split(coef$tau, varthres))
	} else {
		result <- list()
		for (g in 1:ngroups) {
			targettaunames <- rownames(coef[[g]]$tau)
			barpos <- sapply(strsplit(targettaunames, ""), function(x) which(x == "|"))
			varthres <- apply(data.frame(targettaunames, barpos - 1), 1, function(x) substr(x[1], 1, x[2]))
			result[[g]] <- split(coef[[g]]$tau, varthres)
		}
	}
	return(result)
}

invGeneralRelia <- function(w, truevar, totalvar) {
	1 - (t(w) %*% truevar %*% w) / (t(w) %*% totalvar %*% w)
}

invGeneralReliaCat <- function(w, polyr, threshold, denom, nitem) {
	# denom could be polychoric correlation, model-implied correlation, or model-implied without error correlation
	upper <- matrix(NA, nitem, nitem)
	lower <- matrix(NA, nitem, nitem)
	for (j in 1:nitem) {
  	for (jp in 1:nitem) {
  		sumprobn2 <- 0
  		addprobn2 <- 0
  		t1 <- threshold[[j]]
  		t2 <- threshold[[jp]]
  		for (c in 1:length(t1)) {
  		for (cp in 1:length(t2)) {
  			sumprobn2 <- sumprobn2 + p2(t1[c], t2[cp], polyr[j, jp])
  			addprobn2 <- addprobn2 + p2(t1[c], t2[cp], denom[j, jp])
  		}
  		}
  		sumprobn1 <- sum(pnorm(t1))
  		sumprobn1p <- sum(pnorm(t2))
  		upper[j, jp] <- (sumprobn2 - sumprobn1 * sumprobn1p)
  		lower[j, jp] <- (addprobn2 - sumprobn1 * sumprobn1p)
  	}
	}
	1 - (t(w) %*% upper %*% w) / (t(w) %*% lower %*% w)
}


calcMaximalRelia <- function(truevar, totalvar, varnames) {
	start <- rep(1, nrow(truevar))
	out <- nlminb(start, invGeneralRelia, truevar = truevar, totalvar = totalvar)
	if (out$convergence != 0) stop("The numerical method for finding the maximal",
	                               " reliability was not converged.")
	result <- 1 - out$objective
	weight <- out$par / mean(out$par)
	names(weight) <- varnames
	attr(result, "weight") <- weight
	result
}

calcMaximalReliaCat <- function(polyr, threshold, denom, nitem, varnames) {
	start <- rep(1, nrow(polyr))
	out <- nlminb(start, invGeneralReliaCat, polyr = polyr, threshold = threshold, denom = denom, nitem = nitem)
	if (out$convergence != 0) stop("The numerical method for finding the maximal",
	                               " reliability was not converged.")
	result <- 1 - out$objective
	weight <- out$par / mean(out$par)
	names(weight) <- varnames
	attr(result, "weight") <- weight
	result
}

maximalRelia <- function(object) {
	param <- lavInspect(object, "est")
	ngroup <- lavInspect(object, "ngroups")
	name <- names(param)
	if (ngroup == 1L) {
		ly <- param[name == "lambda"]
	} else {
		ly <- lapply(param, "[[", "lambda")
	}
	ps <- lavInspect(object, "cov.lv")
	SigmaHat <- lavInspect(object, "cov.ov")
  if (ngroup == 1L) {
    ps <- list(ps)
    SigmaHat <- list(SigmaHat)
    S <- list(lavInspect(object, "sampstat")$cov)
  } else {
    S <- lapply(lavInspect(object, "sampstat"), function(x) x$cov)
  }
	if (ngroup == 1) {
		tau <- param[name = "tau"]
	} else {
		tau <- lapply(param, "[[", "tau")
	}
	categorical <- length(tau) > 0 && !is.null(tau[[1]])
	threshold <- NULL
	result <- list()
	if (categorical) {
		polycor <- polycorLavaan(object)
		if (ngroup == 1L) polycor <- list(polycor)
		S <- lapply(polycor, function(x) x[rownames(ly[[1]]), rownames(ly[[1]])])
		threshold <- getThreshold(object) # change to lavInspect(object, "th")?
		                                  ## No, it is a list per item, rather than a single vector
		SigmaHat <- thetaImpliedTotalVar(object)
	}
	for (i in 1:ngroup) {
		truevar <- ly[[i]] %*% ps[[i]] %*% t(ly[[i]])
		varnames <- colnames(truevar)
		if (categorical) {
			invstdvar <- 1 / sqrt(diag(SigmaHat[[i]]))
			polyr <- diag(invstdvar) %*% truevar %*% diag(invstdvar)
			nitem <- ncol(SigmaHat[[i]])
			result[[i]] <- calcMaximalReliaCat(polyr, threshold[[i]], S[[i]], nitem, varnames)
		} else {
			result[[i]] <- calcMaximalRelia(truevar, S[[i]], varnames)
		}
	}
	if (ngroup == 1L) {
		result <- result[[1]]
	} else {
		names(result) <- lavInspect(object, "group.label")
	}
	result
}
