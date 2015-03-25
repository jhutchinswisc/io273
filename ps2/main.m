% Problem Set 2
% =============
% Do Yoon Kim, Chris Poliquin, David Zhang
% March 30, 2015

rng(8675309);
addpath('derivest')  % files from John D'Errico's DERIVEST suite

%% 2.2(1) Generate and save data for the entry game

[mrkts, costs, firms, entry] = sim_markets(3, 100);
save('data/entry.mat', 'mrkts', 'costs', 'firms', 'entry');
% create a histogram of simulation values
f = figure('PaperPosition', [.1, .2, 6.2, 3.5], 'PaperSize', [6.4, 4]);
subplot(1,3,1)
p1 = histogram(mrkts(:,2));
xlim([0 3])
title('Number of entrants')
hold on
subplot(1,3,2)
p2 = histogram(mrkts(:,3:end));
title('Realized profits')
subplot(1,3,3)
p3 = scatter(mrkts(:,2), mean(mrkts(:,3:end), 2));
xlabel('Number of entrants')
ylabel('Average profits')
title('Profits and Entrants')
saveas(f, 'figs/sim.pdf');


%% 2.2(2) Maximum likelihood estimation with correct model

% draw standard normals for the simulation estimator
[M, F] = size(firms);  % number of markets and potential entrants
draws = normrnd(0, 1, 100, M*F);

theta = [1, 1, 1];  % true, known alpha, beta, delta
options = optimset('Display', 'iter', 'TolFun', 10e-10);

% likelihood function with mu = x(1) and sigma = x(2)
like = @(x, ord) berry(mrkts, firms, entry, x(1), x(2), theta, draws, ord);
initial = [unifrnd(-1, 4), unifrnd(0, 3)];
sprintf('Starting estimation at mu = %f and sigma = %f', initial)

% estimation assuming entry in order of profitability 2.2(2a)
[x1, fval1] = fminsearch(@(x) -1 * like(x, 'ascend'), initial, options);
[hess1, ~] = hessian(@(x) -1 * like(x, 'ascend'), x1);
se1 = sqrt(diag(inv(hess1)));
sprintf('2.2(2a)\nmu = %f (%f)\nsigma = %f (%f)', x1(1), se1(1), x1(2), se1(2))

% estimation assuming entry in reverse order 2.2(2b)
[x2, fval2] = fminsearch(@(x) -1 * like(x, 'descend'), initial, options);
[hess2, ~] = hessian(@(x) -1 * like(x, 'descend'), x2);
se2 = sqrt(diag(inv(hess2)));
sprintf('2.2(2b)\nmu = %f (%f)\nsigma = %f (%f)', x2(1), se2(1), x2(2), se2(2))


%% 2.3 Estimate mean costs of entry using moment inequality estimator
% Subsampling strategy is wrong: need to draw from nCb combinations rather
% than a partition of the sample. Will fix.
NumSims = 100; % Number of simulations
theta = [1, 1, 1, 1];  % true, known alpha, beta, delta, sigma
% draw u
for i=1:NumSims
    u(:,:,i) = normrnd(0, theta(4), size(mrkts, 1), size(mrkts, 2) - 2);
end
% Find value of obj function at minimum
[~, fvalmu] = fminsearch(@(mu) moment_inequalities(theta, mu, mrkts, firms, entry, u), ...
                     unifrnd(-1, 4), options);
% Define c0 as the 1.25*fvalmu following Ciliberto-Tamer
c0 = 1.25*fvalmu;
% Find initial confidence region by evaluating the obj function in a grid
% of 50 points (from -1.0 to 4.0)
j=1;
for i = 1:50
    point(i,1) = moment_inequalities(theta, i/10-1, mrkts, firms, entry, u);
    if point(i,1)<=c0
        ci0(j) = i/10-1;
        j=j+1;
    end
end
ci0_lb = min(ci0);
ci0_ub = max(ci0);
% Generate subsamples with a subsample size of 4 following Ciliberto-Tamer
% Compute max value of the obj function of each subsample over initial 
% confidence region by finding the min of the negative obj function
for i=0:size(mrkts,1)/5-1
    lb = i*4+1;
    ub = i*4+4;
    [~, cf(i+1)] = fminbnd(@(mu) ...
        -moment_inequalities(theta, mu, mrkts(lb:ub,:), firms(lb:ub,:), entry(lb:ub,:), u(lb:ub,:,:)), ...
    ci0_lb, ci0_ub, options);
end
cf=-cf;
% Take the 95th percentile and set equal to c1 to compute 95% CI
c1 = quantile(cf,0.95);
% compute ci1
j=1;
for i = 1:50
    point(i,1) = moment_inequalities(theta, i/10-1, mrkts, firms, entry, u);
    if point(i,1)<=c1
        ci1(j) = i/10-1;
        j=j+1;
    end
end
ci1_lb = min(ci1);
ci1_ub = max(ci1);
sprintf('2.3\n lower bond = %f; upper bound = %f', ci1_lb, ci1_ub)
