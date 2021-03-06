library(caret)
library(Hmisc)
library(data.table)
library(kernlab)
library(subselect)
library(plyr)
library(binhf)
library(fBasics)

getBasePath = function (type = "data") {
  ret = ""
  base.path1 = ""
  base.path2 = ""
  
  if(type == "data") {
    base.path1 = "C:/docs/ff/gitHub/fast-furious/dataset/walmart-recruiting-sales-in-stormy-weather"
    base.path2 = "/Users/gino/kaggle/fast-furious/gitHub/fast-furious/dataset/walmart-recruiting-sales-in-stormy-weather/"
  } else if (type == "code") {
    base.path1 = "C:/docs/ff/gitHub/fast-furious/competitions/walmart-recruiting-sales-in-stormy-weather"
    base.path2 = "/Users/gino/kaggle/fast-furious/gitHub/fast-furious/competitions/walmart-recruiting-sales-in-stormy-weather/"
  } else if (type == "process") {
    base.path1 = "C:/docs/ff/gitHub/fast-furious/data_process"
    base.path2 = "/Users/gino/kaggle/fast-furious/gitHub/fast-furious/data_process/"
  } else {
    stop("unrecognized type.")
  }
  
  if (file.exists(base.path1))  {
    ret = paste0(base.path1,"/")
  } else {
    ret = base.path2
  }
  
  ret
} 
intrapolatePredTS <- function(train.chunk, test.chunk,doPlot=F) {
  data.chucks = rbind(train.chunk,test.chunk)
  data.chucks = data.chucks[order(data.chucks$as.date,decreasing = F),]
  test.idx = which(  is.na(data.chucks)   )
  ts.all = ts(data.chucks$units ,frequency = 365, start = c(2012,1) )
  x <- ts(ts.all,f=4)
  fit <- ts(rowSums(tsSmooth(StructTS(x))[,-2]))
  tsp(fit) <- tsp(x)
  if (doPlot) {
    plot(x)
    lines(fit,col=2)
  }
  pred = fit[test.idx]
  rmse = RMSE(pred = as.numeric(fit[!is.na(x)]) , obs = train.chunk$units)
  list(pred,rmse)
}


getTrain = function () {
  path = ""
  
  base.path1 = "C:/docs/ff/gitHub/fast-furious/dataset/walmart-recruiting-sales-in-stormy-weather/train.csv"
  base.path2 = "/Users/gino/kaggle/fast-furious/gitHub/fast-furious/dataset/walmart-recruiting-sales-in-stormy-weather/train.csv"
  
  if (file.exists(base.path1))  {
    path = base.path1
  } else if (file.exists(base.path2)) {
    path = base.path2
  } else {
    stop('impossible load train.csv')
  }
  
  cat("loading train data ... ")
  trdata = as.data.frame(fread(path))
  #cat("converting date ...")
  #trdata$date = as.Date(trdata$date,"%Y-%m-%d")
  trdata
} 
getTest = function () {
  path = ""
  
  base.path1 = "C:/docs/ff/gitHub/fast-furious/dataset/walmart-recruiting-sales-in-stormy-weather/test.csv"
  base.path2 = "/Users/gino/kaggle/fast-furious/gitHub/fast-furious/dataset/walmart-recruiting-sales-in-stormy-weather/test.csv"
  
  if (file.exists(base.path1))  {
    path = base.path1
  } else if (file.exists(base.path2)) {
    path = base.path2
  } else {
    stop('impossible load train.csv')
  }
  
  cat("loading train data ... ")
  trdata = as.data.frame(fread(path))
  #cat("converting date ...")
  #trdata$date = as.Date(trdata$date,"%Y-%m-%d")
  trdata
} 

#########
verbose = T 

#########
train = getTrain()
test = getTest()

model.grid = as.data.frame( fread(paste(getBasePath("data") , 
                                        "mySub_grid.csv" , sep='')))

ts.grid = as.data.frame( fread(paste(getBasePath("data") , 
                                     "mySubTS_grid.csv" , sep='')))

model.sub = as.data.frame( fread(paste(getBasePath("data") , 
                                       "mySub.csv" , sep='')))

sub = as.data.frame( fread(paste(getBasePath("data") , 
                                    "mySub_trend_included.csv" , sep='')))

sampleSubmission = as.data.frame( fread(paste(getBasePath("data") , 
                                              "sampleSubmission.csv" , sep='')))

keys = as.data.frame( fread(paste(getBasePath("data") , 
                                  "key.csv" , sep='')))

weather = as.data.frame( fread(paste(getBasePath("data") , 
                                     "weather.imputed.basic.17.9.csv" , sep=''))) ## <<<< TODO use weather.imputed.all.<perf>.csv



stores.test = sort(unique(test$store_nbr))
items.test = sort(unique(test$item_nbr))

################
verbose = T 
################

Adjuststments = data.frame(st=c(37,33,17,16,17,30,33,7,26), 
                           it=c(5,9,9,25,48,44,44,95,5)
                           )

#################
for (i in 1:dim(Adjuststments)[1]) {
  st = Adjuststments[i,]$st
  it = Adjuststments[i,]$it
  stat = keys[keys$store_nbr == st,]$station_nbr 
  cat ("Adjiusting st=",st," -  it=",it,"\n")
  
  ########
  pred = NULL
  
  ## testdata
  testdata = test[test$store_nbr == st & test$item_nbr == it ,  ]
  testdata$station_nbr = stat
  testdata = merge(x = testdata,y = weather, by=c("station_nbr","date"))
  testdata.header = testdata[,c(1,2,3,4)]
  testdata = testdata[,-c(1,2,3,4)]
  
  ## traindata
  traindata = train[train$store_nbr == st & train$item_nbr == it ,  ]
  traindata$station_nbr = stat
  traindata = merge(x = traindata,y = weather, by=c("station_nbr","date"))
  traindata.header = traindata[,c(1,2,3,4,5)]
  traindata.y = traindata[,5]
  traindata = traindata[,-c(1,2,3,4,5)]
  
  ######## visulaze
  traindata.header$as.date = as.Date(traindata.header$date, "%Y-%m-%d")
  traindata.header$data_type = 1
  
  testdata.header$as.date = as.Date(testdata.header$date, "%Y-%m-%d")
  testdata.header$data_type = 2 
  
  train.chunk = traindata.header[,c(5,6,7)]
  test.chunk = testdata.header[,c(5,6)]
  test.chunk$units = NA
  
  l = tryCatch({ 
    intrapolatePredTS (train.chunk, test.chunk,doPlot=T)
  } , error = function(err) { 
    print(paste("ERROR:  ",err))
    NULL
  })
  
  pred = l[[1]]
  if (st == 37 & it == 5) {
    cat("37 - 5    \n")
    m.p = mean(pred)
    cat("mean of prediction before =",m.p ,"\n")
    train.chunk$units = ifelse(train.chunk$units > 154 , 100, train.chunk$units)
    
    l = tryCatch({ 
      intrapolatePredTS (train.chunk, test.chunk,doPlot=T)
    } , error = function(err) { 
      print(paste("ERROR:  ",err))
      NULL
    })
    pred = l[[1]]
    
    m.p = mean(pred)
    cat("mean of prediction after =",m.p ,"\n")
  } else if ( st == 33 & it == 9 ) {
    cat("mean of prediction before =",mean(pred) ,"\n")
    pred = model.sub[grep(x = model.sub$id , pattern = paste("^",st,"_",it,"_",sep='') ), ]$units
    cat("mean of prediction after =",mean(pred) ,"\n")
  } else if ( st == 17 & it == 9 ) {
    cat("mean of prediction before =",mean(pred) ,"\n")
    cat("leaving ... \n")
  } else if ( st == 16 & it == 25 ) {
    cat("mean of prediction before =",mean(pred) ,"\n")
    cat("leaving ... \n")
  } else if ( st == 17 & it == 48 ) {
    cat("mean of prediction before =",mean(pred) ,"\n")
    pred[testdata.header$as.date > as.Date("2013-05-11", "%Y-%m-%d")] = 0 
    cat("mean of prediction after =",mean(pred) ,"\n")
  } else if ( st == 30 & it == 44 ) {
    cat("mean of prediction before =",mean(pred) ,"\n")
    cat("leaving ... \n")
  } else if ( st == 33 & it == 44 ) {
    cat("mean of prediction before =",mean(pred) ,"\n")
    cat("leaving ... \n")
  } else if ( st == 7 & it == 95 ) {
    cat("mean of prediction before =",mean(pred) ,"\n")
    pred[testdata.header$as.date < as.Date("2013-07-15", "%Y-%m-%d")] = 0 
    cat("mean of prediction after =",mean(pred) ,"\n")
  } else if ( st == 26 & it == 5 ) {
    cat("mean of prediction before =",mean(pred) ,"\n")
    cat("leaving ... \n")
  } 
  
  ###### Updating submission
  if (verbose) cat("Updating submission ... \n")
  pred = ifelse(pred >= 0, pred , 0 )
  id = sub[grep(x = sub$id , pattern = paste("^",st,"_",it,"_",sep='') ), ]$id
  sub[sub$id %in% id, ]$units = pred 
}

### perform some checks 
if (dim(sub)[1] != dim(sampleSubmission)[1]) 
  stop (paste("sampleSubmission has ",dim(sampleSubmission)[1]," vs sub that has ",dim(sub)[1]," rows!!"))

if ( sum(!(sub$id %in% sampleSubmission$id)) > 0 ) 
  stop("sub has some ids different from sampleSubmission ids !!")

if ( sum(!(sampleSubmission$id %in% sub$id)) > 0 ) 
  stop("sampleSubmission has some ids different from sub ids !!")

### storing on disk 
write.csv(sub,quote=FALSE, 
          file=paste(getBasePath("data"),"mySub_trend_adj.csv",sep='') ,
          row.names=FALSE)

cat("<<<<< submission correctly stored on disk >>>>>\n")



