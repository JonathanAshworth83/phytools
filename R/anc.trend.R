## this function estimates ancestral traits with a trend
## written by Liam J. Revell 2011, 2013, 2015, 2017

anc.trend<-function(tree,x,maxit=2000){
	if(!inherits(tree,"phylo")) stop("tree should be an object of class \"phylo\".")

	## check if tree is ultrametric
	if(is.ultrametric(tree)) 
		cat("Warning: the trend model is generally non-identifiable for ultrametric trees.\n")

	# preliminaries
	# set global
	tol<-1e-8
	# check to make sure that C will be non-singular
	if(any(tree$edge.length<=(10*.Machine$double.eps)))
		stop("some branch lengths are 0 or nearly zero")
	# compute C
	D<-dist.nodes(tree)
	ntips<-length(tree$tip.label)
	Cii<-D[ntips+1,]
	C<-D; C[,]<-0
	counts<-vector()
	for(i in 1:nrow(D)) for(j in 1:ncol(D)) C[i,j]<-(Cii[i]+Cii[j]-D[i,j])/2
	dimnames(C)[[1]][1:length(tree$tip)]<-tree$tip.label
	dimnames(C)[[2]][1:length(tree$tip)]<-tree$tip.label
	C<-C[c(1:ntips,(ntips+2):nrow(C)),c(1:ntips,(ntips+2):ncol(C))]
	# sort x by tree$tip.label
	x<-x[tree$tip.label]

	# function returns the negative log-likelihood
	likelihood<-function(theta,x,C){
		a<-theta[1]
		u<-theta[2]
		sig2<-theta[3]
		y<-theta[4:length(theta)]
		logLik<-dmnorm(x=c(x,y),mean=(a+diag(C)*u),
			varcov=sig2*C,log=TRUE)
		return(-logLik)
	}

	# get reasonable starting values for the optimizer
	a<-mean(x)
	sig2<-var(x)/max(C)

	# perform ML optimization
	result<-optim(par=c(a,0,sig2,rep(a,tree$Nnode-1)),likelihood,
		x=x,C=C,method="L-BFGS-B",lower=c(-Inf,-Inf,tol,rep(-Inf,tree$Nnode-1)),
		control=list(maxit=maxit))

	# return the result
	ace<-c(result$par[c(1,4:length(result$par))])
	names(ace)<-c(as.character(tree$edge[1,1]),
		rownames(C)[(length(tree$tip.label)+1):nrow(C)])
	obj<-list(ace=ace,mu=result$par[2],sig2=result$par[3],
		logL=-result$value,convergence=result$convergence,
		message=result$message)
	class(obj)<-"anc.trend"
	obj
}


## print method for "anc.trend"
## written by Liam J. Revell 2015, 2017
print.anc.trend<-function(x,digits=6,printlen=NULL,...){
	cat("Ancestral character estimates using anc.trend:\n")
	Nnode<-length(x$ace)
	if(is.null(printlen)||printlen>=Nnode) print(round(x$ace,digits))
	else printDotDot(x$ace,digits,printlen)
	cat("\nParameter estimates:\n")
	cat(paste("\tmu",paste(rep(" ",digits),collapse=""),"\tsig^2",
		paste(rep(" ",max(digits-3,1)),collapse=""),"\tlog(L)\n",sep=""))
	cat(paste("\t",round(x$mu,digits),"\t",round(x$sig2,digits),"\t",
		round(x$logL,digits),"\n"),sep="")
	if(x$convergence==0) cat("\nR thinks it has converged.\n\n")
	else cat("\nR thinks function may not have converged.\n\n")
}

## logLik method for "anc.trend"
logLik.anc.trend<-function(object,...){
	lik<-object$logL
	attr(lik,"df")<-length(object$ace)+2
	lik
}
