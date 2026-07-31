classdef FIRDecimatorBypass < matlab.System
    % FIRDecimatorBypass
    % Wrap dsp.FIRDecimator, M=1 bypass zero delay, M>1 normal FIR decimation
    % Support two creation methods:
    % 1. Quick coefficient pass: FIRDecimatorBypass(M, b_coeff)
    % 2. Property configuration: FIRDecimatorBypass('DecimationFactor',4,'NumTaps',64)

    properties
        DecimationFactor = 8
        NumTaps          = 64
        PassbandFraction = 0.4
        StopbandAttenuation = 60
        Numerator = [] % External custom FIR taps, non-empty takes priority
    end

    properties (Access = private)
        firObj
    end

    methods
        % Override constructor
        function obj = FIRDecimatorBypass(varargin)
            if nargin == 2 && isnumeric(varargin{1}) && isnumeric(varargin{2})
                obj.DecimationFactor = varargin{1};
                obj.Numerator = varargin{2};
            else
                setProperties(obj, nargin, varargin{:});
            end
        end

        % Compute scalar group delay (fix: do not read firObj.GroupDelay, use b coefficients instead)
        function tau = grpDelay(obj)
            M = obj.DecimationFactor;
            if M == 1
                tau = 0;
            else
                % First get filter coefficients
                [b,~] = obj.tf();
                % Linear-phase FIR group delay = (order)/2 = (taps-1)/2
                tau = (length(b) - 1) / 2;
            end
        end

        % Output [b,a] for grpdelay use
        function [b,a] = tf(obj)
            M = obj.DecimationFactor;
            if M == 1
                b = 1;
                a = 1;
            else
                if isempty(obj.firObj)
                    obj.setupImpl([]);
                end
                [b,a] = tf(obj.firObj);
            end
        end
    end

    methods (Access = protected)
        function setupImpl(obj, ~)
            M = obj.DecimationFactor;
            if M > 1
                if ~isempty(obj.Numerator)
                    % External filter taps passed in
                    obj.firObj = dsp.FIRDecimator(M, obj.Numerator);
                else
                    % Auto-design FIR decimation filter
                    obj.firObj = dsp.FIRDecimator(...
                        'DecimationFactor', M, ...
                        'NumTaps', obj.NumTaps, ...
                        'PassbandFraction', obj.PassbandFraction, ...
                        'StopbandAttenuation', obj.StopbandAttenuation);
                end
            end
        end

        function y = stepImpl(obj, x)
            M = obj.DecimationFactor;
            if M == 1
                y = x;
            else
                y = obj.firObj(x);
            end
        end

        function outSize = getOutputSizeImpl(obj)
            inSize = getInputSizeImpl(obj);
            M = obj.DecimationFactor;
            if M == 1
                outSize = inSize;
            else
                outSize = [ceil(inSize(1)/M), inSize(2:end)];
            end
        end

        function dt = getOutputDataTypeImpl(obj)
            dt = getInputDataTypeImpl(obj);
        end

        function flag = isInputSizeMutableImpl(~,~)
            flag = true;
        end

        function resetImpl(obj)
            M = obj.DecimationFactor;
            if M > 1
                reset(obj.firObj);
            end
        end

        function releaseImpl(obj)
            M = obj.DecimationFactor;
            if M > 1
                release(obj.firObj);
            end
        end
    end
end