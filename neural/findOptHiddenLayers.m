function [h_opt,J_opt] = findOptHiddenLayers(Xtrain, ytrain, Xval, yval , lambda=1)

  [m_train,n] = size(Xtrain);
  num_label = unique(ytrain);
  s1 = n-1;
  step = 1;
  hl = 3:step:30; 
  printf("|-> findOptHiddenLayers: detected %i features and %i classes ... \n",s1,length(num_label));
  printf("|-> findOptHiddenLayers: setting  %i  neurons per layers... \n",s1);
  printf("|-> findOptHiddenLayers: setting  hidden layers = %i,%i ... %i ... \n",min(hl),min(hl)+step,max(hl));
  
  error_train = zeros(length(hl), 1);
  error_val = zeros(length(hl), 1);

  %% Finding ...
  for i = 1:length(hl)
        
        NNMeta = buildNNMeta([s1; ones(i,1)*s1 ;num_label]); 
            
        [Theta] = trainNeuralNetwork(NNMeta, Xtrain, ytrain, lambda , iter = 60, featureScaled = 1);
	pred_train = NNPredictMulticlass(NNMeta, Theta , Xtrain , featureScaled = 1);
	pred_val = NNPredictMulticlass(NNMeta, Theta , Xval , featureScaled = 1);
	acc_train = mean(double(pred_train == ytrain)) * 100;
        acc_val = mean(double(pred_val == yval)) * 100;
        
        error_train(i) = 100 - acc_train;
        error_val(i)   = 100 - acc_val;
  endfor

  [J_opt, h_opt] = min(error_val); 
  
  fprintf('\tHidden Layers \tTrain Error\tCross Validation Error\n');
    for i = 1:length(s)
          fprintf('  \t%d\t\t%f\t%f\n', hl(i), error_train(i), error_val(i));
  endfor

  fprintf('Optimal Number of hidden layers s ==  %i , Minimum Cost == %f \n', h_opt , J_opt);

  %%plot 
  plot(hl, error_train, s, error_val);
  text(h_opt+1,J_opt+6,"Optimal Number of Hidden Layers","fontsize",10);
  line([h_opt,J_opt],[h_opt+1,J_opt+5],"linewidth",1);
  title(sprintf('Finding optimal number of Hidden Layers (lambda = %f , number of neurons per layer = %i)', lambda, s1));
  xlabel('Number of Neurons per Hidden Layer')
  ylabel('Error')
  max_X = max(s);
  max_Y = max(max(error_train) , max(error_val));
  axis([0 max_X 0 max_Y]);
  legend('Train', 'Cross Validation')

endfunction 