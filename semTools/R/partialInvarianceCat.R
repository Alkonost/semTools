# Work with only with congeneric models

partialInvarianceCat <- function(fit, type, free = NULL, fix = NULL, p.adjust = "none", return.fit = FALSE) { 
	type <- tolower(type)
	numType <- 0
	fit1 <- fit0 <- NULL
	# fit0 = Nested model, fit1 = Parent model
	if(type %in% c("metric", "weak", "loading", "loadings")) {
		numType <- 1
		if(all(c("configural", "metric") %in% names(fit))) {
			fit1 <- fit$configural
			fit0 <- fit$metric
		} else {
			stop("Both configural and metric invariance models are needed in the 'fit' argument")
		}
	} else if (type %in% c("scalar", "strong", "intercept", "intercepts", "threshold", "thresholds")) {
		numType <- 2
		if(all(c("metric", "scalar") %in% names(fit))) {
			fit1 <- fit$metric
			fit0 <- fit$scalar
		} else {
			stop("Both metric and scalar invariance models are needed in the 'fit' argument")
		}
	} else if (type %in% c("strict", "residual", "residuals", "error", "errors")) {
		numType <- 3
		if("strict" %in% names(fit)) {
			fit0 <- fit$strict
			if("scalar" %in% names(fit)) {
				fit1 <- fit$scalar			
			} else if ("metric" %in% names(fit)) {
				fit1 <- fit$metric			
			} else {
				stop("Either scalar or metric invariance models is needed in the 'fit' argument")
			}			
		} else {
			stop("The strict invariance model is needed in the 'fit' argument")
		}
	} else if (type %in% c("means", "mean")) {
		numType <- 4
		if("means" %in% names(fit)) {
			fit0 <- fit$means
			if("strict" %in% names(fit)) {
				fit1 <- fit$strict			
			} else if ("scalar" %in% names(fit)) {
				fit1 <- fit$scalar			
			} else if ("metric" %in% names(fit)) {
				fit1 <- fit$metric			
			} else {
				stop("Either metric, scalar, or strict invariance models is needed in the 'fit' argument")
			}
		} else {
			stop("Mean invariance models is needed in the 'fit' argument")
		}
	} else {
		stop("Please specify the correct type of measurement invariance. See the help page.")
	}
	pt1 <- partable(fit1)
	pt0 <- partable(fit0)
	namept1 <- paramNameFromPt(pt1)
	namept0 <- paramNameFromPt(pt0)
	if(length(table(table(pt0$rhs[pt0$op == "=~"]))) != 1) stop("The model is not congeneric. This function does not support non-congeneric model.")
	varfree <- varnames <- unique(pt0$rhs[pt0$op == "=~"])
	facnames <- unique(pt0$lhs[(pt0$op == "=~") & (pt0$rhs %in% varnames)])
	facrepresent <- table(pt0$lhs[(pt0$op == "=~") & (pt0$rhs %in% varnames)], pt0$rhs[(pt0$op == "=~") & (pt0$rhs %in% varnames)])
	if(any(apply(facrepresent, 2, function(x) sum(x != 0)) > 1)) stop("The model is not congeneric. This function does not support non-congeneric model.")
	facList <- list()
	for(i in 1:nrow(facrepresent)) {
		facList[[i]] <- colnames(facrepresent)[facrepresent[i,] > 0]
	}
	names(facList) <- rownames(facrepresent)
	facList <- facList[match(names(facList), facnames)]
	fixLoadingFac <- list()
	for(i in seq_along(facList)) {
		select <- pt1$lhs == names(facList)[i] & pt1$op == "=~" & pt1$rhs %in% facList[[i]] & pt1$group == 1 & pt1$free == 0 & (!is.na(pt1$ustart) & pt1$ustart > 0)
		fixLoadingFac[[i]] <- pt1$rhs[select]
	}
	names(fixLoadingFac) <- names(facList)
	
	# Find the number of thresholds
	# Check whether the factor configuration is the same across gorups
	groupParTable <- split(pt1, pt1$group)
	group1pt <- groupParTable[[1]]
	numThreshold <- table(sapply(group1pt, "[", group1pt$op == "|")[,"lhs"])
	numFixedThreshold <- table(sapply(group1pt, "[", group1pt$op == "|" & group1pt$eq.id != 0)[,"lhs"])
	fixIntceptFac <- list()
	for(i in seq_along(facList)) {
		tmp <- numFixedThreshold[facList[[i]]]
		if(all(tmp > 1)) {
			fixIntceptFac[[i]] <- integer(0)
		} else {
			fixIntceptFac[[i]] <- names(which.max(tmp))[1]
		}
	}
	names(fixIntceptFac) <- names(facList)
	
	ngroups <- max(pt0$group)
	if(ngroups <= 1) stop("Well, the number of groups is 1. Measurement invariance across 'groups' cannot be done.")

	if(numType == 4) {
		if(!all(c(free, fix) %in% facnames)) stop("'free' and 'fix' arguments should consist of factor names because mean invariance is tested.")
	} else {
		if(!all(c(free, fix) %in% varnames)) stop("'free' and 'fix' arguments should consist of variable names.")
	}
	result <- fixCon <- freeCon <- NULL
	listFreeCon <- listFixCon <- list()	
	beta <- coef(fit1)
	waldMat <- matrix(0, ngroups - 1, length(beta))	
	if(numType == 1) {
		if(!is.null(free) | !is.null(fix)) {
			if(!is.null(fix)) {
				facinfix <- findFactor(fix, facList)
				dup <- duplicated(facinfix)
				for(i in seq_along(fix)) {
					if(dup[i]) {
						pt0 <- constrainParTable(pt0, facinfix[i], "=~", fix[i], 1:ngroups)
						pt1 <- constrainParTable(pt1, facinfix[i], "=~", fix[i], 1:ngroups)					
					} else {
						oldmarker <- fixLoadingFac[[facinfix[i]]]
						if(length(oldmarker) > 0) {
							oldmarkerval <- pt1$ustart[pt1$lhs == facinfix[i] & pt1$op == "=~" & pt1$rhs == oldmarker & pt1$group == 1]
							if(oldmarker == fix[i]) {
								pt0 <- fixParTable(pt0, facinfix[i], "=~", fix[i], 1:ngroups, oldmarkerval)
								pt1 <- fixParTable(pt1, facinfix[i], "=~", fix[i], 1:ngroups, oldmarkerval)
							} else {
								pt0 <- freeParTable(pt0, facinfix[i], "=~", oldmarker, 1:ngroups)
								pt0 <- constrainParTable(pt0, facinfix[i], "=~", oldmarker, 1:ngroups)
								pt1 <- freeParTable(pt1, facinfix[i], "=~", oldmarker, 1:ngroups)
								pt0 <- fixParTable(pt0, facinfix[i], "=~", fix[i], 1:ngroups, oldmarkerval)
								pt1 <- fixParTable(pt1, facinfix[i], "=~", fix[i], 1:ngroups, oldmarkerval)
								fixLoadingFac[[facinfix[i]]] <- fix[i]
							}
						} else {
							pt0 <- constrainParTable(pt0, facinfix[i], "=~", fix[i], 1:ngroups)
							pt1 <- constrainParTable(pt1, facinfix[i], "=~", fix[i], 1:ngroups)					
						}
					}
				}
			}
			if(!is.null(free)) {
				facinfree <- findFactor(free, facList)
				for(i in seq_along(free)) {
					# Need to change marker variable if fixed
					oldmarker <- fixLoadingFac[[facinfree[i]]]
					if(length(oldmarker) > 0 && oldmarker == free[i]) {
						oldmarkerval <- pt1$ustart[pt1$lhs == facinfix[i] & pt1$op == "=~" & pt1$rhs == oldmarker & pt1$group == 1]
						candidatemarker <- setdiff(facList[[facinfree[i]]], free[i])[1]
						pt0 <- freeParTable(pt0, facinfree[i], "=~", free[i], 1:ngroups)
						pt1 <- freeParTable(pt1, facinfree[i], "=~", free[i], 1:ngroups)
						pt0 <- fixParTable(pt0, facinfix[i], "=~", candidatemarker, 1:ngroups, oldmarkerval)
						pt1 <- fixParTable(pt1, facinfix[i], "=~", candidatemarker, 1:ngroups, oldmarkerval)
						fixLoadingFac[[facinfix[i]]] <- candidatemarker
					} else {
						pt0 <- freeParTable(pt0, facinfree[i], "=~", free[i], 1:ngroups)
						pt1 <- freeParTable(pt1, facinfree[i], "=~", free[i], 1:ngroups)
					}
				}
			}
			namept1 <- paramNameFromPt(pt1)
			namept0 <- paramNameFromPt(pt0)
			fit0 <- refit(pt0, fit0)
			fit1 <- refit(pt1, fit1)
			beta <- coef(fit1)
			waldMat <- matrix(0, ngroups - 1, length(beta))
			varfree <- setdiff(varfree, c(free, fix))
		}

		fixCon <- freeCon <- waldCon <- matrix(NA, length(varfree), 3)
		colnames(fixCon) <- c("fix.chi", "fix.df", "fix.p")
		colnames(freeCon) <- c("free.chi", "free.df", "free.p")
		colnames(waldCon) <- c("wald.chi", "wald.df", "wald.p")
		index <- which((pt1$rhs %in% varfree) & (pt1$op == "=~") & (pt1$group == 1))
		facinfix <- findFactor(fix, facList)
		varinfixvar <- unlist(facList[facinfix])
		varinfixvar <- setdiff(varinfixvar, setdiff(varinfixvar, varfree))
		indexfixvar <- which((pt1$rhs %in% varinfixvar) & (pt1$op == "=~") & (pt1$group == 1))
		varnonfixvar <- setdiff(varfree, varinfixvar)
		indexnonfixvar <- setdiff(index, indexfixvar)
		
		pos <- 1
		for(i in seq_along(indexfixvar)) {
			runnum <- indexfixvar[i]
			temp <- constrainParTable(pt1, pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 1:ngroups)
			tryresult <- try(tempfit <- refit(temp, fit1), silent = TRUE)
			if(!is(tryresult, "try-error")) {
				compresult <- try(modelcomp <- lavTestLRT(tempfit, fit1), silent = TRUE)
				if(!is(compresult, "try-error"))  fixCon[pos,] <- unlist(modelcomp[2,5:7])
			}
			listFixCon <- c(listFixCon, tryresult)
			temp0 <- freeParTable(pt0, pt0$lhs[runnum], pt0$op[runnum], pt0$rhs[runnum], 1:ngroups)
			tryresult0 <- try(tempfit0 <- refit(temp0, fit0), silent = TRUE)
			if(!is(tryresult0, "try-error")) {
				compresult0 <- try(modelcomp0 <- lavTestLRT(tempfit0, fit0), silent = TRUE)
				if(!is(compresult0, "try-error"))  freeCon[pos,] <- unlist(modelcomp0[2,5:7])
			}
			listFreeCon <- c(listFreeCon, tryresult0)
			waldCon[pos,] <- waldConstraint(fit1, pt1, waldMat, cbind(pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 1:ngroups))
			pos <- pos + 1
		}

		facinvarfree <- findFactor(varnonfixvar, facList)
		for(i in seq_along(indexnonfixvar)) {
			runnum <- indexnonfixvar[i]
			# Need to change marker variable if fixed
			oldmarker <- fixLoadingFac[[facinvarfree[i]]]
			if(length(oldmarker) > 0 && oldmarker == varnonfixvar[i]) {
				candidatemarker <- setdiff(facList[[facinvarfree[i]]], varnonfixvar[i])[1]
				temp <- freeParTable(pt1, facinvarfree[i], "=~", varnonfixvar[i], 1:ngroups)
				temp <- constrainParTable(temp, facinvarfree[i], "=~", varnonfixvar[i], 1:ngroups)
				temp <- fixParTable(temp, facinvarfree[i], "=~", candidatemarker, 1:ngroups)
				newparent <- freeParTable(pt1, facinvarfree[i], "=~", varnonfixvar[i], 1:ngroups)
				newparent <- fixParTable(newparent, facinvarfree[i], "=~", candidatemarker, 1:ngroups)
				newparentfit <- refit(newparent, fit1)
				
				tryresult <- try(tempfit <- refit(temp, fit1), silent = TRUE)
				if(!is(tryresult, "try-error")) {
					compresult <- try(modelcomp <- lavTestLRT(tempfit, newparentfit), silent = TRUE)
					if(!is(compresult, "try-error"))  fixCon[pos,] <- unlist(modelcomp[2,5:7])
				}
				waldCon[pos,] <- waldConstraint(newparentfit, newparent, waldMat, cbind(facinvarfree[i], "=~", varnonfixvar[i], 1:ngroups))
			} else {
				temp <- constrainParTable(pt1, pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 1:ngroups)
				tryresult <- try(tempfit <- refit(temp, fit1), silent = TRUE)
				if(!is(tryresult, "try-error")) {
					compresult <- try(modelcomp <- lavTestLRT(tempfit, fit1), silent = TRUE)
					if(!is(compresult, "try-error"))  fixCon[pos,] <- unlist(modelcomp[2,5:7])
				}
				waldCon[pos,] <- waldConstraint(fit1, pt1, waldMat, cbind(pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 1:ngroups))
			}
			listFixCon <- c(listFixCon, tryresult)
			if(length(oldmarker) > 0 && oldmarker == varnonfixvar[i]) {
				temp0 <- freeParTable(pt0, pt0$lhs[runnum], pt0$op[runnum], pt0$rhs[runnum], 2:ngroups)
			} else {
				temp0 <- freeParTable(pt0, pt0$lhs[runnum], pt0$op[runnum], pt0$rhs[runnum], 1:ngroups)
			}
			tryresult0 <- try(tempfit0 <- refit(temp0, fit0), silent = TRUE)
			if(!is(tryresult0, "try-error")) {
				compresult0 <- try(modelcomp0 <- lavTestLRT(tempfit0, fit0), silent = TRUE)
				if(!is(compresult0, "try-error"))  freeCon[pos,] <- unlist(modelcomp0[2,5:7])
			}
			listFreeCon <- c(listFreeCon, tryresult0)
			pos <- pos + 1
		}
		freeCon[,3] <- stats::p.adjust(freeCon[,3], p.adjust)
		fixCon[,3] <- stats::p.adjust(fixCon[,3], p.adjust)
		waldCon[,3] <- stats::p.adjust(waldCon[,3], p.adjust)

		rownames(fixCon) <- names(listFixCon) <- rownames(freeCon) <- names(listFreeCon) <- rownames(waldCon) <- namept1[c(indexfixvar, indexnonfixvar)]
		result <- cbind(freeCon, fixCon, waldCon)		
	} else if (numType == 2) {
		if(!is.null(free) | !is.null(fix)) {
			if(!is.null(fix)) {
				facinfix <- findFactor(fix, facList)
				dup <- duplicated(facinfix)
				for(i in seq_along(fix)) {
					numfixthres <- numThreshold[fix[i]]
					if(numfixthres > 1) {
						if(dup[i]) {
							for(s in 2:numfixthres) {
								pt0 <- constrainParTable(pt0, fix[i], "|", paste0("t", s), 1:ngroups)
								pt1 <- constrainParTable(pt1, fix[i], "|", paste0("t", s), 1:ngroups)			
							}
						} else {
							oldmarker <- fixIntceptFac[[facinfix[i]]]
							numoldthres <- numThreshold[oldmarker]
							if(length(oldmarker) > 0) {
								if(oldmarker == fix[i]) {
									for(s in 2:numfixthres) {
										pt0 <- constrainParTable(pt0, fix[i], "|", paste0("t", s), 1:ngroups)
										pt1 <- constrainParTable(pt1, fix[i], "|", paste0("t", s), 1:ngroups)			
									}	
								} else {
									for(r in 2:numoldthres) {
										pt1 <- freeParTable(pt1, oldmarker, "|", paste0("t", r), 1:ngroups)										
									}
									for(s in 2:numfixthres) {
										pt0 <- constrainParTable(pt0, fix[i], "|", paste0("t", s), 1:ngroups)		
										pt1 <- constrainParTable(pt1, fix[i], "|", paste0("t", s), 1:ngroups)	
									}	
									fixIntceptFac[[facinfix[i]]] <- fix[i]
								}
							} else {
								for(s in 2:numfixthres) {
									pt0 <- constrainParTable(pt0, fix[i], "|", paste0("t", s), 1:ngroups)
									pt1 <- constrainParTable(pt1, fix[i], "|", paste0("t", s), 1:ngroups)			
								}				
							}
						}
					}
				}
			}
			if(!is.null(free)) {
				facinfree <- findFactor(free, facList)
				for(i in seq_along(free)) {
					numfreethres <- numThreshold[free[i]]
					# Need to change marker variable if fixed
					oldmarker <- fixIntceptFac[[facinfree[i]]]
					numoldthres <- numThreshold[oldmarker]
					if(length(oldmarker) > 0 && oldmarker == free[i]) {
						candidatemarker <- setdiff(facList[[facinfree[i]]], free[i])
						candidatemarker <- candidatemarker[numThreshold[candidatemarker] > 1][1]
						numcandidatethres <- numThreshold[candidatemarker]
						pt0 <- constrainParTable(pt0, candidatemarker, "|", "t2", 1:ngroups)
						pt1 <- constrainParTable(pt1, candidatemarker, "|", "t2", 1:ngroups)
						for(s in 2:numfixthres) {
							pt0 <- freeParTable(pt0, free[i], "|", paste0("t", s), 1:ngroups)
							pt1 <- freeParTable(pt1, free[i], "|", paste0("t", s), 1:ngroups)			
						}	
						fixIntceptFac[[facinfix[i]]] <- candidatemarker
					} else {
						for(s in 2:numfixthres) {
							pt0 <- freeParTable(pt0, free[i], "|", paste0("t", s), 1:ngroups)
							pt1 <- freeParTable(pt1, free[i], "|", paste0("t", s), 1:ngroups)			
						}	
					}
				}
			}
			namept1 <- paramNameFromPt(pt1)
			namept0 <- paramNameFromPt(pt0)
			fit0 <- refit(pt0, fit0)
			fit1 <- refit(pt1, fit1)
			beta <- coef(fit1)
			waldMat <- matrix(0, ngroups - 1, length(beta))
			varfree <- setdiff(varfree, c(free, fix))
		}

		fixCon <- freeCon <- waldCon <- matrix(NA, length(varfree), 3)
		colnames(fixCon) <- c("fix.chi", "fix.df", "fix.p")
		colnames(freeCon) <- c("free.chi", "free.df", "free.p")
		colnames(waldCon) <- c("wald.chi", "wald.df", "wald.p")

		facinfix <- findFactor(fix, facList)
		varinfixvar <- unlist(facList[facinfix])
		varinfixvar <- setdiff(varinfixvar, setdiff(varinfixvar, varfree))
		varnonfixvar <- setdiff(varfree, varinfixvar)
		
		pos <- 1
		for(i in seq_along(varinfixvar)) {
			temp <- pt1
			for(s in 2:numThreshold[varinfixvar[i]]) {
				runnum <- which((pt1$lhs == varfree[i]) & (pt1$op == "|") & (pt1$rhs == paste0("t", s)) & (pt1$group == 1))
				temp <- constrainParTable(temp, pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 1:ngroups)
			}
			tryresult <- try(tempfit <- refit(temp, fit1), silent = TRUE)
			if(!is(tryresult, "try-error")) {
				compresult <- try(modelcomp <- lavTestLRT(tempfit, fit1), silent = TRUE)
				if(!is(compresult, "try-error"))  fixCon[pos,] <- unlist(modelcomp[2,5:7])
			}
			listFixCon <- c(listFixCon, tryresult)
			temp0 <- pt0
			for(s in 2:numThreshold[varinfixvar[i]]) {
				runnum <- which((pt0$lhs == varfree[i]) & (pt0$op == "|") & (pt0$rhs == paste0("t", s)) & (pt0$group == 1))
				temp0 <- freeParTable(temp0, pt0$lhs[runnum], pt0$op[runnum], pt0$rhs[runnum], 1:ngroups)
			}			
			tryresult0 <- try(tempfit0 <- refit(temp0, fit0), silent = TRUE)
			if(!is(tryresult0, "try-error")) {
				compresult0 <- try(modelcomp0 <- lavTestLRT(tempfit0, fit0), silent = TRUE)
				if(!is(compresult0, "try-error"))  freeCon[pos,] <- unlist(modelcomp0[2,5:7])
			}
			listFreeCon <- c(listFreeCon, tryresult0)
			args <- list(fit1, pt1, waldMat)
			for(s in 2:numThreshold[varinfixvar[i]]) {
				runnum <- which((pt1$lhs == varfree[i]) & (pt1$op == "|") & (pt1$rhs == paste0("t", s)) & (pt1$group == 1))
				args <- c(args, list(cbind(pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 1:ngroups)))
			}
			waldCon[pos,] <- do.call(waldConstraint, args)
			pos <- pos + 1
		}

		facinvarfree <- findFactor(varnonfixvar, facList)
		for(i in seq_along(varnonfixvar)) {
			# Need to change marker variable if fixed
			oldmarker <- fixIntceptFac[[facinvarfree[i]]]
			if(length(oldmarker) > 0 && oldmarker == varfree[i]) {
				candidatemarker <- setdiff(facList[[facinvarfree[i]]], varnonfixvar[i])
				candidatemarker <- candidatemarker[numThreshold[candidatemarker] > 1][1]
				numcandidatethres <- numThreshold[candidatemarker]
				newparent <- constrainParTable(pt1, candidatemarker, "|", "t2", 1:ngroups)
				for(s in 2:numfixthres) {
					newparent <- freeParTable(newparent, varnonfixvar[i], "|", paste0("t", s), 1:ngroups)			
				}	
				temp <- newparent
				for(s in 2:numThreshold[varnonfixvar[i]]) {
					runnum <- which((newparent$lhs == varnonfixvar[i]) & (newparent$op == "|") & (newparent$rhs == paste0("t", s)) & (newparent$group == 1))
					temp <- constrainParTable(temp, newparent$lhs[runnum], newparent$op[runnum], newparent$rhs[runnum], 1:ngroups)
				}
				newparentfit <- refit(newparent, fit1)
				
				tryresult <- try(tempfit <- refit(temp, fit1), silent = TRUE)
				if(!is(tryresult, "try-error")) {
					compresult <- try(modelcomp <- lavTestLRT(tempfit, newparentfit), silent = TRUE)
					if(!is(compresult, "try-error"))  fixCon[pos,] <- unlist(modelcomp[2,5:7])
				}
				args <- list(newparentfit, newparent, waldMat)
				for(s in 2:numThreshold[varnonfixvar[i]]) {
					runnum <- which((newparent$lhs == varnonfixvar[i]) & (newparent$op == "|") & (newparent$rhs == paste0("t", s)) & (newparent$group == 1))
					args <- c(args, list(cbind(newparent$lhs[runnum], newparent$op[runnum], newparent$rhs[runnum], 1:ngroups)))
				}
				waldCon[pos,] <- do.call(waldConstraint, args)
			} else {
				temp <- pt1
				for(s in 2:numThreshold[varnonfixvar[i]]) {
					runnum <- which((pt1$lhs == varfree[i]) & (pt1$op == "|") & (pt1$rhs == paste0("t", s)) & (pt1$group == 1))
					temp <- constrainParTable(temp, pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 1:ngroups)
				}
				tryresult <- try(tempfit <- refit(temp, fit1), silent = TRUE)
				if(!is(tryresult, "try-error")) {
					compresult <- try(modelcomp <- lavTestLRT(tempfit, fit1), silent = TRUE)
					if(!is(compresult, "try-error"))  fixCon[pos,] <- unlist(modelcomp[2,5:7])
				}
				args <- list(fit1, pt1, waldMat)
				for(s in 2:numThreshold[varnonfixvar[i]]) {
					runnum <- which((pt1$lhs == varfree[i]) & (pt1$op == "|") & (pt1$rhs == paste0("t", s)) & (pt1$group == 1))
					args <- c(args, list(cbind(pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 1:ngroups)))
				}
				waldCon[pos,] <- do.call(waldConstraint, args)
			}
			listFixCon <- c(listFixCon, tryresult)
			
			temp0 <- pt0
			for(s in 2:numThreshold[varnonfixvar[i]]) {
				runnum <- which((pt0$lhs == varfree[i]) & (pt0$op == "|") & (pt0$rhs == paste0("t", s)) & (pt0$group == 1))
				temp0 <- freeParTable(temp0, pt0$lhs[runnum], pt0$op[runnum], pt0$rhs[runnum], 1:ngroups)
			}
			tryresult0 <- try(tempfit0 <- refit(temp0, fit0), silent = TRUE)
			if(!is(tryresult0, "try-error")) {
				compresult0 <- try(modelcomp0 <- lavTestLRT(tempfit0, fit0), silent = TRUE)
				if(!is(compresult0, "try-error"))  freeCon[pos,] <- unlist(modelcomp0[2,5:7])
			}
			listFreeCon <- c(listFreeCon, tryresult0)
			pos <- pos + 1
		}
		freeCon[,3] <- stats::p.adjust(freeCon[,3], p.adjust)
		fixCon[,3] <- stats::p.adjust(fixCon[,3], p.adjust)
		waldCon[,3] <- stats::p.adjust(waldCon[,3], p.adjust)
		rownames(fixCon) <- names(listFixCon) <- rownames(freeCon) <- names(listFreeCon) <- rownames(waldCon) <- paste0(c(varinfixvar, varnonfixvar), "|")
		result <- cbind(freeCon, fixCon, waldCon)		
	} else if (numType == 3) {
		if(!is.null(free) | !is.null(fix)) {
			if(!is.null(fix)) {
				for(i in seq_along(fix)) {
					pt0 <- constrainParTable(pt0, fix[i], "~~", fix[i], 1:ngroups)
					pt1 <- constrainParTable(pt1, fix[i], "~~", fix[i], 1:ngroups)					
				}
			}
			if(!is.null(free)) {
				for(i in seq_along(free)) {
					pt0 <- freeParTable(pt0, free[i], "~~", free[i], 1:ngroups)
					pt1 <- freeParTable(pt1, free[i], "~~", free[i], 1:ngroups)
				}
			}
			namept1 <- paramNameFromPt(pt1)
			namept0 <- paramNameFromPt(pt0)
			fit0 <- refit(pt0, fit0)
			fit1 <- refit(pt1, fit1)
			beta <- coef(fit1)
			waldMat <- matrix(0, ngroups - 1, length(beta))
			varfree <- setdiff(varfree, c(free, fix))
		}

		fixCon <- freeCon <- waldCon <- matrix(NA, length(varfree), 3)
		colnames(fixCon) <- c("fix.chi", "fix.df", "fix.p")
		colnames(freeCon) <- c("free.chi", "free.df", "free.p")
		colnames(waldCon) <- c("wald.chi", "wald.df", "wald.p")
		index <- which((pt1$lhs %in% varfree) & (pt1$op == "~~") & (pt1$lhs == pt1$rhs) & (pt1$group == 1))
		for(i in seq_along(index)) {
			runnum <- index[i]
			temp <- constrainParTable(pt1, pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 1:ngroups)
			tryresult <- try(tempfit <- refit(temp, fit1), silent = TRUE)
			if(!is(tryresult, "try-error")) {
				compresult <- try(modelcomp <- lavTestLRT(tempfit, fit1), silent = TRUE)
				if(!is(compresult, "try-error"))  fixCon[i,] <- unlist(modelcomp[2,5:7])
			}
			listFixCon <- c(listFixCon, tryresult)
			temp0 <- freeParTable(pt0, pt0$lhs[runnum], pt0$op[runnum], pt0$rhs[runnum], 1:ngroups)
			tryresult0 <- try(tempfit0 <- refit(temp0, fit0), silent = TRUE)
			if(!is(tryresult0, "try-error")) {
				compresult0 <- try(modelcomp0 <- lavTestLRT(tempfit0, fit0), silent = TRUE)
				if(!is(compresult0, "try-error"))  freeCon[i,] <- unlist(modelcomp0[2,5:7])
			}
			listFreeCon <- c(listFreeCon, tryresult0)
			waldCon[i,] <- waldConstraint(fit1, pt1, waldMat, cbind(pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 1:ngroups))
		}
		freeCon[,3] <- stats::p.adjust(freeCon[,3], p.adjust)
		fixCon[,3] <- stats::p.adjust(fixCon[,3], p.adjust)
		waldCon[,3] <- stats::p.adjust(waldCon[,3], p.adjust)
		rownames(fixCon) <- names(listFixCon) <- rownames(freeCon) <- names(listFreeCon) <- rownames(waldCon) <- namept1[index]
		result <- cbind(freeCon, fixCon, waldCon)		
	} else if (numType == 4) {
		varfree <- facnames
		if(!is.null(free) | !is.null(fix)) {
			if(!is.null(fix)) {
				for(i in seq_along(fix)) {
					pt0 <- constrainParTable(pt0, fix[i], "~1", "", 1:ngroups)
					pt1 <- constrainParTable(pt1, fix[i], "~1", "", 1:ngroups)					
				}
			}
			if(!is.null(free)) {
				for(i in seq_along(free)) {
					pt0 <- freeParTable(pt0, free[i], "~1", "", 1:ngroups)
					pt1 <- freeParTable(pt1, free[i], "~1", "", 1:ngroups)
				}
			}
			namept1 <- paramNameFromPt(pt1)
			namept0 <- paramNameFromPt(pt0)
			fit0 <- refit(pt0, fit0)
			fit1 <- refit(pt1, fit1)
			beta <- coef(fit1)
			waldMat <- matrix(0, ngroups - 1, length(beta))
			varfree <- setdiff(varfree, c(free, fix))
		}

		fixCon <- freeCon <- waldCon <- matrix(NA, length(varfree), 3)
		colnames(fixCon) <- c("fix.chi", "fix.df", "fix.p")
		colnames(freeCon) <- c("free.chi", "free.df", "free.p")
		colnames(waldCon) <- c("wald.chi", "wald.df", "wald.p")
		index <- which((pt1$lhs %in% varfree) & (pt1$op == "~1") & (pt1$group == 1))
		for(i in seq_along(index)) {
			runnum <- index[i]
			isfree <- pt1$free[runnum] != 0
			if(isfree) {
				temp <- constrainParTable(pt1, pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 1:ngroups)
			} else {
				temp <- fixParTable(pt1, pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 2:ngroups, ustart = pt1$ustart[runnum])
			}
			tryresult <- try(tempfit <- refit(temp, fit1), silent = TRUE)
			if(!is(tryresult, "try-error")) {
				compresult <- try(modelcomp <- lavTestLRT(tempfit, fit1), silent = TRUE)
				if(!is(compresult, "try-error"))  fixCon[i,] <- unlist(modelcomp[2,5:7])
			}
			listFixCon <- c(listFixCon, tryresult)
			isfree0 <- pt0$free[runnum] != 0
			if(isfree0) {
				temp0 <- freeParTable(pt0, pt0$lhs[runnum], pt0$op[runnum], pt0$rhs[runnum], 1:ngroups)
			} else {
				temp0 <- freeParTable(pt0, pt0$lhs[runnum], pt0$op[runnum], pt0$rhs[runnum], 2:ngroups)
			}
			tryresult0 <- try(tempfit0 <- refit(temp0, fit0), silent = TRUE)
			if(!is(tryresult0, "try-error")) {
				compresult0 <- try(modelcomp0 <- lavTestLRT(tempfit0, fit0), silent = TRUE)
				if(!is(compresult0, "try-error"))  freeCon[i,] <- unlist(modelcomp0[2,5:7])
			}
			listFreeCon <- c(listFreeCon, tryresult0)
			waldCon[i,] <- waldConstraint(fit1, pt1, waldMat, cbind(pt1$lhs[runnum], pt1$op[runnum], pt1$rhs[runnum], 1:ngroups))
		}
		freeCon[,3] <- stats::p.adjust(freeCon[,3], p.adjust)
		fixCon[,3] <- stats::p.adjust(fixCon[,3], p.adjust)
		waldCon[,3] <- stats::p.adjust(waldCon[,3], p.adjust)
		rownames(fixCon) <- names(listFixCon) <- rownames(freeCon) <- names(listFreeCon) <- rownames(waldCon) <- namept1[index]
		result <- cbind(freeCon, fixCon, waldCon)		
	}
	if(return.fit) {
		return(invisible(list(result = result, models = list(free = listFreeCon, fix = listFixCon, nested = fit0, parent = fit1))))
	} else {
		return(result)
	}
}