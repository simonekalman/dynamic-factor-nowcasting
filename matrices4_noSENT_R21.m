function [Rs,Qs,Hs,Fs]=matrices4_noSENT_R21(z)
% Run 21 spec: PERMIT loads on f_{t+1} AND f_{t+2} (shared gamma, 2-point distributed lead).
%
% Motivation: permits → starts (1-2 months) → value-put-in-place (3-8 months).
% The permit pipeline has uncertainty about whether the transmission lag is 1 or 2
% months. Loading on both f_{t+1} and f_{t+2} with shared gamma_permit spans
% that uncertainty, analogous to the SENT distributed window in practiceKF.pdf §3.
%
% Measurement equation for PERMIT:
%   PERMIT_t = gamma_permit * f_{t+2} + gamma_permit * f_{t+1} + e_PERMIT,t
%            = gamma_permit * (f_{t+2} + f_{t+1}) + e_PERMIT,t
%
% Observable order: CAP(1), RES(2), PCE(3), PERMIT(4), TARGET(5)
%
% State (pnk=20): identical to Run 20.
%   Factor block (7 states):
%    1: f_{t+2}   ← PERMIT loads here (and also on position 2)
%    2: f_{t+1}   ← PERMIT also loads here
%    3: f_t       ← CAP, RES, PCE load here; TARGET MM starts here
%    4: f_{t-1}
%    5: f_{t-2}
%    6: f_{t-3}
%    7: f_{t-4}   ← TARGET MM ends here
%   8-12: e_TARGET
%  13-14: e_CAP
%  15-16: e_RES
%  17-18: e_PCE
%  19-20: e_PERMIT
%
% Parameters (22, identical to Run 18 / Run 20):
%  z(1-5)   loadings: TARGET, CAP, RES, PCE, PERMIT
%  z(6-7)   phi: factor AR(2)
%  z(8-17)  AR idiosyncratic (5 variables x AR(2))
%  z(18-22) sigma (5 variables)

global vfq vector;

Rs = ones(1,5);
Hs = zeros(5,20);

lambda_TARGET = z(1);
lambda_CAP    = z(2);
lambda_RES    = z(3);
lambda_PCE    = z(4);
lambda_PERMIT = z(5);

% Contemporaneous → f_t = position 3
Hs(1,3)  = lambda_CAP;    Hs(1,13) = 1;
Hs(2,3)  = lambda_RES;    Hs(2,15) = 1;
Hs(3,3)  = lambda_PCE;    Hs(3,17) = 1;

% PERMIT: shared gamma on f_{t+2} (pos 1) AND f_{t+1} (pos 2)
Hs(4,1)  = lambda_PERMIT;
Hs(4,2)  = lambda_PERMIT;
Hs(4,19) = 1;

% TARGET MM: f_t...f_{t-4} = positions 3-7
Hs(5,3:7)  = lambda_TARGET * vector';
Hs(5,8:12) = vector';

% Transition (identical to Run 20)
Fs = zeros(20,20);

z0 = z(6:7);
z1 = z(8:9);
z2 = z(10:11);
z3 = z(12:13);
z4 = z(14:15);
z5 = z(16:17);

Fs(1,1) = z0(1); Fs(1,2) = z0(2);
Fs(2,1) = 1;
Fs(3,2) = 1;
Fs(4,3) = 1;
Fs(5,4) = 1;
Fs(6,5) = 1;
Fs(7,6) = 1;

Fs(8,8:9)=z1';   Fs(9,8)=1; Fs(10,9)=1; Fs(11,10)=1; Fs(12,11)=1;
Fs(13,13:14)=z2'; Fs(14,13)=1;
Fs(15,15:16)=z3'; Fs(16,15)=1;
Fs(17,17:18)=z4'; Fs(18,17)=1;
Fs(19,19:20)=z5'; Fs(20,19)=1;

q = zeros(20,1);
q(1)  = vfq;
q(8)  = z(18);
q(13) = z(19);
q(15) = z(20);
q(17) = z(21);
q(19) = z(22);

Qs = diag(q.^2);

end
