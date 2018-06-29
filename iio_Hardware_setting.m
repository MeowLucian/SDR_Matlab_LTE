function [s,input] = iio_Hardware_setting(IP,txWaveform,CenterFrequency,rmc)
    s = iio_sys_obj_matlab; % Hardware Parameter object
    s.ip_address = IP; % Direct Connect IP
    s.dev_name = 'ad9361';
    s.in_ch_no = 2;     % 2 for I and Q input Channel (1st Antenna)
    s.out_ch_no = 2;    % 2 for I and Q output Channel (1st Antenna)
    s.in_ch_size = length(txWaveform);
    s.out_ch_size = length(txWaveform)*2;
    s = s.setupImpl();
    fir_data_file = 'LTE10_MHz.ftr';
    s.writeFirData(fir_data_file); % Configure the FIR filter
    input = cell(1, s.in_ch_no + length(s.iio_dev_cfg.cfg_ch));
    input{1} = real(txWaveform);                                    % input I channel (1st Antenna)
    input{2} = imag(txWaveform);                                    % input Q channel (1st Antenna)
    input{s.getInChannel('RX_LO_FREQ')} = CenterFrequency;          % Center frequency (1st Antenna)
    input{s.getInChannel('RX_SAMPLING_FREQ')} = rmc.SamplingRate;   % SamplingRate (1st Antenna)
    input{s.getInChannel('RX_RF_BANDWIDTH')} = 9e6;                 % RF Bandwidth (1st Antenna)
    input{s.getInChannel('RX1_GAIN_MODE')} = 'slow_attack';         % Auto Gain Control (1st Antenna)
    input{s.getInChannel('RX1_GAIN')} = 0;                          % Manual Gain Control (1st Antenna)
    input{s.getInChannel('RX2_GAIN_MODE')} = 'slow_attack';
    input{s.getInChannel('RX2_GAIN')} = 0;
    input{s.getInChannel('TX_LO_FREQ')} = CenterFrequency;
    input{s.getInChannel('TX_SAMPLING_FREQ')} = rmc.SamplingRate;
    input{s.getInChannel('TX_RF_BANDWIDTH')} = 9e6;
end