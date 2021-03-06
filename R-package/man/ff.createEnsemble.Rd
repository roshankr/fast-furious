% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fastRegression.R
\name{ff.createEnsemble}
\alias{ff.createEnsemble}
\title{Create an ensemble of a tuned model}
\usage{
ff.createEnsemble(Xtrain, Xtest, y, caretModelName, bestTune, predTest = NULL,
  removePredictorsMakingIllConditionedSquareMatrix_forLinearModels = TRUE,
  controlObject, parallelize = TRUE, verbose = TRUE, regression = TRUE,
  ...)
}
\arguments{
\item{Xtrain}{the encoded \code{data.frame} of train data. Must be a \code{data.frame} of \code{numeric}}

\item{Xtest}{the encoded \code{data.frame} of test data. Must be a \code{data.frame} of \code{numeric}}

\item{y}{the output variable as numeric vector}

\item{caretModelName}{a string specifying which model to use. Possible values for regression are \code{'lm'}, \code{'bayesglm'}, 
\code{'glm'}, \code{'glmStepAIC'}, \code{'rlm'}, \code{'knn'}, \code{'pls'}, \code{'ridge'}, \code{'enet'}, 
\code{'svmRadial'}, \code{'treebag'}, \code{'gbm'}, \code{'rf'}, \code{'cubist'}, \code{'avNNet'}, 
\code{'xgbTreeGTJ'}, \code{'xgbTree'}.}

\item{bestTune}{a \code{data.frame} with best tuned parameters of specified model.}

\item{predTest}{test set prediction (numeric vector). If available, passing it through this paramter 
the function doesn't compute it again for creating the esemble.}

\item{removePredictorsMakingIllConditionedSquareMatrix_forLinearModels}{\code{TRUE} for removing predictors making 
ill-conditioned square matrices in case of fragile linear models, i.e. \code{c('rlm','pls','ridge','enet')} for regression.}

\item{controlObject}{a list of values that define how this function acts. Must be a caret \code{trainControl} object}

\item{parallelize}{\code{TRUE} to enable parallelization (require \code{parallel}).}

\item{verbose}{\code{TRUE} to enable verbose mode.}

\item{regression}{\code{TRUE} to create an ensemble of a tuned regression model and \code{FALSE} to create an ensemble of a tuned classification model.}

\item{...}{arguments passed to the regression routine.}
}
\value{
a list of train and test predictions.
}
\description{
Create an ensemble of a tuned model
}
\examples{

## suppress warnings raised because there few obs 
warn_def = getOption('warn')
options(warn=-1)

## data 
Xtrain <- data.frame( a = rep(1:10 , each = 2), b = 20:1, 
c = rep(as.Date(c("2007-06-22", "2004-02-13")),10) )
Xtest <- data.frame( a = rep(2:11 , each = 2), b = 1:20, 
c = rep(as.Date(c("2007-03-01", "2004-05-23")),10) )
Ytrain = 1:20 + runif(nrow(Xtrain))

## encode datasets 
l = ff.makeFeatureSet(Xtrain,Xtest,c("C","N","D"))
Xtrain = l$traindata
Xtest = l$testdata

## make a caret control object 
controlObject <- trainControl(method = "repeatedcv", repeats = 1, number = 2)

tp = ff.trainAndPredict.reg(Ytrain=Ytrain ,
                          Xtrain=Xtrain , 
                          Xtest=Xtest , 
                          model.label = "cubist" , 
                          controlObject=controlObject)

pred_test = tp$pred
model = tp$model
secs = tp$secs

## create ensemble 
en = ff.createEnsemble(Xtrain = Xtrain, 
                      Xtest = Xtest, 
                      y = Ytrain, 
                      bestTune = tp$model$bestTune , 
                      caretModelName = "cubist" , 
                      parallelize = TRUE, 
                      removePredictorsMakingIllConditionedSquareMatrix_forLinearModels = TRUE, 
                      controlObject = tp$model$control)
predTrain = en$predTrain
predTest = en$predTest

## restore warnings 
options(warn=warn_def)

}

