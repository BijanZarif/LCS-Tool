%% Input parameters
timespan = [100,130];
domain = [0,6;-34,-28];
resolutionX = 400;
[resolutionY,deltaX] = equal_resolution(domain,resolutionX);
resolution = [resolutionX,resolutionY];

%% Velocity definition
load('ocean_geostrophic_velocity.mat')
% Set velocity to zero at boundaries
vlon(:,[1,end],:) = 0;
vlon(:,:,[1,end]) = 0;
vlat(:,[1,end],:) = 0;
vlat(:,:,[1,end]) = 0;
interpMethod = 'spline';
vlon_interpolant = griddedInterpolant({time,lat,lon},vlon,interpMethod);
vlat_interpolant = griddedInterpolant({time,lat,lon},vlat,interpMethod);
lDerivative = @(t,x,~)derivative(t,x,vlon_interpolant,vlat_interpolant);
incompressible = true;

%% LCS parameters
% Cauchy-Green strain
cgEigenvalueFromMainGrid = false;
cgAuxGridRelDelta = .01;

% Lambda-lines
poincareSection = struct('endPosition',{},'numPoints',{},'orbitMaxLength',{});
poincareSection(1).endPosition = [3.3,-32.1;3.7,-31.6];
poincareSection(2).endPosition = [1.3,-30.9;2.0,-31.2];
poincareSection(3).endPosition = [4.9,-29.6;5.7,-29.6];
poincareSection(4).endPosition = [4.9,-31.4;5.3,-31.4];
poincareSection(5).endPosition = [3.0,-29.3;3.5,-29.3];
[poincareSection.numPoints] = deal(100);
nPoincareSection = numel(poincareSection);
for i = 1:nPoincareSection
    rOrbit = hypot(diff(poincareSection(i).endPosition(:,1)),diff(poincareSection(i).endPosition(:,2)));
    poincareSection(i).orbitMaxLength = 4*(2*pi*rOrbit);
end
lambda = .9:.02:1.1;
lambdaLineOdeSolverOptions = odeset('relTol',1e-6,'initialStep',1e-2);
forceEtaComplexNaN = true;

% Strainlines
strainlineMaxLength = 20;
strainlineLocalMaxDistance = 2*deltaX;
strainlineOdeSolverOptions = odeset('relTol',1e-6);

% Stretchlines
stretchlineMaxLength = 20;
stretchlineLocalMaxDistance = 4*deltaX;
stretchlineOdeSolverOptions = odeset('relTol',1e-6);

% Graphics properties
repellingColor = 'r';
attractingColor = 'b';
ellipticColor = [0,.6,0];

hAxes = setup_figure(domain);
title(hAxes,'Repelling and elliptic LCSs')
xlabel(hAxes,'Longitude (\circ)')
ylabel(hAxes,'Latitude (\circ)')

%% Cauchy-Green strain eigenvalues and eigenvectors
[cgEigenvector,cgEigenvalue] = eig_cgStrain(lDerivative,domain,resolution,timespan,'incompressible',incompressible,'eigenvalueFromMainGrid',cgEigenvalueFromMainGrid,'auxGridRelDelta',cgAuxGridRelDelta);

%% Elliptic LCSs
[closedLambdaLinePos,closedLambdaLineNeg] = poincare_closed_orbit_range(domain,resolution,cgEigenvector,cgEigenvalue,lambda,poincareSection,'forceEtaComplexNaN',forceEtaComplexNaN,'lambdaLineOdeSolverOptions',lambdaLineOdeSolverOptions);

ellipticLcs = elliptic_lcs(closedLambdaLinePos);
ellipticLcs = [ellipticLcs,elliptic_lcs(closedLambdaLineNeg)];

% Plot elliptic LCSs
hEllipticLcs = plot_elliptic_lcs(hAxes,ellipticLcs);
set(hEllipticLcs,'color',ellipticColor)
set(hEllipticLcs,'linewidth',2)
drawnow

%% Hyperbolic repelling LCSs
strainlineLcs = seed_curves_from_lambda_max(strainlineLocalMaxDistance,strainlineMaxLength,cgEigenvalue(:,2),cgEigenvector(:,1:2),domain,resolution,'odeSolverOptions',strainlineOdeSolverOptions);

% Remove strainlines inside elliptic LCSs
for i = 1:nPoincareSection
    strainlineLcs = remove_strain_in_elliptic(strainlineLcs,ellipticLcs{i});
end

% Plot hyperbolic repelling LCSs
hStrainlineLcs = cellfun(@(position)plot(hAxes,position(:,1),position(:,2)),strainlineLcs,'UniformOutput',false);
hStrainlineLcs = [hStrainlineLcs{:}];
set(hStrainlineLcs,'color',repellingColor)

uistack(hEllipticLcs,'top')
drawnow

%% Hyperbolic attracting LCSs
hAxes = setup_figure(domain);
title(hAxes,'Attracting and elliptic LCSs')
xlabel(hAxes,'Longitude (\circ)')
ylabel(hAxes,'Latitude (\circ)')

% Copy objects from repelling LCS plot
hEllipticLcs = copyobj(hEllipticLcs,hAxes);
drawnow

% FIXME Part of calculations in seed_curves_from_lambda_max are
% unsuitable/unecessary for stretchlines do not follow ridges of λ₁
% minimums
stretchlineLcs = seed_curves_from_lambda_max(stretchlineLocalMaxDistance,stretchlineMaxLength,-cgEigenvalue(:,1),cgEigenvector(:,3:4),domain,resolution,'odeSolverOptions',stretchlineOdeSolverOptions);

% Remove stretchlines inside elliptic LCSs
for i = 1:nPoincareSection
    stretchlineLcs = remove_strain_in_elliptic(stretchlineLcs,ellipticLcs{i});
end

% Plot hyperbolic attracting LCSs
hStretchlineLcs = cellfun(@(position)plot(hAxes,position(:,1),position(:,2)),stretchlineLcs,'UniformOutput',false);
hStretchlineLcs = [hStretchlineLcs{:}];
set(hStretchlineLcs,'color',attractingColor)

uistack(hEllipticLcs,'top')
