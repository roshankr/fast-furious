## notes_seizure_R
library(caret)
library(Hmisc)
library(data.table)
library(verification)

getBasePath = function (type = "data" , ds="") {
  ret = ""
  base.path1 = ""
  base.path2 = ""
  
  if(type == "data") {
    base.path1 = "C:/docs/ff/gitHub/fast-furious/dataset/seizure-prediction"
    base.path2 = "/Users/gino/kaggle/fast-furious/gitHub/fast-furious/dataset/seizure-prediction/"
  } else if (type == "code") {
    base.path1 = "C:/docs/ff/gitHub/fast-furious/data_pre_process"
    base.path2 = "/Users/gino/kaggle/fast-furious/gitHub/fast-furious/data_pre_process/"
  } else {
    stop("unrecognized type.")
  }
  
  if (file.exists(base.path1))  {
    ret = paste0(base.path1,"/")
  } else {
    ret = base.path2
  }
  
  if (ds != "" ) {
    ret = paste0(paste0(ret,ds),"_digest/")
  }
  ret
} 

######### models in action 
predictAndMeasure = function(model,model.label,model.id,trainingData,ytrain,testData,ytest,tm , 
                             ytrain.cat , ytest.cat ,   
                             grid = NULL,verbose=F) {
  pred.train = predict(model , trainingData) 
  RMSE.train = RMSE(obs = ytrain , pred = pred.train)
  
  pred = predict(model , testData) 
  RMSE.test = RMSE(obs = ytest , pred = pred)
  
  ## fitter.cat 
  train.cat = data.frame( cat = ytrain.cat , pr =  pred.train )
  test.cat = data.frame( pr =  pred )
  
#   ctrl <- trainControl(summaryFunction = twoClassSummary, classProbs = TRUE)
#   fitter.cat <- train( cat ~ pr ,  data=train.cat , method = "glm", metric = "ROC", trControl = ctrl)
#   pred.train.cat = predict(fitter.cat, train.cat ) 
#   pred.cat = predict(fitter.cat, test.cat ) 
#   
#   acc.train = sum(ytrain.cat == pred.train.cat) / length(ytrain.cat)
#   acc.test = sum(ytest.cat == pred.cat) / length(ytest.cat)
#   
#   roc.train = roc.area(as.numeric(ytrain.cat == 1) , as.numeric(pred.train.cat == 1) )$A
#   roc.test = roc.area(as.numeric(ytest.cat == 1) , as.numeric(pred.cat == 1) )$A

  fitter.cat <- glm( cat ~ pr ,  data=train.cat , family = binomial)
  pred.train.cat = predict(fitter.cat, newdata = train.cat , type = "response") 
  pred.cat = predict(fitter.cat, newdata = test.cat , type = "response") 

  rocCurve <- roc(response = ytrain.cat, predictor = as.numeric(pred.train.cat), levels = rev(levels(ytrain.cat)))
  roc.train = as.numeric( auc(rocCurve) )

  rocCurve <- roc(response = ytest.cat, predictor = as.numeric(pred.cat ), levels = rev(levels(ytest.cat)))
  roc.test = as.numeric( auc(rocCurve) )

  acc.train = sum(    factor(ifelse(pred.train.cat > 0.5,1,0), levels=levels(ytrain.cat)) ==   ytrain.cat   ) / length(ytrain.cat)
  acc.test = sum(     factor(ifelse(pred.cat > 0.5,1,0),       levels=levels(ytrain.cat)) ==   ytest.cat  ) / length(ytest.cat)
  
  if (verbose) cat("** RMSE(train) =",RMSE.train," -  RMSE(test) =",RMSE.test,"  --  Time elapsed(sec.):",tm[[3]], " \n")
  if (verbose) cat("** acc.train =",acc.train," -  acc.test =",acc.test,"  \n")
  if (verbose) cat("** roc.train =",roc.train," -  roc.test =",roc.test,"  \n")
  
  ### perf.grid 
  perf.grid = NULL
  if (is.null(grid)) { 
    perf.grid = data.frame(predictor = c(model.label) , model.id = c(model.id), RMSE.train = c(RMSE.train) , 
                           RMSE.test = c(RMSE.test) , 
                           acc.train = c(acc.train) , acc.test = c(acc.test) , 
                           roc.train = c(roc.train) , roc.test =c(roc.test),
                           time = c(tm[[3]]))
  } else {
    .grid = data.frame(predictor = c(model.label) , model.id = c(model.id), RMSE.train = c(RMSE.train) , 
                       RMSE.test = c(RMSE.test) , 
                       acc.train = c(acc.train) , acc.test = c(acc.test) , 
                       roc.train = c(roc.train) , roc.test =c(roc.test),
                       time = c(tm[[3]]) )
    perf.grid = rbind(grid, .grid)
  }
  
  perf.grid
}

######################################################## CONSTANTS 
LINEAR_REG_MEAN_SD = 1 
LINEAR_REG_QUANTILES = 2
PLS_MEAN_SD = 3 
PLS_QUANTILES = 4 
SVM_MEAN_SD = 5 
SVM_QUANTILES = 6 
BAGGED_TREE_MEAN_SD = 7 
BAGGED_TREE_QUANTILES = 8 
CART_MEAN_SD = 9
CART_QUANTILES = 10
CUBIST_MEAN_SD = 11 
CUBIST_QUANTILES = 12 

######################################################## MAIN LOOP 
sampleSubmission = as.data.frame(fread(paste(getBasePath(type = "data"),"sampleSubmission.csv",sep="") , header = T , sep=","  ))
predVect = rep(-1,dim(sampleSubmission)[1])
predVect.idx = 1

############# model selection ... 
verbose = T
controlObject <- trainControl(method = "repeatedcv", repeats = 5, number = 10)

dss = c("Dog_1","Dog_2","Dog_3","Dog_4","Dog_5","Patient_1","Patient_2")
##dss = c("Dog_2")
for (ds in dss) {
  
  cat("|---------------->>> processing data set <<",ds,">> ..\n")
  
  ######### loading data sets ...
  Xtrain_mean_sd = as.data.frame(fread(paste(getBasePath(type = "data" , ds=ds),"Xtrain_mean_sd.zat",sep="") , header = F , sep=","  ))
  Xtrain_quant = as.data.frame( fread(paste(getBasePath(type = "data" , ds=ds),"Xtrain_quant.zat",sep="") , header = F , sep=","  ))
  
  Xtest_mean_sd = as.data.frame(fread(paste(getBasePath(type = "data" , ds=ds),"Xtest_mean_sd.zat",sep="") , header = F , sep=","  ))
  Xtest_quant = as.data.frame(fread(paste(getBasePath(type = "data" , ds=ds),"Xtest_quant.zat",sep="") , header = F , sep=","  ))
  
  ytrain = as.data.frame(fread(paste(getBasePath(type = "data" , ds=ds),"ytrain.zat",sep="") , header = F , sep=","  ))
  
  ######### making train / xval set ... 
  Xtrain_mean_sd$time_before_seizure = ytrain[,1]
  Xtrain_quant$time_before_seizure = ytrain[,1]
  
  set.seed(975)
  forTraining <- createDataPartition(Xtrain_mean_sd$time_before_seizure, p = 3/4)[[1]]
  Xtrain_mean_sd.train <- Xtrain_mean_sd[ forTraining,]
  Xtrain_mean_sd.xval <- Xtrain_mean_sd[-forTraining,]
  
  Xtrain_quant.train <- Xtrain_quant[ forTraining,]
  Xtrain_quant.xval <- Xtrain_quant[-forTraining,]
  
  ytrain.cat = as.factor(ytrain[forTraining,2])
  ytest.cat = as.factor(ytrain[-forTraining,2])
  
  ######################################################## linear regression 
  if (verbose) cat("** [Xtrain_mean_sd] linear regression <<",LINEAR_REG_MEAN_SD,">> ...  \n")
  set.seed(669); ptm <- proc.time()
  linearReg <- train(time_before_seizure ~  . , data = Xtrain_mean_sd.train, method = "lm", trControl = controlObject) 
  #if (verbose) linearReg
  tm = proc.time() - ptm
  perf.grid = predictAndMeasure (linearReg,"Linear Reg (mean sd)",LINEAR_REG_MEAN_SD,Xtrain_mean_sd.train,
                                 Xtrain_mean_sd.train$time_before_seizure,
                                 Xtrain_mean_sd.xval,Xtrain_mean_sd.xval$time_before_seizure,
                                 tm ,  ytrain.cat , ytest.cat ,    
                                 grid = NULL , verbose)
  
  if (verbose) cat("** [Xtrain_quant] linear regression <<",LINEAR_REG_QUANTILES,">> ...  \n")
  set.seed(669); ptm <- proc.time()
  linearReg.quant <- train(time_before_seizure ~  . , data = Xtrain_quant.train, method = "lm", trControl = controlObject) 
  #if (verbose) linearReg.quant
  tm = proc.time() - ptm
  perf.grid = predictAndMeasure (linearReg.quant,"Linear Reg (quantiles)",LINEAR_REG_QUANTILES,Xtrain_quant.train,
                                 Xtrain_quant.train$time_before_seizure,
                                 Xtrain_quant.xval,Xtrain_quant.xval$time_before_seizure, 
                                 tm,  ytrain.cat , ytest.cat ,    
                                 grid = perf.grid , verbose )
  print(perf.grid)
  
  ######################################################## Partial Least Squares
  if (verbose) cat("** [Xtrain_mean_sd] Partial Least Squares <<",PLS_MEAN_SD,">> ...  \n")
  set.seed(669); ptm <- proc.time()
  plsModel <- train(time_before_seizure ~  . , data = Xtrain_mean_sd.train , method = "pls", preProc = c("center", "scale"), tuneLength = 15, trControl = controlObject)
  #if (verbose) plsModel
  tm = proc.time() - ptm
  perf.grid = predictAndMeasure (plsModel,"PLS (mean sd)",PLS_MEAN_SD,Xtrain_mean_sd.train,
                                 Xtrain_mean_sd.train$time_before_seizure,
                                 Xtrain_mean_sd.xval,Xtrain_mean_sd.xval$time_before_seizure,
                                 tm ,  ytrain.cat , ytest.cat ,    
                                 grid = perf.grid , verbose)
  
  if (verbose) cat("** [Xtrain_quant] Partial Least Squares <<",PLS_QUANTILES,">> ...  \n")
  set.seed(669); ptm <- proc.time()
  plsModel.quant <- train(time_before_seizure ~  . , data = Xtrain_quant.train , method = "pls", preProc = c("center", "scale"), tuneLength = 15, trControl = controlObject)
  #if (verbose) plsModel.quant
  tm = proc.time() - ptm
  perf.grid = predictAndMeasure (plsModel.quant,"PLS (quantiles)",PLS_QUANTILES,Xtrain_quant.train,
                                 Xtrain_quant.train$time_before_seizure,
                                 Xtrain_quant.xval,Xtrain_quant.xval$time_before_seizure, 
                                 tm,  ytrain.cat , ytest.cat ,    
                                 grid = perf.grid , verbose)
  print(perf.grid)
  
  ######################################################## Support Vector Machines 
  if (verbose) cat("** [Xtrain_mean_sd] Support Vector Machines <<",SVM_MEAN_SD,">> ...  \n")
  set.seed(669); ptm <- proc.time()
  svmRModel <- train(time_before_seizure ~  . , data = Xtrain_mean_sd.train ,  method = "svmRadial",
                     tuneLength = 15, preProc = c("center", "scale"),  trControl = controlObject)
  #if (verbose) svmRModel
  tm = proc.time() - ptm
  perf.grid = predictAndMeasure (svmRModel,"SVM (mean sd)",SVM_MEAN_SD,Xtrain_mean_sd.train,
                                 Xtrain_mean_sd.train$time_before_seizure,
                                 Xtrain_mean_sd.xval,Xtrain_mean_sd.xval$time_before_seizure,
                                 tm ,  ytrain.cat , ytest.cat ,    
                                 grid = perf.grid , verbose)
  
  if (verbose) cat("** [Xtrain_quant] Support Vector Machines <<",SVM_QUANTILES,">> ...  \n")
  set.seed(669); ptm <- proc.time()
  svmRModel.quant <- train(time_before_seizure ~  . , data = Xtrain_quant.train ,  method = "svmRadial",
                           tuneLength = 15, preProc = c("center", "scale"),  trControl = controlObject)
  #if (verbose) svmRModel.quant
  tm = proc.time() - ptm
  perf.grid = predictAndMeasure (svmRModel.quant,"SVM (quantiles)",SVM_QUANTILES,Xtrain_quant.train,
                                 Xtrain_quant.train$time_before_seizure,
                                 Xtrain_quant.xval,Xtrain_quant.xval$time_before_seizure, 
                                 tm,  ytrain.cat , ytest.cat ,    
                                 grid = perf.grid , verbose)
  print(perf.grid)
  
  ######################################################## Bagged Tree
  if (verbose) cat("** [Xtrain_mean_sd] Bagged Tree <<",BAGGED_TREE_MEAN_SD,">> ...  \n")
  set.seed(669); ptm <- proc.time()
  treebagModel <- train(time_before_seizure ~  . , data = Xtrain_mean_sd.train , method = "treebag", trControl = controlObject)
  #if (verbose) treebagModel
  tm = proc.time() - ptm
  perf.grid = predictAndMeasure (treebagModel,"Bagged Tree (mean sd)",BAGGED_TREE_MEAN_SD,Xtrain_mean_sd.train,Xtrain_mean_sd.train$time_before_seizure,
                                 Xtrain_mean_sd.xval,Xtrain_mean_sd.xval$time_before_seizure,
                                 tm , ytrain.cat , ytest.cat ,  
                                 grid = perf.grid , verbose)
  
  if (verbose) cat("** [Xtrain_quant] Bagged Tree <<",BAGGED_TREE_QUANTILES,">> ...  \n")
  set.seed(669); ptm <- proc.time()
  treebagModel.quant <- train(time_before_seizure ~  . , data = Xtrain_quant.train , method = "treebag", trControl = controlObject)
  
  #if (verbose) treebagModel.quant
  tm = proc.time() - ptm
  perf.grid = predictAndMeasure (treebagModel.quant,"Bagged Tree (quantiles)",BAGGED_TREE_QUANTILES,
                                 Xtrain_quant.train,Xtrain_quant.train$time_before_seizure,
                                 Xtrain_quant.xval,Xtrain_quant.xval$time_before_seizure, 
                                 tm, ytrain.cat , ytest.cat ,  
                                 grid = perf.grid , verbose )
  print(perf.grid)
  
  ######################################################## CART
  if (verbose) cat("** [Xtrain_mean_sd] CART <<",CART_MEAN_SD,">> ...  \n")
  set.seed(669); ptm <- proc.time()
  rpartModel <- train(time_before_seizure ~  . , data = Xtrain_mean_sd.train,  method = "rpart", tuneLength = 30, trControl = controlObject)
  #if (verbose) rpartModel
  tm = proc.time() - ptm
  perf.grid = predictAndMeasure (rpartModel,"CART (mean sd)",CART_MEAN_SD,
                                 Xtrain_mean_sd.train,Xtrain_mean_sd.train$time_before_seizure,
                                 Xtrain_mean_sd.xval,Xtrain_mean_sd.xval$time_before_seizure,
                                 tm , ytrain.cat , ytest.cat ,  
                                 grid = perf.grid , verbose)
  
  if (verbose) cat("** [Xtrain_quant] CART <<",CART_QUANTILES,">> ...  \n")
  set.seed(669); ptm <- proc.time()
  rpartModel.quant <- train(time_before_seizure ~  . , data = Xtrain_quant.train , method = "rpart", tuneLength = 30, trControl = controlObject)
  #if (verbose) rpartModel.quant
  tm = proc.time() - ptm
  perf.grid = predictAndMeasure (rpartModel.quant,"CART (quantiles)",CART_QUANTILES,Xtrain_quant.train,
                                 Xtrain_quant.train$time_before_seizure,
                                 Xtrain_quant.xval,Xtrain_quant.xval$time_before_seizure, 
                                 tm, ytrain.cat , ytest.cat ,  
                                 grid = perf.grid , verbose )
  print(perf.grid)
  
  ######################################################## CUBIST
  cat("** [Xtrain_mean_sd] CUBIST <<",CUBIST_MEAN_SD,">> ...  \n")
  set.seed(669); ptm <- proc.time()
  cubistGrid <- expand.grid(.committees = c(1, 5, 10, 50, 75, 100), .neighbors = c(0, 1, 3, 5, 7, 9))
  cbModel <- train(time_before_seizure ~  . , data = Xtrain_mean_sd.train ,  method = "cubist", 
                   tuneGrid = cubistGrid, trControl = controlObject)
  #if (verbose) cbModel
  tm = proc.time() - ptm
  perf.grid = predictAndMeasure (cbModel,"CUBIST (mean sd)",CUBIST_MEAN_SD,Xtrain_mean_sd.train,
                                 Xtrain_mean_sd.train$time_before_seizure,
                                 Xtrain_mean_sd.xval,Xtrain_mean_sd.xval$time_before_seizure,
                                 tm , ytrain.cat , ytest.cat ,  
                                 grid = perf.grid , verbose)
  
  if (verbose) cat("****** [Xtrain_quant] CUBIST <<",CUBIST_QUANTILES,">> ...  \n")
  set.seed(669); ptm <- proc.time()
  cubistGrid <- expand.grid(.committees = c(1, 5, 10, 50, 75, 100), .neighbors = c(0, 1, 3, 5, 7, 9))
  cbModel.quant <- train(time_before_seizure ~  . , data = Xtrain_quant.train ,  method = "cubist", 
                         tuneGrid = cubistGrid, trControl = controlObject)
  #if (verbose) cbModel.quant
  tm = proc.time() - ptm
  perf.grid = predictAndMeasure (cbModel.quant,"CUBIST (quantiles)",CUBIST_QUANTILES,Xtrain_quant.train,
                                 Xtrain_quant.train$time_before_seizure,
                                 Xtrain_quant.xval,Xtrain_quant.xval$time_before_seizure, 
                                 tm, ytrain.cat , ytest.cat ,  
                                 grid = perf.grid , verbose )
  print(perf.grid)
  
  ##### the winner is ... 
  perf.grid = perf.grid[order(perf.grid$roc.test, decreasing = T),] 
  model.id.winner = perf.grid[1,]$model.id
  model.label.winner = as.character(perf.grid[1,]$predictor) 
  cat("************ THE WINNER IS ",model.label.winner," <<",model.id.winner,">> \n")
  
  ##### saving on disk perf.grid ...
  write.csv(perf.grid,quote=FALSE,file=paste0(getBasePath(),paste0(ds,"_perf_grid_regress.csv")), row.names=FALSE)
  
  ##### re-train winner model on whole train set and predict on test set 
  Xtrain = Xtest = NULL
  model = NULL
  
  ## setting Xtrain, Xtest 
  if ( ( model.id.winner %% 2 == 0) ) {
    Xtrain = Xtrain_quant
    Xtest = Xtest_quant
  } else {
    Xtrain = Xtrain_mean_sd
    Xtest = Xtest_mean_sd
  }
  ytrain.cat = as.factor(ytrain[,2])
  
  ## fitting model on Xtrain 
  if (model.id.winner == LINEAR_REG_MEAN_SD | model.id.winner == LINEAR_REG_QUANTILES ) {
    if (verbose) cat("**** fitting linear regression on Xtrain <<",model.id.winner,">> ...  \n")
    set.seed(669)
    model <- train(time_before_seizure ~  . , data = Xtrain, method = "lm", trControl = controlObject) 
  } else if (model.id.winner == PLS_MEAN_SD | model.id.winner == PLS_QUANTILES) {
    if (verbose) cat("**** fitting Partial Least Squares on Xtrain <<",model.id.winner,">> ...  \n")
    set.seed(669)
    model <- train(time_before_seizure ~  . , data = Xtrain , method = "pls", preProc = c("center", "scale"), 
                   tuneLength = 15, trControl = controlObject)
  } else if (model.id.winner == SVM_MEAN_SD | model.id.winner == SVM_QUANTILES) {
    if (verbose) cat("**** fitting Support Vector Machines on Xtrain <<",model.id.winner,">> ...  \n")
    set.seed(669)
    model <- train(time_before_seizure ~  . , data = Xtrain ,  method = "svmRadial",
                       tuneLength = 15, preProc = c("center", "scale"),  trControl = controlObject)
  } else if (model.id.winner == BAGGED_TREE_MEAN_SD | model.id.winner == BAGGED_TREE_QUANTILES) {
    if (verbose) cat("***** fitting Bagged Tree on Xtrain <<",model.id.winner,">> ...  \n")
    set.seed(669)
    model <- train(time_before_seizure ~  . , data = Xtrain , method = "treebag", trControl = controlObject)
  } else if (model.id.winner == CART_MEAN_SD | model.id.winner == CART_QUANTILES) {
    if (verbose) cat("****** fitting CART on Xtrain <<",model.id.winner,">> ...  \n")
    set.seed(669); 
    model <- train(time_before_seizure ~  . , data = Xtrain,  method = "rpart", tuneLength = 30, 
                   trControl = controlObject)
  } else if (model.id.winner == CUBIST_MEAN_SD | model.id.winner == CUBIST_QUANTILES) {
    if (verbose) cat("****** fitting CUBIST on Xtrain <<",model.id.winner,">> ...  \n")
    set.seed(669)
    cubistGrid <- expand.grid(.committees = c(1, 5, 10, 50, 75, 100), .neighbors = c(0, 1, 3, 5, 7, 9))
    model <- train(time_before_seizure ~  . , data = Xtrain ,  method = "cubist", 
                           tuneGrid = cubistGrid, trControl = controlObject)
  } else {
    stop("unrecognized model.id.winner")
  } 
  
  ## predicting model on Xtest 
  pred.train = predict(model , Xtrain) 
  RMSE.train = RMSE(obs = ytrain[,1] , pred = pred.train)
  
  pred.test = predict(model , Xtest) 
  
  ## fitter.cat 
  train.cat = data.frame( cat = ytrain.cat , pr =  pred.train )
  test.cat = data.frame( pr =  pred.test )
  
#   ctrl <- trainControl(summaryFunction = twoClassSummary, classProbs = TRUE)
#   fitter.cat <- train( cat ~ pr ,  data=train.cat , method = "glm", metric = "ROC", trControl = ctrl)
#   pred.train.cat = predict(fitter.cat, train.cat ) 
#   pred.test.cat = predict(fitter.cat, data.frame(pr=pred.test) ) ####### <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

   fitter.cat <- glm( cat ~ pr ,  data=train.cat , family = binomial)
   pred.train.cat = predict(fitter.cat, newdata = train.cat , type = "response") 
   pred.test.cat = predict(fitter.cat, newdata = test.cat , type = "response") ####### <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  
#   acc.train = sum(ytrain.cat == pred.train.cat) / length(ytrain.cat)
  acc.train = sum(    factor(ifelse(pred.train.cat > 0.5,1,0), levels=levels(ytrain.cat)) ==   ytrain.cat   ) / length(ytrain.cat)

  ##roc.train = roc.area(as.numeric(ytrain.cat == 1) , as.numeric(pred.train.cat == 1) )$A
  rocCurve <- roc(response = ytrain.cat, predictor = as.numeric(pred.train.cat), levels = rev(levels(ytrain.cat)))
  roc.train = as.numeric( auc(rocCurve) )
  
  if (verbose) cat("** acc.train =",acc.train," -  roc.train =",roc.train," \n")
  if (verbose) cat("** RMSE(train) =",RMSE.train," \n")
  
  ### update predVect 
  predVect[predVect.idx:(predVect.idx+length(pred.test.cat)-1)] = as.numeric(pred.test.cat)
  predVect.idx = predVect.idx + length(pred.test.cat)
}

## submission 
mySub = data.frame(clip = sampleSubmission$clip , preictal = predVect)
write.csv(mySub,quote=FALSE,file=paste0(getBasePath(),"mySub.zat"), row.names=FALSE)
