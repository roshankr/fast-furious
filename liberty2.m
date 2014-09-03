#! /opt/local/bin/octave -qf 

%%%% setting enviroment 
menv;

trainFile = "train_nn.csv"; 
testFile = "test_nn.csv"; 

printf("|--> loading Xtrain, ytrain files ...\n");
train = dlmread([curr_dir "/dataset/liberty-mutual-fire-peril/" trainFile]); 
X_test = dlmread([curr_dir "/dataset/liberty-mutual-fire-peril/" testFile]); 

train = train(2:end,:); ## elimina le intestazioni del csv 
X_test = X_test(2:end,:);

y = train(:,1); ## la prima colonna e' target mentra l'ultima e' tragetPos che va scartata ...
X = train(:,2:(end-1));

clear train;



### cv ...
perc_train = 0.8;
[m,n] = size(X);
rand_indices = randperm(m);
[_Xtrain,ytrain,_Xval,yval] = splitTrainValidation(X(rand_indices,:),y(rand_indices,:),perc_train);

### feature scaling and cenering ...
[Xtrain,mu,sigma] = treatContFeatures(_Xtrain,1);
[Xval,mu,sigma] = treatContFeatures(_Xval,1,1,mu,sigma);

####### Linear Regression
printf("|--> finding optimal polinomial degree ... \n");
tic(); [p_opt,J_opt] = findOptP_RegLin(Xtrain, ytrain, Xval, yval , p_vec = [1 2 3 4 5 6 7 8 9 10]'); toc();
p = 1;
                                       
printf("|--> finding optimal regularization parameter ... \n");
tic(); [lambda_opt,J_opt] = findOptLambda_RegLin(Xtrain, ytrain, Xval, yval , lambda_vec = [0 0.001 0.003 0.01 0.03 0.1 0.3 1 3 10]' , p=1); toc();
lambda = 0;
                                                 
                                                 
[theta] = trainLinearReg(Xtrain, ytrain, 0 , 300 );
pred_val = predictLinearReg(Xval,theta);
pred_train =predictLinearReg(Xtrain,theta);
cost_val_gd1 = MSE(pred_val, yval);
cost_train_gd1 = MSE(pred_train, ytrain);
printf("MSE on training set = %f \n",cost_train_gd1);
printf("MSE on cross validation set = %f \n",cost_val_gd1);
                                                 
gini_train = NormalizedWeightedGini(ytrain,_Xtrain(:,20),pred_train);
printf("LR - NormalizedWeightedGini on train = %f \n", gini_train );
                                                 
gini_xval = NormalizedWeightedGini(yval,_Xval(:,20),pred_val);
printf("LR - NormalizedWeightedGini on cv = %f \n", gini_xval );
                                                 
####### Neural Networks 
[m,n] = size(Xtrain);
num_label = 1;
NNMeta = buildNNMeta([(n-1) (n-1) num_label]);disp(NNMeta);

[Theta] = trainNeuralNetworkReg(NNMeta, Xtrain, ytrain, 0 , iter = 300, featureScaled = 1 );

pred_train = NNPredictReg(NNMeta, Theta , Xtrain , featureScaled = 1);
pred_val = NNPredictReg(NNMeta, Theta , Xval , featureScaled = 1);
cost_val_gd1 = MSE(pred_val, yval);
cost_train_gd1 = MSE(pred_train, ytrain);
                                                 
printf("NN - MSE on training set = %f \n",cost_train_gd1);
printf("NN - MSE on cross validation set = %f \n",cost_val_gd1);
                                                 
gini_train = NormalizedWeightedGini(ytrain,_Xtrain(:,20),pred_train);
printf("NN - NormalizedWeightedGini on train = %f \n", gini_train );
                                                 
gini_xval = NormalizedWeightedGini(yval,_Xval(:,20),pred_val);
printf("NN - NormalizedWeightedGini on cv = %f \n", gini_xval );
                                                 
### NN EGS
num_label = 1;
NNMeta = buildNNMeta([(n-1) (n-1)  num_label]);disp(NNMeta);
[Theta] = trainNeuralNetworkRegEGS(NNMeta, Xtrain, ytrain, 0 , iter = 300, featureScaled = 1 );

pred_train = NNPredictRegEGS(NNMeta, Theta , Xtrain , featureScaled = 1);
pred_val = NNPredictRegEGS(NNMeta, Theta , Xval , featureScaled = 1);
cost_val_gd1 = MSE(pred_val, yval);
cost_train_gd1 = MSE(pred_train, ytrain);

printf("NN - MSE on training set = %f \n",cost_train_gd1);
printf("NN - MSE on cross validation set = %f \n",cost_val_gd1);

gini_train = NormalizedWeightedGini(ytrain,_Xtrain(:,20),pred_train);
printf("NN - NormalizedWeightedGini on train = %f \n", gini_train );

gini_xval = NormalizedWeightedGini(yval,_Xval(:,20),pred_val);
printf("NN - NormalizedWeightedGini on cv = %f \n", gini_xval );



