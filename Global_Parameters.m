%% Parameters
CenterFrequency = 2.4e9; % 2.4 GHz
%% Create RMC 1
rmc = lteRMCDL('R.7'); % Base RMC configuration, 10 MHz bandwidth
% Customize RMC parameters
rmc.NCellID = 88;      % Cell identity
rmc.NFrame = 700;      % Initial frame number
rmc.TotSubframes = 10; % 10 subframes per frame
rmc.CellRefP = 1;      % Configure number of cell reference ports
rmc.PDSCH.RVSeq = 0;
% Fill subframe 5 with dummy data
rmc.OCNGPDSCHEnable = 'On';
rmc.OCNGPDCCHEnable = 'On';
rmc.SerialCat = true;
rmc.SamplingRate = 15.36e6;
rmc.Nfft = 1024;
%% Create RMC 2
rmc2 = lteRMCDL('R.7'); % Base RMC configuration, 10 MHz bandwidth
% Customize RMC parameters
rmc2.NCellID = 0;      % Cell identity
rmc2.NFrame = 700;      % Initial frame number
rmc2.TotSubframes = 10; % 10 subframes per frame
rmc2.CellRefP = 1;      % Configure number of cell reference ports
rmc2.PDSCH.RVSeq = 0;
% Fill subframe 5 with dummy data
rmc2.OCNGPDSCHEnable = 'On';
rmc2.OCNGPDCCHEnable = 'On';
rmc2.SerialCat = true;
rmc2.SamplingRate = 15.36e6;
rmc2.Nfft = 1024;