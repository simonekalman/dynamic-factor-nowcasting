function [fun] = ofn_noSENT_R21IP(th)
% Objective function for Run 21 + IP spec.

global yv filter capt index pnk H

[R,Q,H,F] = matrices4_noSENT_R21IP(th);

beta00 = zeros(pnk,1);

P00 = eye(pnk);
A = eye(pnk^2) - kron(F,F);
if rcond(A) > 1e-12
    P0 = reshape(A \ Q(:), pnk, pnk);
    P0 = (P0 + P0')/2;
    if all(isfinite(P0(:))) && min(eig(P0)) > 0
        P00 = P0;
    end
end

like = zeros(capt,1);

it = 1;
while it <= capt

    beta10 = F * beta00;
    P10    = F * P00 * F' + Q;

    Hit = bsxfun(@times, index(it,:)', H);
    Rit = diag(bsxfun(@times, (1-index(it,:)), R));

    n10 = yv(it,:)' - Hit * beta10;
    F10 = Hit * P10 * Hit' + Rit;

    rc = rcond(F10);
    if ~isfinite(rc) || rc < 1e-10
        fun = 1e8;
        return;
    end

    like(it) = -0.5 * ( ...
        6 * log(2*pi) + ...
        log(det(F10)) + ...
        n10' * (F10 \ n10) ...
    );

    K = P10 * (Hit' / F10);

    beta11 = beta10 + K * n10;
    P11    = P10 - K * Hit * P10;

    filter(it,:) = beta11';

    beta00 = beta11;
    P00    = P11;
    it     = it + 1;

end

fun = -sum(like(20:end));

end
