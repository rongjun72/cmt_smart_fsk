classdef FIRDecimatorBypass < matlab.System
    % FIRDecimatorBypass
    % 封装dsp.FIRDecimator，M=1直通零延迟，M>1正常FIR抽取
    % 支持两种创建方式：
    % 1. 快速传系数：FIRDecimatorBypass(M, b_coeff)
    % 2. 属性配置：FIRDecimatorBypass('DecimationFactor',4,'NumTaps',64)

    properties
        DecimationFactor = 8
        NumTaps          = 64
        PassbandFraction = 0.4
        StopbandAttenuation = 60
        Numerator = [] % 外部自定义FIR抽头，非空优先使用
    end

    properties (Access = private)
        firObj
    end

    methods
        % 重载构造函数
        function obj = FIRDecimatorBypass(varargin)
            if nargin == 2 && isnumeric(varargin{1}) && isnumeric(varargin{2})
                obj.DecimationFactor = varargin{1};
                obj.Numerator = varargin{2};
            else
                setProperties(obj, nargin, varargin{:});
            end
        end

        % 计算标量群时延（修复：不读取firObj.GroupDelay，改用b系数计算）
        function tau = grpDelay(obj)
            M = obj.DecimationFactor;
            if M == 1
                tau = 0;
            else
                % 先获取滤波器系数
                [b,~] = obj.tf();
                % 线性相位FIR群延迟 = (阶数)/2 = (抽头数-1)/2
                tau = (length(b) - 1) / 2;
            end
        end

        % 输出[b,a]供grpdelay使用
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
                    % 外部传入滤波器抽头
                    obj.firObj = dsp.FIRDecimator(M, obj.Numerator);
                else
                    % 自动设计FIR抽取滤波器
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