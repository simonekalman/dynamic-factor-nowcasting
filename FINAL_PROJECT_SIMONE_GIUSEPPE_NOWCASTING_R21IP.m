
%SCHEMA:
%CleanTable_DEFINITIVE
      %  down
%grafici livelli
 %       down
%trasformazioni economiche
 %       down
%NaN -> 99999
 %       down
%standard(indica)
 %       down
%index = osservato/missing
 %       down
%relleno(indica,va)
 %       down
%yv pronto per Kalman

%%PRE-PROCESSING DEI DATI

% TARGET  : Quarterly Real Final Sales to Private Domestic Purchasers
% CAP     : Core Capital Goods Shipments             (monthly, hard)
% RES     : Residential Construction Spending        (monthly, hard)
% PCE     : Personal Consumption Expenditures        (monthly, hard)
% PERMIT  : Building Permits                         (monthly, hard, leading)
%           PERMIT_t = gamma_PERMIT*(f_{t+2} + f_{t+1}) + e_PERMIT,t
% IP      : Industrial Production Index              (monthly, hard)
%
% Run 21+IP — best model by chi_TARGET criterion (Option 3 = 0.798)
% Observable order: CAP(1) RES(2) PCE(3) PERMIT(4) IP(5) TARGET(6)
% pnk=22, 26 parameters

%% ============================================================


%% ---- Global chart style ---------------
FN    = 'Arial';              % font — sans-serif standard
C1    = [0.09 0.23 0.42];    % deep navy       — factor / primary
C2    = [0.72 0.11 0.08];    % brick red        — GDP / observed
C3    = [0.18 0.52 0.30];    % forest green     — common component
C4    = [0.80 0.47 0.06];    % amber            — leads / forecast
C5    = [0.48 0.48 0.48];    % medium grey      — tertiary / f_{t+2}
CFILL = [0.85 0.91 0.96];    % ice blue         — uncertainty band
FS    = 10;                   % axis font size
FST   = 11;                   % title font size
LW    = 1.8;                  % primary line width
LWt   = 1.2;                  % secondary line width
GCLR  = [0.80 0.80 0.80];    % grid colour

% apply font defaults for this session
set(groot,'DefaultAxesFontName',FN,'DefaultTextFontName',FN, ...
          'DefaultAxesFontSize',FS)
% ---------------------------------------------------------------

% ============================================================
% STEP 0: INIZIALIZZAZIONE
% ============================================================

global yv filter n vfq capt pnk vector index ny H filterptt

va     = 1;      % varianza defi numeri casuali usati da relleno
vfq    = 1;    % deviazione standard dello shock del fattore (fissata)

pphi = 2;
nk   = pphi + 1;

% Vettore Mariano-Murasawa per aggregare crescita mensile → trimestrale
vector = [(1/3); (2/3); 1; (2/3); (1/3)];
load('CleanTable1_DEFINITIVE.mat')

% Se CleanTable1 è una timetable, trasformala in table
if istimetable(CleanTable1)
    Data = timetable2table(CleanTable1);
else
    Data = CleanTable1;
end

% Sistemo nome prima colonna
Data.Properties.VariableNames{1} = 'Date';

% Controllo formato Date
Data.Date = datetime(Data.Date);
Data.Date.Format = 'dd/MM/yyyy';

disp(head(Data))

%% ============================================================
% STEP 0B: CORREZIONE PCE
% ============================================================

% Alcuni valori PCE sono importati con scala 10x
% Esempio: 111780 invece di 11178

idxPCE = isfinite(Data.PCE) & Data.PCE > 30000;
Data.PCE(idxPCE) = Data.PCE(idxPCE) / 10;

fprintf('PCE corretto: min = %.2f, max = %.2f\n', ...
    min(Data.PCE,[],'omitnan'), max(Data.PCE,[],'omitnan'));




%% PERMIT from FRED
permit_raw = readtable('https://fred.stlouisfed.org/graph/fredgraph.csv?id=PERMIT');
permit_raw.Properties.VariableNames = {'Date','PERMIT'};
permit_raw.Date = datetime(permit_raw.Date,'InputFormat','yyyy-MM-dd');
[~,ia,ib] = intersect(Data.Date, permit_raw.Date);
permit_col = NaN(height(Data),1);
permit_col(ia) = permit_raw.PERMIT(ib);
Data.PERMIT = permit_col;
fprintf('PERMIT: %d obs  (%s - %s)\n', sum(isfinite(permit_col)), ...
    datestr(Data.Date(find(isfinite(permit_col),1,'first'))), ...
    datestr(Data.Date(find(isfinite(permit_col),1,'last'))))

%% IP from FRED
ip_raw = readtable('https://fred.stlouisfed.org/graph/fredgraph.csv?id=INDPRO');
ip_raw.Properties.VariableNames = {'Date','IP'};
ip_raw.Date = datetime(ip_raw.Date,'InputFormat','yyyy-MM-dd');
[~,ia2,ib2] = intersect(Data.Date, ip_raw.Date);
ip_col = NaN(height(Data),1);
ip_col(ia2) = ip_raw.IP(ib2);
Data.IP = ip_col;
fprintf('IP:     %d obs  (%s - %s)\n', sum(isfinite(ip_col)), ...
    datestr(Data.Date(find(isfinite(ip_col),1,'first'))), ...
    datestr(Data.Date(find(isfinite(ip_col),1,'last'))))


%% ============================================================
% STEP 1: DATA LEVELS — CHART
% ============================================================

vars       = {'CAP','RES','PCE','PERMIT','IP','TARGET'};
var_titles = {'Capital Goods Shipments (CAP)', ...
              'Residential Construction (RES)', ...
              'Personal Consumption (PCE)', ...
              'Building Permits (PERMIT)', ...
              'Industrial Production (IP)', ...
              'Real Final Sales (TARGET)'};

figure('Color','w','Position',[60 80 1080 620])
tl = tiledlayout(3,2,'TileSpacing','compact','Padding','tight');
title(tl,'Indicator Series — Levels','FontSize',FST+1,'FontWeight','bold','FontName',FN)

for i = 1:numel(vars)
    ax = nexttile(tl); hold(ax,'on')
    x  = Data.(vars{i}); ok = isfinite(x);
    plot(ax, Data.Date(ok), x(ok), 'Color',C1, 'LineWidth',LW)
    title(ax, var_titles{i}, 'FontSize',FS,'FontWeight','bold')
    fmt_ax(ax, GCLR, FN, FS)
    axis(ax,'tight')
    shade_covid(ax)
end
drawnow


%% ============================================================
% STEP 2: TRANSFORMATIONS  (100 x dlog)
% ============================================================

DataTrans = Data;
varsLog = {'CAP', 'RES','PCE','TARGET','PERMIT','IP'};
for i = 1:numel(varsLog)
    x    = DataTrans.(varsLog{i});
    tmp  = nan(size(x));
    ok   = ~isnan(x);
    tmp(ok) = [NaN; 100*diff(log(x(ok)))];
    DataTrans.(varsLog{i}) = tmp;
end


%% ============================================================
% STEP 3: GROWTH RATES — CHART
% ============================================================

figure('Color','w','Position',[60 80 1080 620])
tl = tiledlayout(3,2,'TileSpacing','compact','Padding','tight');
title(tl,'Indicator Series — Month-on-Month Growth Rates (%)','FontSize',FST+1,'FontWeight','bold','FontName',FN)

for i = 1:numel(vars)
    ax = nexttile(tl); hold(ax,'on')
    x  = DataTrans.(vars{i}); ok = isfinite(x);
    plot(ax, DataTrans.Date(ok), x(ok), 'Color',C1, 'LineWidth',LW)
    yline(ax, 0, 'Color',C5, 'LineStyle','-', 'LineWidth',0.7, 'HandleVisibility','off')
    title(ax, var_titles{i}, 'FontSize',FS,'FontWeight','bold')
    ylabel(ax,'%','FontSize',FS-1)
    fmt_ax(ax, GCLR, FN, FS)
    axis(ax,'tight')
    shade_covid(ax)
end
drawnow


%% ============================================================
% AUGMENTED DICKEY-FULLER
% ============================================================

adf_vars = {'CAP','RES','PCE','TARGET','PERMIT','IP'};
for kk = 1:numel(adf_vars)
    x = DataTrans.(adf_vars{kk}); x = x(isfinite(x));
    [h,pValue,stat] = adftest(x);
    fprintf('%s  H=%d  p=%.4f  ADF=%.4f\n', adf_vars{kk}, h, pValue, stat)
end


%% ============================================================
% STEP 4: Y MATRIX
% Observable order: CAP(1) RES(2) PCE(3) PERMIT(4) IP(5) TARGET(6)
% ============================================================

Y = DataTrans{:, {'CAP','RES','PCE','PERMIT','IP','TARGET'}};

idxCovid = DataTrans.Date >= datetime(2020,3,1) & ...
           DataTrans.Date <= datetime(2020,9,1);
fprintf('Covid observations set to missing: %d\n', sum(idxCovid))
Y(idxCovid,:) = NaN;


%% ============================================================
% STEPS 5-9: STANDARDISE / MISSING INDEX / RELLENO
% ============================================================

indica = Y;
indica(isnan(indica)) = 99999;
n  = size(indica,2);
ny = n;

mu_data  = zeros(1,n);
std_data = zeros(1,n);
for j = 1:n
    gg          = indica(indica(:,j) ~= 99999, j);
    mu_data(j)  = mean(gg);
    std_data(j) = std(gg,1);
end

indica  = standard(indica);
index   = (indica ~= 99999);
indica2 = relleno(indica, va);
yv      = indica2;
capt    = size(yv, 1);


%% ============================================================
% STEP 10: STATE DIMENSIONS  (pnk=22)
%
%   pos 1    f_{t+2}   <- PERMIT shared gamma
%   pos 2    f_{t+1}   <- PERMIT shared gamma
%   pos 3    f_t       <- CAP,RES,PCE,IP contemporaneous; TARGET MM starts
%   pos 4-7  f_{t-1}..f_{t-4}
%   pos 8-12   e_TARGET
%   pos 13-14  e_CAP
%   pos 15-16  e_RES
%   pos 17-18  e_PCE
%   pos 19-20  e_PERMIT
%   pos 21-22  e_IP
% ============================================================

pnk    = 22;
filter = zeros(capt, pnk);


%% ============================================================
%
%% ============================================================
% STEP 11: STARTING VALUES - MANUAL
%tot parameter 26
% ============================================================

% Parameters:
% z(1)      gamma_TARGET
% z(2)      gamma_CAP
% z(3)      gamma_RES
% z(4)      gamma_PCE
% z(5)      gamma_PERMIT
% z(6)      gamma_IP
% z(7-8)    factor AR(2)
% z(9-20)   idiosyncratic AR(2)
% z(21-26)  shock standard deviations

startval = [

    0.5     % gamma_TARGET

    0.5     % gamma_CAP
    0.5     % gamma_RES
    0.5     % gamma_PCE
    0.5     % gamma_PERMIT
    0.5     % gamma_IP

    0.6     % phi1 factor
    0.2     % phi2 factor

    0.3     % psi_TARGET_1
    0.1     % psi_TARGET_2

    0.3     % psi_CAP_1
    0.1     % psi_CAP_2

    0.3     % psi_RES_1
    0.1     % psi_RES_2

    0.3     % psi_PCE_1
    0.1     % psi_PCE_2

    0.3     % psi_PERMIT_1
    0.1     % psi_PERMIT_2

    0.3     % psi_IP_1
    0.1     % psi_IP_2

    0.5     % sigma_TARGET
    0.5     % sigma_CAP
    0.5     % sigma_RES
    0.5     % sigma_PCE
    0.5     % sigma_PERMIT
    0.5     % sigma_IP
];

nth = length(startval);
fprintf('Parameters: %d\n', nth)

%% ============================================================
% ESTIMATION
% ============================================================

options = optimset('Display','iter','TolFun',1e-8,'TolX',1e-8, ...
                   'MaxFunEvals',20000,'MaxIter',10000);

fprintf('\n=== ESTIMATION RUN 21+IP ===\n\n')
[x, ff, EXITFLAG, ~, GRAD, HESSIAN] = fminunc(@ofn_noSENT_R21IP, startval, options);
fprintf('\nExitFlag = %d\n', EXITFLAG)
fprintf('Negative log-likelihood = %.4f\n', ff)


%% ============================================================
% CRAMER-RAO STANDARD ERRORS
% ============================================================

cramerrao = inv(HESSIAN);
std_par   = sqrt(abs(diag(cramerrao)));

param_names = { ...
    'gamma_TARGET'; 'gamma_CAP'; 'gamma_RES'; 'gamma_PCE'; 'gamma_PERMIT'; 'gamma_IP'; ...
    'phi1'; 'phi2'; ...
    'psi_TARGET_1'; 'psi_TARGET_2'; ...
    'psi_CAP_1';    'psi_CAP_2'; ...
    'psi_RES_1';    'psi_RES_2'; ...
    'psi_PCE_1';    'psi_PCE_2'; ...
    'psi_PERMIT_1'; 'psi_PERMIT_2'; ...
    'psi_IP_1';     'psi_IP_2'; ...
    'sigma_TARGET'; 'sigma_CAP'; 'sigma_RES'; 'sigma_PCE'; 'sigma_PERMIT'; 'sigma_IP' ...
};

fprintf('\n%-20s  %10s  %10s  %10s\n','Parameter','Estimate','Std Err','t-stat')
for j = 1:nth
    fprintf('%-20s  %10.4f  %10.4f  %10.4f\n', ...
        param_names{j}, x(j), std_par(j), x(j)/std_par(j))
end


%% ============================================================
% RECONSTRUCT MATRICES AND FILTER
% ============================================================

[Rs, Qs, Hs, Fs] = matrices4_noSENT_R21IP(x);
filter = zeros(capt, pnk);
ofn_noSENT_R21IP(x);


%% ============================================================
% FITTED VALUES
% ============================================================

forecast_mat = zeros(6, capt);
for i = 1:capt
    forecast_mat(:,i) = Hs * filter(i,:)';
end
forecast2  = forecast_mat';
target_hat = forecast2(:,6)*std_data(6) + mu_data(6);


%% ============================================================
% COMMON COMPONENT OF TARGET: chi_{TARGET,t}
%
%   chi_{TARGET,t} = lambda * [1/3 f_t + 2/3 f_{t-1} + f_{t-2}
%                              + 2/3 f_{t-3} + 1/3 f_{t-4}]
%   = H_star(6,:) * h_{t|t}
%   where H_star zeroes the idiosyncratic columns 8:12
% ============================================================

H2 = Hs;
H2(6,8:12) = 0;

fc_common = zeros(6, capt);
for i = 1:capt
    fc_common(:,i) = H2 * filter(i,:)';
end
target_common_std2 = fc_common(6,:)';
target_common      = target_common_std2*std_data(6) + mu_data(6);

target_obs = DataTrans.TARGET;
idx_fin    = isfinite(target_obs);


%% ============================================================
% UNCERTAINTY BAND  (f_t = state position 3)
% ============================================================

[R_unc, Q_unc, H_unc, F_unc] = matrices4_noSENT_R21IP(x);
beta00_unc = zeros(pnk,1);
P00_unc    = eye(pnk);
factor_unc = zeros(capt,1);
factor_var = zeros(capt,1);

for it = 1:capt
    Hit    = bsxfun(@times, index(it,:)', H_unc);
    Rit    = diag(bsxfun(@times, (1-index(it,:)), R_unc));
    beta10 = F_unc * beta00_unc;
    P10    = F_unc * P00_unc * F_unc' + Q_unc;
    n10    = yv(it,:)' - Hit * beta10;
    F10    = Hit * P10 * Hit' + Rit;
    K      = P10 * (Hit' / F10);
    beta11 = beta10 + K * n10;
    P11    = P10   - K * Hit * P10;
    factor_unc(it) = beta11(3);
    factor_var(it) = P11(3,3);
    beta00_unc = beta11;
    P00_unc    = P11;
end

factor_se = sqrt(factor_var);
upper_95  = factor_unc + 1.96*factor_se;
lower_95  = factor_unc - 1.96*factor_se;


%% ============================================================
% SELECTION METRICS
% ============================================================

q_idx     = index(:,6);
cc1       = corrcoef(filter(q_idx,3), yv(q_idx,6));
corr_opt1 = cc1(1,2);

target_chi_std = zeros(capt,1);
for t = 1:capt
    target_chi_std(t) = H2(6,:) * filter(t,:)';
end
cc3       = corrcoef(target_chi_std(q_idx), yv(q_idx,6));
corr_opt3 = cc3(1,2);

fprintf('\n=== SELECTION METRICS ===\n')
fprintf('Option 1  Corr(f_t, TARGET)         = %.4f\n', corr_opt1)
fprintf('Option 3  Corr(chi_TARGET, TARGET)  = %.4f\n', corr_opt3)
fprintf('R2(f_t, TARGET)                      = %.4f\n', corr_opt1^2)

rho_ft_full = corrcoef(filter(idx_fin,3), DataTrans.TARGET(idx_fin));
fprintf('Corr(f_t, TARGET) full sample        = %.4f\n', rho_ft_full(1,2))

dates_q   = DataTrans.Date(q_idx);
tgt_q_std = yv(:,6);


%% FIGURE: factor vs TARGET at quarterly TARGET dates only

target_obs = DataTrans.TARGET;
idx_q = isfinite(target_obs);

factor_q = filter(idx_q,3);      % f_t only when TARGET is observed
target_q = target_obs(idx_q);
dates_q  = DataTrans.Date(idx_q);

% Standardise both series on the same quarterly sample
factor_q_std = (factor_q - mean(factor_q,'omitnan')) ./ std(factor_q,'omitnan');
target_q_std = (target_q - mean(target_q,'omitnan')) ./ std(target_q,'omitnan');

rho = corr(factor_q_std, target_q_std, 'Rows','complete');

figure('Color','w','Position',[80 80 1100 420])
plot(dates_q, factor_q_std, 'LineWidth', 1.7, 'DisplayName','Common factor f_t')
hold on
plot(dates_q, target_q_std, 'LineWidth', 1.7, 'DisplayName','Real Final Sales (std, quarterly)')
yline(0,'k-','LineWidth',0.6,'HandleVisibility','off')

ylabel('Standardised units')
legend('Location','southwest')
grid on
xlim([dates_q(1) dates_q(end)])


%% ============================================================
% FIGURE 2 — COMMON FACTOR WITH 95% CONFIDENCE BAND
% ============================================================

figure('Color','w','Position',[80 80 1100 380])
ax2 = axes; hold(ax2,'on')

fill(ax2,[DataTrans.Date; flipud(DataTrans.Date)], ...
     [upper_95; flipud(lower_95)], CFILL, ...
     'EdgeColor','none','FaceAlpha',0.70,'DisplayName','95% confidence band')
plot(ax2, DataTrans.Date, factor_unc, ...
    'Color',C1,'LineWidth',LW,'DisplayName','Common Factor  f_t')
yline(ax2,0,'Color',C5,'LineStyle','-','LineWidth',0.6,'HandleVisibility','off')
shade_covid(ax2)

lg = legend(ax2,'FontSize',FS,'Location','southwest'); lg.Box='off';
title(ax2,'Common Factor — Kalman Filter Estimate with 95% Confidence Band', ...
    'FontSize',FST,'FontWeight','bold')
ylabel(ax2,'Standardised units','FontSize',FS)
fmt_ax(ax2, GCLR, FN, FS)
xlim(ax2,[DataTrans.Date(1) DataTrans.Date(end)])
drawnow


%% ============================================================
% FIGURE 3 — FACTOR CURRENT AND LEADING VALUES
% ============================================================

figure('Color','w','Position',[80 80 1100 380])
ax3 = axes; hold(ax3,'on')

plot(ax3, DataTrans.Date, filter(:,3), ...
    'Color',C1,'LineWidth',LW,'DisplayName','f_t  (contemporaneous)')
plot(ax3, DataTrans.Date, filter(:,2), ...
    'Color',C4,'LineWidth',LWt,'LineStyle','--','DisplayName','f_{t+1}  (1-month lead)')
plot(ax3, DataTrans.Date, filter(:,1), ...
    'Color',C5,'LineWidth',LWt,'LineStyle',':','DisplayName','f_{t+2}  (2-month lead, PERMIT)')
yline(ax3,0,'Color',C5,'LineStyle','-','LineWidth',0.6,'HandleVisibility','off')
shade_covid(ax3)

lg = legend(ax3,'FontSize',FS,'Location','southwest'); lg.Box='off';
title(ax3,'Common Factor — Current and Leading Values','FontSize',FST,'FontWeight','bold')
ylabel(ax3,'Standardised units','FontSize',FS)
fmt_ax(ax3, GCLR, FN, FS)
xlim(ax3,[DataTrans.Date(1) DataTrans.Date(end)])
drawnow


%% ============================================================
% FIGURE 4 — IDIOSYNCRATIC COMPONENTS  (2x2 panel)
% ============================================================

idio_pos   = [13, 15, 17, 21];
idio_names = {'CAP','RES','PCE','IP'};
idio_clrs  = {C2, C3, C4, [0.35 0.18 0.55]};

figure('Color','w','Position',[80 80 1060 540])
tl4 = tiledlayout(2,2,'TileSpacing','compact','Padding','tight');
title(tl4,'Common Factor vs Idiosyncratic Components', ...
    'FontSize',FST,'FontWeight','bold','FontName',FN)

for k = 1:4
    ax = nexttile(tl4); hold(ax,'on')
    plot(ax, DataTrans.Date, filter(:,3), ...
        'Color',[C1 0.35],'LineWidth',LWt,'DisplayName','Common Factor')
    plot(ax, DataTrans.Date, filter(:,idio_pos(k)), ...
        'Color',idio_clrs{k},'LineWidth',LW,'DisplayName',['Idio. ' idio_names{k}])
    yline(ax,0,'Color',C5,'LineStyle','-','LineWidth',0.5,'HandleVisibility','off')
    shade_covid(ax)
    lg = legend(ax,'FontSize',FS-1,'Location','southwest'); lg.Box='off';
    title(ax, idio_names{k}, 'FontSize',FS,'FontWeight','bold')
    fmt_ax(ax, GCLR, FN, FS-1)
    xlim(ax,[DataTrans.Date(1) DataTrans.Date(end)])
end
drawnow


%% ============================================================
% FIGURE 5 — AUTOCORRELATION OF COMMON FACTOR
% ============================================================

autocorr(filter(:,3))
ax5 = gca; fig5 = gcf;
fig5.Color = 'w'; fig5.Position = [80 80 700 360];
ax5.FontName = FN; ax5.FontSize = FS;
ax5.GridAlpha = 0.15; ax5.GridColor = GCLR;
ax5.XGrid = 'on'; ax5.YGrid = 'on';
ax5.TickDir = 'out'; ax5.Box = 'off';
title(ax5,'Autocorrelation Function — Common Factor','FontSize',FST,'FontWeight','bold')
xlabel(ax5,'Lag (months)','FontSize',FS)
ylabel(ax5,'Autocorrelation','FontSize',FS)
drawnow


%% ============================================================
% FIGURE 6 — REAL FINAL SALES: OBSERVED vs COMMON COMPONENT
% ============================================================

figure('Color','w','Position',[80 80 1100 380])
ax6 = axes; hold(ax6,'on')

plot(ax6, DataTrans.Date(idx_fin), target_obs(idx_fin), ...
    'Color',C2,'LineWidth',LW,'DisplayName','Observed  (Real Final Sales)')
plot(ax6, DataTrans.Date(idx_fin), target_common(idx_fin), ...
    'Color',C3,'LineWidth',LW,'DisplayName','Common component  \chi_{TARGET}')
yline(ax6,0,'Color',C5,'LineStyle','-','LineWidth',0.6,'HandleVisibility','off')
shade_covid(ax6)

lg = legend(ax6,'FontSize',FS,'Location','southwest'); lg.Box='off';
title(ax6, sprintf('Real Final Sales — Observed vs Common Component  (Corr = %.3f)', corr_opt3), ...
    'FontSize',FST,'FontWeight','bold')
ylabel(ax6,'MoM growth rate (%)','FontSize',FS)
fmt_ax(ax6, GCLR, FN, FS)
xlim(ax6,[DataTrans.Date(1) DataTrans.Date(end)])
drawnow


%% ============================================================
% FIGURE 7 — SCATTER: COMMON FACTOR vs REAL FINAL SALES
% ============================================================

ft_obs    = filter(idx_fin,3);
tgt_obs_q = DataTrans.TARGET(idx_fin);
p_ols     = polyfit(ft_obs, tgt_obs_q, 1);
ft_rng    = linspace(min(ft_obs), max(ft_obs), 200);

figure('Color','w','Position',[80 80 540 500])
ax7 = axes; hold(ax7,'on')

scatter(ax7, ft_obs, tgt_obs_q, 36, C1, 'filled', 'MarkerFaceAlpha',0.60)
plot(ax7, ft_rng, polyval(p_ols,ft_rng), '-', 'Color',C2, 'LineWidth',LW-0.3)
yline(ax7,0,'Color',C5,'LineStyle','-','LineWidth',0.5,'HandleVisibility','off')
xline(ax7,0,'Color',C5,'LineStyle','-','LineWidth',0.5,'HandleVisibility','off')

text(ax7, 0.05, 0.93, sprintf('\\rho = %.3f\nR^2 = %.3f', corr_opt1, corr_opt1^2), ...
    'Units','normalized','FontSize',FS,'FontName',FN,'FontWeight','bold', ...
    'BackgroundColor','w','EdgeColor',[0.85 0.85 0.85],'Margin',4)

title(ax7,'Common Factor vs Real Final Sales','FontSize',FST,'FontWeight','bold')
xlabel(ax7,'Common Factor  f_t  (standardised)','FontSize',FS)
ylabel(ax7,'Real Final Sales  MoM growth (%)','FontSize',FS)
fmt_ax(ax7, GCLR, FN, FS)
drawnow


%% ============================================================
% PCA  (variance decomposition)
% ============================================================

X_all = DataTrans{:, {'CAP','RES','PCE','PERMIT','IP','TARGET'}};

idx_complete = all(isfinite(X_all),2);

X_all = X_all(idx_complete,:);

% Normalizzazione: demean and standardise each variable

X_norm = (X_all - mean(X_all)) ./ std(X_all);

[T_pca,N_pca] = size(X_norm);

% Covariance matrix and eigendecomposition

var_cov = (X_norm' * X_norm) / (T_pca - 1);

[Evectors,Evalues] = eig(var_cov);

% eig() does not guarantee ordering, so we sort descending

eigenvalues = diag(Evalues);

[eigenvalues_sorted,idx] = sort(eigenvalues,'descend');

largest_eigenvalue  = eigenvalues_sorted(1);
largest_eigenvector = Evectors(:,idx(1));

% First principal component

principal_comp_1 = X_norm * largest_eigenvector;

factor_pca = principal_comp_1 / sqrt(largest_eigenvalue);

% Results

fprintf('\nPCA on selected variables:\n')
fprintf('Largest eigenvalue: %.4f\n', largest_eigenvalue)
fprintf('Share of variance explained by PC1: %.2f%%\n', ...
        100 * largest_eigenvalue / sum(eigenvalues))

fprintf('Cumulative variance explained:\n')
disp(100 * cumsum(eigenvalues_sorted) / sum(eigenvalues))

% Optional: compare PCA factor with DFM common component

rho_pca_dfm = corrcoef(factor_pca, target_chi_std(idx_complete));

fprintf('Corr(PC1, DFM common component) = %.4f\n', rho_pca_dfm(1,2))


%% ============================================================
% FIGURE 8 — PCA SCREE PLOT
% ============================================================

pct_var = 100 * eigenvalues_sorted / sum(eigenvalues_sorted);

figure('Color','w','Position',[80 80 600 380])
ax8L = axes; hold(ax8L,'on')

bar(ax8L, 1:6, pct_var, 0.55, 'FaceColor',C1, 'EdgeColor','none', 'FaceAlpha',0.85)

yyaxis(ax8L,'right')
plot(ax8L, 1:6, cumshare, 'o-', 'Color',C2, 'LineWidth',LW, ...
    'MarkerFaceColor',C2,'MarkerSize',5)
yline(ax8L, 80, 'Color',[0.6 0.6 0.6], 'LineStyle',':', 'LineWidth',0.8, 'HandleVisibility','off')
ylim(ax8L,[0 105])
ylabel(ax8L,'Cumulative variance (%)','FontSize',FS)
ax8L.YAxis(2).Color = C2;

yyaxis(ax8L,'left')
ylim(ax8L,[0 max(pct_var)*1.30])
ylabel(ax8L,'Individual variance (%)','FontSize',FS)
ax8L.YAxis(1).Color = C1;
xlabel(ax8L,'Principal component','FontSize',FS)
ax8L.XTick = 1:6;
fmt_ax(ax8L, GCLR, FN, FS)

title(ax8L, sprintf('PCA Scree — PC1 explains %.1f%% of variance', share_pc1), ...
    'FontSize',FST,'FontWeight','bold')
drawnow


%% ============================================================
% NOWCAST + FORECAST TARGET
% ============================================================

% Last observed TARGET
last_tgt_row  = find(isfinite(DataTrans.TARGET), 1, 'last');
last_tgt_date = DataTrans.Date(last_tgt_row);

% Last available monthly information
last_data_row  = height(DataTrans);
last_data_date = DataTrans.Date(end);

fprintf('\nLast observed TARGET : %s\n', datestr(last_tgt_date,'mmm-yyyy'))
fprintf('Last monthly data    : %s\n', datestr(last_data_date,'mmm-yyyy'))

%% ============================================================
% 1. NOWCAST TARGET INSIDE THE SAMPLE
%    TARGET missing, but monthly indicators available
% ============================================================

target_now_std = zeros(capt,1);

for t = 1:capt
    target_now_std(t) = Hs(6,:) * filter(t,:)';
end

% De-standardize TARGET
target_now = target_now_std * std_data(6) + mu_data(6);

% Missing TARGET after last observed TARGET and up to last dataset date
idx_nowcast = isnan(DataTrans.TARGET) & ...
              DataTrans.Date > last_tgt_date & ...
              DataTrans.Date <= last_data_date;

NowcastTable = table( ...
    DataTrans.Date(idx_nowcast), ...
    target_now(idx_nowcast), ...
    'VariableNames', {'Date','TARGET_nowcast'} );

fprintf('\n=== TARGET NOWCASTS: missing TARGET inside sample ===\n')
disp(NowcastTable)


%% ============================================================
% 2. PURE FORECAST AFTER LAST MONTHLY OBSERVATION
%    Start from filter(end,:), not from last TARGET
% ============================================================

horizon = 9;   % 9 monthly steps = 3 quarters after Mar-2026

h_fore = filter(end,:)';

y_fore_std = zeros(horizon,6);

for s = 1:horizon
    h_fore = Fs * h_fore;
    y_fore_std(s,:) = Hs * h_fore;
end

% De-standardize all observables
y_fore = zeros(size(y_fore_std));

for j = 1:6
    y_fore(:,j) = y_fore_std(:,j) * std_data(j) + mu_data(j);
end

forecastDates = (last_data_date + calmonths(1:horizon))';

% Quarterly forecast rows: Jun-2026, Sep-2026, Dec-2026
q_fore_rows = 3:3:horizon;

ForecastTable = array2table(y_fore(q_fore_rows,:), ...
    'VariableNames', {'CAP','RES','PCE','PERMIT','IP','TARGET'} );

ForecastTable.Date = forecastDates(q_fore_rows);
ForecastTable = movevars(ForecastTable,'Date','Before',1);

fprintf('\n=== PURE TARGET FORECASTS: after last monthly data (%s) ===\n', ...
    datestr(last_data_date,'mmm-yyyy'))
disp(ForecastTable)


%% ============================================================
% 3. COMPACT TABLE FOR REPORT / SLIDES
% ============================================================

% Optional: keep only quarter-end nowcasts/forecasts
ReportNowcast = NowcastTable(month(NowcastTable.Date)==1 | ...
                             month(NowcastTable.Date)==4 | ...
                             month(NowcastTable.Date)==7 | ...
                             month(NowcastTable.Date)==10, :);

ReportForecast = ForecastTable(:, {'Date','TARGET'});

fprintf('\n=== REPORT TABLE: NOWCAST + FORECAST ===\n')
disp('Nowcasted missing TARGET:')
disp(ReportNowcast)

disp('Forecasted TARGET:')
disp(ReportForecast)

%% ============================================================
% FIGURE 9 — COMMON FACTOR: RECENT HISTORY AND 3-QUARTER NOWCAST
% ============================================================

cutDate    = last_tgt_date - calyears(5);
hist_ok    = DataTrans.Date >= cutDate & DataTrans.Date <= last_tgt_date;
dates_hist = DataTrans.Date(hist_ok);
ft_hist    = factor_unc(hist_ok);
up_hist    = upper_95(hist_ok);
lo_hist    = lower_95(hist_ok);

h_roll = filter(last_tgt_row,:)';
ft_fore_vals = zeros(horizon,1);
for s = 1:horizon
    h_roll = Fs * h_roll;
    ft_fore_vals(s) = h_roll(3);
end

all_fore_dates = [last_tgt_date; forecastDates];
all_fore_vals  = [factor_unc(last_tgt_row); ft_fore_vals];
q_dates        = forecastDates(q_fore_rows);
q_vals         = ft_fore_vals(q_fore_rows);

figure('Color','w','Position',[80 80 1100 400])
ax9 = axes; hold(ax9,'on')

fill(ax9,[dates_hist; flipud(dates_hist)],[up_hist; flipud(lo_hist)], CFILL, ...
    'EdgeColor','none','FaceAlpha',0.70,'DisplayName','95% confidence band')
plot(ax9, dates_hist, ft_hist, ...
    'Color',C1,'LineWidth',LW,'DisplayName','Common Factor  f_t')
plot(ax9, all_fore_dates, all_fore_vals, ...
    'Color',C4,'LineWidth',LW,'LineStyle','--','DisplayName','Monthly nowcast path')
scatter(ax9, q_dates, q_vals, 55, C2, 'filled', 'ZData',ones(3,1), ...
    'DisplayName','Quarterly nowcast')

plot(ax9, last_tgt_date, factor_unc(last_tgt_row), 'o', ...
    'Color',C1,'MarkerFaceColor',C1,'MarkerSize',6,'HandleVisibility','off')
xline(ax9, last_tgt_date, 'Color',[0.65 0.65 0.65],'LineStyle',':','LineWidth',1.0, ...
    'HandleVisibility','off')
yline(ax9,0,'Color',C5,'LineStyle','-','LineWidth',0.6,'HandleVisibility','off')
shade_covid(ax9)

lg = legend(ax9,'FontSize',FS,'Location','southwest'); lg.Box='off';
title(ax9, sprintf('Common Factor — Last 5 Years and 3-Quarter Nowcast  (anchor: %s)', ...
    datestr(last_tgt_date,'mmm-yyyy')), 'FontSize',FST,'FontWeight','bold')
ylabel(ax9,'Standardised units','FontSize',FS)
fmt_ax(ax9, GCLR, FN, FS)
drawnow


%% ============================================================
% SAVE OUTPUTS
% ============================================================

outdir = fullfile(fileparts(mfilename('fullpath')),'output','noSENT','R21IP_full');
if ~exist(outdir,'dir'), mkdir(outdir); end

metrics_tbl = table(ff, double(EXITFLAG), corr_opt1, corr_opt1^2, corr_opt3, ...
    share_pc1, rho_pca_dfm(1,2), ...
    'VariableNames',{'NegLogLik','ExitFlag','Corr_ft_TARGET','R2_ft_TARGET', ...
        'Corr_chi_TARGET','PC1_VarPct','Corr_PC1_chi'});
writetable(metrics_tbl, fullfile(outdir,'metrics.csv'));

params_tbl = table(param_names, x, std_par, x./std_par, ...
    'VariableNames',{'Parameter','Estimate','StdErr','tStat'});
writetable(params_tbl, fullfile(outdir,'parameters.csv'));

factor_table = table(DataTrans.Date, factor_unc, upper_95, lower_95, ...
    'VariableNames',{'Date','Factor','Upper95','Lower95'});
writetable(factor_table, fullfile(outdir,'factor_path.csv'));

writetable(ForecastTable, fullfile(outdir,'forecast.csv'));

target_fit_table = table(DataTrans.Date, target_obs, target_hat, target_common, ...
    'VariableNames',{'Date','TARGET_obs','TARGET_fitted','TARGET_chi'});
writetable(target_fit_table, fullfile(outdir,'target_fit.csv'));

figs = findall(0,'Type','figure'); figs = figs(isvalid(figs));
for k = 1:numel(figs)
    print(figs(k), fullfile(outdir,sprintf('fig_%02d.png',k)), '-dpng','-r150')
end

fprintf('\nSaved to: %s\n', outdir)
fprintf('\n=== RUN 21+IP COMPLETE ===\n')
fprintf('Option 1  Corr(f_t, TARGET)        = %.4f\n', corr_opt1)
fprintf('Option 3  Corr(chi, TARGET)         = %.4f\n', corr_opt3)
fprintf('Exit flag                           = %d\n',   EXITFLAG)
fprintf('Negative log-likelihood             = %.2f\n', ff)


%% ============================================================
% LOCAL FUNCTIONS
% ============================================================

function fmt_ax(ax, gclr, fn, fs)
    ax.FontName   = fn;
    ax.FontSize   = fs;
    ax.GridAlpha  = 0.15;
    ax.GridColor  = gclr;
    ax.XGrid      = 'on';
    ax.YGrid      = 'on';
    ax.TickDir    = 'out';
    ax.Box        = 'off';
    ax.LineWidth  = 0.8;
end

function shade_covid(ax)
    yl  = ylim(ax);
    cs  = datetime(2020,3,1);
    ce  = datetime(2020,9,1);
    ph  = patch(ax,[cs ce ce cs],[yl(1) yl(1) yl(2) yl(2)], ...
                [0.93 0.90 0.84],'EdgeColor','none','FaceAlpha',0.40, ...
                'HandleVisibility','off');
    uistack(ph,'bottom')
    ylim(ax,yl)
end
