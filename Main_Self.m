clear;close all;clc;j=1i;
Global_Parameters;
%% TX signal load
load('Picture_all.mat');
%% Button setting
figure('Name','TX','NumberTitle','off');
button = uicontrol; % Generate GUI button
set(button,'String','Stop !','Position',[700 15 100 60]); % Add "Stop !" text
%% TRX Main
state=1; % status Start
Ready_Time=3;
Run_time_number=1;
index = 1;
%% New Add
IP = '192.168.3.7';
txWaveform = Picture_all(1).txdata2;
[s,input] = iio_Hardware_setting(IP,txWaveform,CenterFrequency,rmc);

while(state==1)
    try
        if index > 10
            index = 1;
        end
        txWaveform = Picture_all(index).txdata;
        input{1} = real(txWaveform);
        input{2} = imag(txWaveform);
        output = cell(1, s.out_ch_no + length(s.iio_dev_cfg.mon_ch));
        output = stepImpl(s, input);
        rssi = output{s.getOutChannel('RX1_RSSI')};
        if Run_time_number>Ready_Time
            rxWaveform = double(output{1}+j*output{2})*(2^-15);
            OFDM_RX(rxWaveform,rmc,rssi);
        end

        if Run_time_number<=Ready_Time  % Ready
            disp('Ready');
        end
        Run_time_number=Run_time_number+1;

        % ----- Button Behavior -----%
        set(button,'Callback','setstate0'); % Set the reaction of pushing button
        index = index + 1;
    
    catch
        ErrorMessage=lasterr;
        fprintf('Error Message : \n');
        disp(ErrorMessage);
        fprintf(2,'Error occurred & Stop Hardware\n');
        
        % Error handling
        % release(rx_object);
        % state=0;

    end % try Loop
end % While

s.releaseImpl();
close all;
disp('Software Complete');