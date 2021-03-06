
%% Load data

% These files are for an Antarctic wide PICO simulation

load Ua2D_Restartfile.mat;
load MeshBoundaryCoordinates.mat
load BasinsInterpolant.mat;

%% Run PICO:

% the PICO_opts structure can be defined by the user to change from default
% values (which are set in PICO_DefaultParameters)

PICO_opts = struct;
PICO_opts.algorithm = 'watershed';%'polygon','oneshelf';
PICO_opts.C1 = 1e6; 
PICO_opts.gamTstar = 2e-5;
PICO_opts.nmax = 5;
PICO_opts.minArea = 2e9;
PICO_opts.minNumShelf = 20;
PICO_opts.SmallShelfMelt = 0;
PICO_opts.PICOres = 10000; % resolution in km (for watershed algorithm only)
PICO_opts.BasinsInterpolant = Fbasins;
PICO_opts.FloatingCriteria = 'GLthreshold'; %'GLthreshold' or 'StrictDownstream'
PICO_opts.persistentBC = 0;
PICO_opts.InfoLevel = 0; % 0,1,10,100

% these two vectors are the salinity and temperature of each basin in the BasinsInterpolant file - provided by Ronja
PICO_opts.Sbasins = [34.6505;34.5273;34.3222;34.3259;34.3297;34.5315;34.4819;34.5666;34.5766;34.6677;34.7822;34.6254;34.4107;34.5526;34.6902;34.6668;34.5339;34.5849;34.6644];
PICO_opts.Tbasins = [-1.75725;-1.65931;-1.58212;-1.54757;-1.51301;-1.72267;-1.69117;-0.67609;-1.61561;-1.30789;-1.83764;-1.5798;-0.368398;0.45505;1.04046;1.17196;0.229878;-1.23091;-1.79334];

PICO_opts.MeshBoundaryCoordinates = MeshBoundaryCoordinates;

tic

[Mk,ShelfID,T0,S0,Tkm,Skm,q,PBOX,Ak] = PICO_driver(1,CtrlVarInRestartFile,MUA,GF,F.h,median(F.rho),F.rhow,PICO_opts);

toc
