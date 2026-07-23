classdef CICDecimatorBypass < matlab.System
    % CICDecimatorBypass
    % DecimationFactor=1：直通 H(z)=1，群时延恒0
    % DecimationFactor>1：封装dsp.CICDecimator，通过公式计算群时延

    properties
        DecimationFactor = 8
        NumSections      = 5
        DifferentialDelay = 1
    end

    properties (Access = private)
        cicObj
    end

    methods
        function obj = CICDecimatorBypass(varargin)
            setProperties(obj, nargin, varargin{:});
        end

        % 标量群时延，改用公式计算，不读取cicObj.GroupDelay
        function tau = grpDelay(obj)
            R = obj.DecimationFactor;
            N = obj.NumSections;
            M = obj.DifferentialDelay;
            if R == 1
                tau = 0;
            else
                tau = (N * R * M - 1) / 2;
            end
        end

        % 输出[b,a]供grpdelay调用
        function [b,a] = tf(obj)
            R = obj.DecimationFactor;
            if R == 1
                b = 1;
                a = 1;
            else
                if isempty(obj.cicObj)
                    obj.setupImpl([]);
                end
                [b,a] = tf(obj.cicObj);
            end
        end
    end

    methods (Access = protected)
        function setupImpl(obj, ~)
            R = obj.DecimationFactor;
            if R > 1
                obj.cicObj = dsp.CICDecimator(...
                    'DecimationFactor', R, ...
                    'NumSections', obj.NumSections, ...
                    'DifferentialDelay', obj.DifferentialDelay);
            end
        end

        function y = stepImpl(obj, x)
            R = obj.DecimationFactor;
            if R == 1
                y = x;
            else
                y = obj.cicObj(x);
            end
        end

        function y = getOutputSizeImpl(obj)
            if obj.DecimationFactor == 1
                y = getInputSizeImpl(obj);
            else
                inSize = getInputSizeImpl(obj);
                y = [ceil(inSize(1)/obj.DecimationFactor), inSize(2:end)];
            end
        end

        function dt = getOutputDataTypeImpl(obj)
            dt = getInputDataTypeImpl(obj);
        end

        function flag = isInputSizeMutableImpl(~,~)
            flag = true;
        end

        function resetImpl(obj)
            if obj.DecimationFactor > 1
                reset(obj.cicObj);
            end
        end

        function releaseImpl(obj)
            if obj.DecimationFactor > 1
                release(obj.cicObj);
            end
        end
    end
end