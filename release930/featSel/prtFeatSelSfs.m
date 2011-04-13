classdef prtFeatSelSfs < prtFeatSel
% prtFeatSelSfs   Sequential forward feature selection object.
%
%    FEATSEL = prtFeatSelSfs creates a sequental forward feature selection
%    object.
%
%    FEATSEL = prtFeatSelSfs(PROPERTY1, VALUE1, ...) constructs a
%    prttFeatSelSfs object FEATSEL with properties as specified by
%    PROPERTY/VALUE pair
%
%    A prtFeatSelSfsobject has the following properties:
%
%    nFeatures             - The number of features to be selected
%    showProgressBar       - Flag indicating whether or not to show the
%                            progress bar during feature selection.
%    evaluationMetric      - The metric to be used to determine which
%                            features are selected. evaluationMetric must
%                            be a function handle. The function handle must
%                            be in the form:
%                            @(dataSet)prtEval(prtClass, dataSet, varargin)
%                            where prtEvak is a prtEval function, prtClass
%                            is a prt classifier object, and varargin
%                            represents optional input arguments to a
%                            prtEval function.
%
%    peformance            - The performance obtained by the using the
%                            features selected.
%    selectedFeatures      - The indices of the features selected that gave
%                            the best performance.
%
%   A prtFeatSelExhaustive object inherits the TRAIN and RUN methods
%   from prtClass.
%
%   Example:
%
%   dataSet = prtDataGenFeatureSelection;         % Generate a data set
%   featSel = prtFeatSelSfs;          % Create a feature selction object
%   featSel.nFeatures = 3;            % Select only one feature of the data
%   featSel = featSel.train(dataSet); % Train the feature selection object
%   outDataSet = featSel.run(dataSet);% Extract the data set with only the
%                                     % selected features
%
%   %   Change the scoring function to prtScorePdAtPf, and change the
%   %   classification method to prtClassMAP
%
%   featSel.evaluationMetric = @(DS)prtEvalPdAtPf(prtClassMap, DS, .9);
%
%   featSel = featSel.train(dataSet);
%   outDataSet = featSel.run(dataSet);
%
 % See Also:  prtFeatSelStatic, prtFeatSelExhaustive
    
    properties (SetAccess=private)
        name = 'Sequentual Feature Selection' % Sequentual Feature Selection
        nameAbbreviation = 'SFS' % SFS
    end
    
    properties
        % General Classifier Properties
        nFeatures = 3;                    % The number of features to be selected
        showProgressBar = true;           % Whether or not the progress bar should be displayed
        evaluationMetric = @(DS)prtEvalAuc(prtClassFld,DS);   % The metric used to evaluate performance
    end
    
    properties (SetAccess = protected)
        performance = [];        % The evalutationMetric for the selected features
        selectedFeatures = [];   % The integer values of the selected features
    end
    
    
    methods
        function Obj = prtFeatSelSfs(varargin)
            Obj.isCrossValidateValid = false;
            Obj = prtUtilAssignStringValuePairs(Obj,varargin{:});
        end
        
        function Obj = set.nFeatures(Obj,val)
            if ~prtUtilIsPositiveScalarInteger(val);
                error('prt:prtFeatSelSfs','nFeatures must be a positive scalar integer.');
            end
            Obj.nFeatures = val;
        end
        
        function Obj = set.showProgressBar(Obj,val)
            if ~prtUtilIsLogicalScalar(val);
                error('prt:prtFeatSelSfs','showProgressBar must be a scalar logical.');
            end
            Obj.showProgressBar = val;
        end
        
        function Obj = set.evaluationMetric(Obj,val)
            assert(isa(val, 'function_handle') && nargin(val)>=1,'prt:prtFeatSelExhaustive','evaluationMetric must be a function handle that accepts one input argument.');
            Obj.evaluationMetric = val;
        end
        
    end
    methods (Access=protected,Hidden=true)
        
        function Obj = trainAction(Obj,DS)
            
            nFeatsTotal = DS.nFeatures;
            nSelectFeatures = min(nFeatsTotal,Obj.nFeatures);
            canceled = false;
            try
                Obj.performance = nan(1,nSelectFeatures);
                Obj.selectedFeatures = nan(1,nSelectFeatures);
                
                h = [];
                sfsSelectedFeatures = [];
                for j = 1:nSelectFeatures
                    
                    if j > 1
                        sfsSelectedFeatures = Obj.selectedFeatures(1:(j-1));
                    end
                    
                    if Obj.showProgressBar
                        h = prtUtilWaitbarWithCancel('SFS');
                    end
                    
                    availableFeatures = setdiff(1:nFeatsTotal,sfsSelectedFeatures);
                    cPerformance = nan(size(availableFeatures));
                    for i = 1:length(availableFeatures)
                        currentFeatureSet = cat(2,sfsSelectedFeatures,availableFeatures(i));
                        tempDataSet = DS.retainFeatures(currentFeatureSet);
                        
                        cPerformance(i) = Obj.evaluationMetric(tempDataSet);
                        
                        if Obj.showProgressBar
                            prtUtilWaitbarWithCancel(i/length(availableFeatures),h);
                        end
                        
                        if ~ishandle(h)
                            canceled = true;
                            break
                        end
                    end
                    
                    if Obj.showProgressBar && ~canceled
                        close(h);
                    end
                    
                    if canceled
                        break
                    end
                    
                    if all(~isfinite(cPerformance))
                        error('prt:prtFeatSelSfs','All evaluation matrics resulted in non-finite values. Check evalutionMetric');
                    end
                    
                    % Randomly choose the next feature if more than one provide the same performance
                    val = max(cPerformance);
                    newFeatInd = find(cPerformance == val);
                    newFeatInd = newFeatInd(max(1,ceil(rand*length(newFeatInd))));
                    
                    % In the (degenerate) case when rand==0, set the index to the first one
                    Obj.performance(j) = val;
                    Obj.selectedFeatures(j) = availableFeatures(newFeatInd);
                end
                
            catch ME
                if ~isempty(h) && ishandle(h)
                    close(h);
                end
                throw(ME);
            end
        end
        
        function DataSet = runAction(Obj,DataSet)
            if ~Obj.isTrained
                error('prt:prtFeatSelSfs','Attempt to run a prtFeatSel that is not trained');
            end
            DataSet = DataSet.retainFeatures(Obj.selectedFeatures);
        end
    end
end
