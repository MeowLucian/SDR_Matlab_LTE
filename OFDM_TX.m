close all;clear;clc;
%% Input an image file and convert to binary stream
load('Picture_all.mat');
index = 1;
fData = Picture_all(index).data;      % Read image data from file
scale = 0.2;                      % Image scaling factor
origSize = size(fData);            % Original input image size
scaledSize = max(floor(scale.*origSize(1:2)),1); % Calculate new image size
heightIx = min(round(((1:scaledSize(1))-0.5)./scale+0.5),origSize(1));
widthIx = min(round(((1:scaledSize(2))-0.5)./scale+0.5),origSize(2));
fData = fData(heightIx,widthIx,:); % Resize image
imsize = size(fData);              % Store new image size
binData = dec2bin(fData(:),8);     % Convert to 8 bit unsigned binary
trData = reshape((binData-'0').',1,[]).'; % Create binary stream
%% Global Parameters
Global_Parameters;
%% Generate Baseband LTE Signal
% Pack the image data into a single LTE frame
[eNodeBOutput,txGrid] = lteRMCDLTool(rmc,trData);
[eNodeBOutput2,txGrid2] = lteRMCDLTool(rmc2,trData);
% Scale the signal for better power output.
powerScaleFactor = 0.7;
eNodeBOutput = eNodeBOutput.*(1/max(abs(eNodeBOutput))*powerScaleFactor);
eNodeBOutput2 = eNodeBOutput2.*(1/max(abs(eNodeBOutput2))*powerScaleFactor);
% Cast the transmit signal to int16
eNodeBOutput = int16(eNodeBOutput*2^15);
eNodeBOutput2 = int16(eNodeBOutput2*2^15);
%% Plot Ref Grid
% mesh(abs(txGrid));view(2);
% figure('Color','w');
% helperPlotTransmitResourceGrid(rmc,txGrid);
%% Save
% Picture_all(index).txdata = eNodeBOutput;
% Picture_all(index).txdata2 = eNodeBOutput2;
% save Picture_all Picture_all
% rxWaveform = eNodeBOutput;