function [theta, vcov, fval] = blpdemand(prices, prods, shares, cost, ...
        prodcount, mktcount, usegrad)
    % BLP Estimation of model from BLP (1995)
    % Input arguments:
    %   prices = mXj by 1 vector of prices for each product-market combination
    %   prods  = mXj by 3 vector of product characteristics
    %   shares = mXj by 1 vector of market shares
    %   cost   =   j by 1 vector of firm-level marginal cost shifters
    %   prodcount = number of products
    %   mktcount  = number of markets
    %   usegrad   = true means use analytic gradient of objective function in
    %               optimization routine
    % Outputs:
    %   theta = [alpha; beta; sigma_alpha]
    %   fval = value of objective function evaluated at theta

    % construct matrix of BLP instruments
    Z = abs(eye(prodcount) - 1);   % matrix with 1 on off diagonal
    Z = repmat({Z}, mktcount, 1);  % selects other products in market
    Z = blkdiag(Z{:}) * prods;  % sum of other product characteristics
    % remove the first instrument, which does not vary across markets
    % because all markets have the same number of products.
    Z = Z(:, 2:3);

    % add marginal cost shifters to the instrument matrix
    cost = repmat(cost, mktcount, 1);
    % uncomment below to add the cost shifter
    %Z = [cost, Z];

    % this is the Nevo instrument
    totprice = repmat(eye(prodcount), 1, mktcount) * prices;
    avgprice = (1/(mktcount - 1))*(repmat(totprice, mktcount, 1) - prices);
    % uncomment below to add Nevo instrument
    %Z = [avgprice, Z];

    % find an initial value for delta using logit model
    share_mat = reshape(shares, prodcount, []);  % markets by products matrix
    out_share = 1 - sum(share_mat);  % share of outside option
    
    % Nevo menions setting delta0 to the one that solves the logit equation
    % log(s_jt) - log(s_0t);
    deltas = log(share_mat ./ repmat(out_share, 3, 1));
    deltas = reshape(deltas, 1, [])';
    % uncomment below to estimate the logit model
    %[coef, ~, ~] = logit(logit_shr, [prices, prods], [Z, prods]);
    
    % draw 500 consumers for each market, held constant over simulation
    nu = lognrnd(0, 1, mktcount, 500);
    nu = kron(nu, ones(prodcount, 1));  % replicate draws for each product

    % initial weighting matrix
    % TODO: Change weighting matrix at each iteration
    W = ([Z, prods]' * [Z, prods]) \ eye(size([Z, prods], 2));
    
    tolerance = 1e-12;
    estimator = @(s) gmmobj(s, deltas, prices, prods, Z, W, shares, nu, tolerance);
    options = optimset('Display', 'iter', 'TolFun', tolerance);
    if usegrad  % use the gradient info in optimization routine
        options = optimset(options, 'GradObj', 'on');
        % uncomment below to check derivative against finite difference
        %options = optimset(options, 'DerivativeCheck', 'on');
        [s, fval, grad] = fminunc(estimator, lognrnd(0,1), options);
    else
        [s, fval] = fminunc(estimator, lognrnd(0,1), options);
    end
    vcov = stderr(exp(s), prods, Z, W);

    function [fval, grad] = gmmobj(sigma, deltas, prices, X, Z, W, shares, nu, tolerance)
        % GMMOBJ Objective function for BLP random coefficients model
        % Input arguments:
        %   theta = model parameters [beta; alpha; sigma_alpha]
        %   deltas = initial mXj by 1 vector of values for delta
        %   prices = mXj by 1 vector of prices
        %   X = matrix of product characteristics
        %   Z = matrix of BLP instruments
        %   shares = mXj by 1 vector of market shares
        % Outputs:
        %   fval = value of the objective function
        %   grad = gradient for speedy computation
       
        % sigma must be a positive number
        sigma = exp(sigma);

        % create a simulator for market shares that can calculate shares for
        % different values of delta (the d variable); this is used to equate 
        % the observed shares with simulated shares and thereby find deltas.
        price_utility = sigma * bsxfun(@times, nu, prices);  % price disutility
        sharefunc = @(d) deltashares(d, price_utility, prodcount);
        
        % TODO: adjust tolerance based on change in objective function
        % find deltas using the share simulator
        deltas = innerloop(deltas, shares, sharefunc, tolerance);
        
        % make sure deltas are defined, otherwise set high objective value
        if any(isnan(deltas)) == 1
            fval = 10e6;  % avoid these regions
            return
        end

        % estimate non-random coefficients and unobservables
        [betas, xi] = ivreg(deltas, [prices, X], [Z, X], W);
    
        % compute value of the objective function
        fval = xi' * [Z, X] * W * [Z, X]' * xi;
        
        if nargout > 1
            % find the jacobian, then calculate gradient of objective function
            jac = jacob(deltas, sigma, prices, nu, prodcount, mktcount);
            grad = 2 * jac' * [Z, X] * W * [Z, X]' * xi;
        end
    
        % save latest parameter values
        theta = [betas; sigma];
    end

    function [V1] = stderr(deltas, sigma)
        % STDERR Calculate standard errors for BLP parameter estimates
        %   This code follows Nevo's example code.

        % derivative of share delta function with respect to sigma
        D = jacob(deltas, sigma, prices, nu, prodcount, mktcount);
        % calculate first portion of matrix
        IV = [Z, prods];  % full instrument matrix
        Q = [prods, D]' * IV;
        % calculate matrix that gets inverted
        B = inv(Q * W * Q');
        % calculate interaction of instrument matrix and residuals
        [betas, xi] = ivreg(deltas, [prices, prods], [Z, prods], W);
        S = IV .* (xi * ones(1, size(IV, 2)));
        % calculate V1 from BLP (1995)
        % TODO: is this V1, or full covariance matrix using just V1?
        V1 = B * Q * W * S' * S * W * Q' * B;
    end
end

