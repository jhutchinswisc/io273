function [deltas] = innerloop(start_deltas, shares, sharefunc, tolerance, prodcount)
    %INNERLOOP Contraction mapping to solve non-linear system for delta
    %   Solve equation 6.8 from BLP (1995) to make the observed market shares
    %   similar to the estimated shares.
    % Input arguments:
    %   start_deltas = Vector of initial values of delta for each product
    %   shares = Vector of observed market shares for each product
    %   sharefunc = Function that calculates theoretical shares given deltas.
    %   tolerance = Tolerance for value of delta, should be small, like 2e-14
    % Output arguments:
    %   deltas = Values of delta found using the contraction map, with markets
    %            in rows and products in columns.
    iters = 0;
    old_deltas = start_deltas;
    while 1
        old_shares = reshape(mean(sharefunc(old_deltas),2),prodcount,[]);
        
        deltas = old_deltas + log(shares) - log(old_shares);
        % check if we have converged on values for delta
        if (max(abs(deltas(:) - old_deltas(:))) < tolerance)
            break
        end
        if (iters > 1e6)
            max(abs(deltas(:) - old_deltas(:)))
            deltas;
        end
        old_deltas = deltas;
        iters = iters + 1;
    end
end
