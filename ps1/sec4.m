% Merger analysis
rng(8675309);  % seed for reproducibility
load('data/100_3.mat')
W = normrnd(0,1,3,1); % Need to change simulated data to include W & Z
Z = normrnd(0, 1, 3, 1);

% Pick parameters that we liked (Got them from our Latex file)
SIGMA = 1.313;
ALPHA = 0.693;
BETA = [4.664; 1.268; 1.100];
GAMMA = [1.602; 0.351; 0.346];

%% Predict new set of prices using estimated parameters
% Draw 500 consumers
nu = lognrnd(0, 1, 100, 500);

ns = 10; % Repeat ns times to get bootstrapped std. err.
all_prices = zeros(3,100,ns);
p_all_prices = zeros(3,100,ns);

% Solve for prices that solve the first order conditions
% Compute Marginal costs
MC = 0.2 * exp([ones(3,1), W, Z] * GAMMA);

% Values for optimization
P0 = [1;1;1];
options = optimoptions('fsolve', 'Display', 'off','MaxIter', 1e3, 'MaxFunEvals',1e3);

% Bootstrap process:
%   1. sample 500 individuals with replacement
%   2. with simulated sample, calculate prices
%   3. store prices, repeat.
temp = zeros(ns*100,1);
temp_prices = zeros(3,500);
for nsim = 1:ns
    % 1. Sample 500 individuals with replacement
    nu_btsp = datasample(nu,500,2);
    merger_prices = zeros(3,100); % Empty matrix for storing price data
    pre_prices = zeros(3,100);
    
    % 2.Solve FOC for each market separately
    for i=1:100
        X = prods((i-1)*3+1:i*3,:);
        XI = xi((i-1)*3+1:i*3,:);
        NU = nu_btsp(i,:);

        % Merged firm's first order conditions
        firmobj = @(P) merger_foc(P,MC,X,BETA,ALPHA,XI,NU,SIGMA,true);
        [P, fval, exitflag] = fsolve(firmobj, P0, options);
        temp(nsim*i) = exitflag;
        iters = 0;
        while sum(P<0)>0 && iters < 1e3
            iters = iters + 1;
            % When firm prices are negative, bad starting values
            [P, fval, exitflag] = fsolve(firmobj, unifrnd(0,10,3,1), options);
        end
        if iters >= 1e3
            disp([nsim, i, P']);
        end
        merger_prices(:,i) = P;
        
        % Unmerged firm's first order conditions
        firmobj = @(P) merger_foc(P,MC,X,BETA,ALPHA,XI,NU,SIGMA,false);
        [P, fval] = fsolve(firmobj, P0, options);
        while sum(P<0)>0 && iters < 1e3
            iters = iters + 1;
            % When firm prices are negative, bad starting values
            [P, fval, exitflag] = fsolve(firmobj, unifrnd(0,10,3,1), options);
        end
        pre_prices(:,i) = P;
    end
    
    % 3. Store prices
    all_prices(:,:,nsim) = merger_prices;
    p_all_prices(:,:,nsim) = pre_prices;
    disp(nsim)
end
tabulate(temp)
sum(sum(sum(all_prices<0)))

% Calculate standard errors 
avg_prices = mean(mean(all_prices,2),3);
std_err = std(reshape(all_prices,3,[]),0,2);
p_avg_prices = mean(mean(p_all_prices,2),3);
p_std_err = std(reshape(p_all_prices,3,[]),0,2);

% Display results
table(num2str(p_avg_prices,'%3.4f &'),num2str(p_std_err,'%3.4f &'),...
    num2str(avg_prices,'%3.4f &'),num2str(std_err,'%3.4f \\\\'),...
    'RowNames',{'P1 &','P2 &','P3 &'}, ...
    'VariableNames',{'PreMean','PreSE','Mean','SE'})

% Calculate markups
post_mkup = (avg_prices-MC)./avg_prices;
pre_mkup = (p_avg_prices-MC)./p_avg_prices;
increase = (post_mkup./pre_mkup)-1;

% Display results
table(num2str(pre_mkup,'%3.4f &'),num2str(post_mkup,'%3.4f &'),...
    num2str(increase,'%3.4f \\\\'),...
    'RowNames',{'Firm 1 &','Firm 2 &','Firm 3 &'}, ...
    'VariableNames',{'Before','After','Increase'})

% Changes in profits
post_profits = (avg_prices-MC) .* mean(reshape(shares,3,[]),2) * 500;
pre_profits = (p_avg_prices-MC) .* mean(reshape(shares,3,[]),2) * 500;
increase_pi = (post_profits./pre_profits)-1;

% Display results
table(num2str(pre_profits,'%3.4f &'),num2str(post_profits,'%3.4f &'),...
    num2str(increase_pi,'%3.4f \\\\'),...
    'RowNames',{'Firm 1 &','Firm 2 &','Firm 3 &'}, ...
    'VariableNames',{'Before','After','Increase'})

% Consumer surplus for the average consumer
pre_cs = X*BETA - (ALPHA + SIGMA*0.5)*p_avg_prices;
post_cs = X*BETA - (ALPHA + SIGMA*0.5)*avg_prices;
increase_cs = (post_cs./pre_cs)-1;

% Display results
table(num2str(pre_cs,'%3.4f &'),num2str(post_cs,'%3.4f &'),...
    num2str(increase_cs,'%3.4f \\\\'),...
    'RowNames',{'Firm 1 &','Firm 2 &','Firm 3 &'}, ...
    'VariableNames',{'Before','After','Increase'})
