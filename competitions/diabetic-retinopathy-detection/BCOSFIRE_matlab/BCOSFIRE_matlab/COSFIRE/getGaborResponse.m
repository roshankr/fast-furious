function GaborBankOutput = getGaborResponse(img,params,lambdalist,thetalist)

[rows cols] = size(img);

nlambda = length(lambdalist);
ntheta = length(thetalist);

GaborBankOutput = zeros(rows,cols,ntheta,nlambda);
for lambda = 1:nlambda
    for theta = 1:ntheta
        GaborBankOutput(:,:,theta,lambda) = ...
            Gabor(img,lambdalist(lambda),...
            params.aspectratio,...
            params.bandwidth,...
            {thetalist(theta)},...
            params.phaseoffset,...
            params.halfwaverect,...
            [],...
            params.inhibition,...
            1,...
            params.thinning);
    end    
end
