function Sp = eaf_compare(AnnTrue, AnnTest, varargin)
%
%Sp = eaf_compare(AnnTrue, AnnTest [, option pairs])
%
% Perform annotation comparison between truth annotations and test annotations.
% AnnTrue and AnnTest are EMGlab annotation structures.  Each must contain
% the fields "time" (s) and "unit".  If AnnTrue also contains either of
% "datastart" or "datastop", these fields are also used.
%
% Structure "Sp" is used to hold all of the relevant spike information,
% with certain fields returned to the user and other fields used internally
% by this function.  All fields are described subsequently.  The fields
% returned to the user are: TEasn, Confuse, MUidTR, MUidTE and MUmap.
%
% Capitol letter code "TR" (within a field name) refers to truth spike information and
% capitol letter code "TE" refers to test spike information.  Structure fields:
%
% TRtim (TEtim): Vector of truth (test) spike firing times (s) of all MUs combined.
%     Set an element to NaN once accounted (e.g., paired and entered into Confuse).
% TRnum (TEnum): Corresponding spike numbers of unpaired spikes.
% TEasn: Test spikes assignment vector; same length as TEtim.  Element k gives INDEX
%     of paired spike firing within TRtim.  Set element to NaN to indicate no
%     pair.  Set vector to null to indicate a program error which
%     forced a premature return.
%
% Confuse: Confusion matrix (oriented as: truth spikes by test spikes).
%     One extra truth row for "Not Included".  One extra test column for "Not Found".
%     The k-th row in Confuse corresponds to the truth motor unit whose
%     number is held in the k-th element of MUidTR.  The m-th column in
%     Confuse corresponds to the test motor unit whose number is held in
%     the m-th element of MUidTE.
%
% MUidTR (MUidTE): Sorted (asending) column vector of all distinct MU numbers
%     occuring within TRnum (TEnum).
% MUmap: Vector, same length as MUidTE.  The k-th element in MUmap
%     lists the truth MU NUMBER corresponding to k-th element in MUidTE.
%     Unmapped test MUs are assigned NaN.
% MU_TRtim{k} (MU_TEtim{m}): Each cell element is a vector of truth (test) spike
%     firing times from only the k-th truth MU as indexed in MUidTR (m-th test
%     MU as indexed in MUidTE).  These vectors are extracted from
%     TRtim/TEtim.
%
% TT: Structure that holds various array results for truth (row index k) by test
%     (column index m) combinations from step 1.  Indeces k and m range over the
%     number of truth and test MU IDs, respectively.  Fields (all matrices) are:
%     Acc(k,m):    Accuracy (0-1).
%     Hits(k,m):   Number of true positives.
%     NF(k,m):     Number of unpaired (Not Found) truth annotations.
%     NI(k,m):     Number of unpaired (Not Included) test annotations.
%     Offset(k,m): Offset. Test time plus Offset gives truth time.
%
% StartTime: Start time of the corresponding data record (s).  If supplied
%     in AnnTrue, this value is loaded.  The AnnTrue value can be
%     overridden by option "StartTime".
% StopTime:  Stop  time of the corresponding data record (s).  If supplied
%     in AnnTrue, the value is loaded.  The AnnTrue value can be overridden
%     by option "StopTime".
% Win: Match window, in the same units as TRtim/TEtim.  Spikes <= this
%     distance away, offset adjusted, are "hits."
%
% Options:
% 'Compare' ['TruthTest'/'Agreement']: Comparison algorithm flag.
% 'Print' ['on'/'off']: Turns on or off printing of Confusion matrix.
% 'StartTime' value: Define start time of corresponding data record (s).
% 'StopTime' value: Define stop time of corresponding data record (s).
% 'Window' value: Set duration of the match window (s).
%
% Returned variables are as defined in the internal structure.
%
% Copyright (c) 2006. Edward A. Clancy, Kevin C. McGill and others.
% This work is licensed under the Aladdin free public license.
% For copying permissions see license.txt.
% email: emglab@emglab.stanford.edu

%%%%%%%%%% Process and perform some checks on command line arguments.
Sp.Confuse=[]; Sp.MUidTE=[]; Sp.MUidTR=[]; Sp.MUmap=[]; Sp.TEasn=[];  % Default.

Msg = 'Too few input arguments. ABORTED.';
if nargin < 2, errordlg(Msg, 'eaf_compare'); return; end
Sp.TRtim = AnnTrue.time;  Sp.TRnum = AnnTrue.unit;
Sp.TEtim = AnnTest.time;  Sp.TEnum = AnnTest.unit;
if isfield(AnnTrue, 'datastart'), Sp.StartTime = AnnTrue.datastart; end
if isfield(AnnTrue, 'datastop' ), Sp.StopTime  = AnnTrue.datastop;  end

Msg = 'No truth annotations. ABORTED.';
if isempty(Sp.TRtim), errordlg(Msg, 'eaf_compare'); return; end
Msg = 'Truth annotations not in time order. ABORTED.';
if any( diff(Sp.TRtim) < 0 ), errordlg(Msg, 'eaf_compare'); return; end
Msg = 'Truth times, IDs must be same length. ABORTED.';
if length(Sp.TRtim)~=length(Sp.TRnum), errordlg(Msg, 'eaf_compare'); return; end

Msg = 'No test annotations. ABORTED.';
if isempty(Sp.TEtim), errordlg(Msg, 'eaf_compare'); return; end
Msg = 'Test annotations not in time order. ABORTED.';
if any( diff(Sp.TEtim) < 0 ), errordlg(Msg, 'eaf_compare'); return; end
Msg = 'Test times, IDs must be same length. ABORTED.';
if length(Sp.TEtim)~=length(Sp.TEnum), errordlg(Msg, 'eaf_compare'); return; end

% Defaults.  Note: Start and stop time could be in AnnTrue.
Sp.Compare = 'truthtest'; % Comparison algorithm.
Print = 1;  % Default print to "on."
if ~isfield(Sp, 'StartTime')  % Test if already defaulted in AnnTrue.
  Sp.StartTime = 0;  if any(Sp.TRtim<0), Sp.StartTime = -Inf; end
end
if ~isfield(Sp, 'StopTime'), Sp.StopTime = Inf; end
Sp.Win = 0.001;  % Set match window (seconds).
% Now, process command-line options.
if round(length(varargin)/2)*2 ~= length(varargin)
  errordlg('Options must each be entered as pairs. ABORTED.', 'eaf_compare');
  return;
end
for k = 1:2:length(varargin)
  switch lower(varargin{k})
    case 'compare'
      switch lower(varargin{k+1})
        case {'agreement', 'truthtest'}, Sp.Compare = lower(varargin{k+1});
        otherwise, Msg = ['Bogus option to "Compare": ' Sp.Compare '. ABORTED.'];
          errordlg(Msg, 'eaf_compare');
      end
    case 'print'
      switch lower(varargin{k+1})
        case 'on',  Print = 1;
        case 'off', Print = 0;
        otherwise, Msg = ['Bogus option to "Print": ' varargin{k+1} '. ABORTED.'];
          errordlg(Msg, 'eaf_compare');          
      end
    case 'starttime'
      Sp.StartTime = varargin{k+1};
      if length(Sp.StartTime) ~= 1
        errordlg('Bogus argument to "StartTime." ABORTED.', 'eaf_compare');
        return;
      end
    case 'stoptime'
      Sp.StopTime = varargin{k+1};
      if length(Sp.StopTime) ~= 1
        errordlg('Bogus argument to "StopTime." ABORTED.', 'eaf_compare');
        return;
      end
    case 'window'
      Sp.Win = varargin{k+1};
      if length(Sp.Win) ~= 1
        errordlg('Bogus argument to "Window." ABORTED.', 'eaf_compare');
        return;
      end
    otherwise
      errordlg(['Bogus option: "' varargin{k} '". ABORTED.'], 'eaf_compare');
      return
  end
end

%%%%%%%%%% Initialization.
%   Set assignment vector to all "no assignment" values.
Sp.TEasn = NaN * ones(size(Sp.TEtim));
%   Determine number of MUs for True, Test; initialize confusion matrix.
Sp.MUidTR = find_unique(Sp.TRnum);  % Sorted list of TRnum MU numbers.
Sp.MUidTE = find_unique(Sp.TEnum);  % Sorted list of TEnum MU numbers.
Sp.MUmap = NaN * zeros(1,length(Sp.MUidTE));  % Default.
Sp.Confuse = zeros( length(Sp.MUidTR)+1, length(Sp.MUidTE)+1 );  % Init.
%   Pre-allocate TT fields.
Sp.TT.Acc    = NaN * ones( length(Sp.MUidTR), length(Sp.MUidTE) );
Sp.TT.Hits   = NaN * ones( length(Sp.MUidTR), length(Sp.MUidTE) );
Sp.TT.NF     = NaN * ones( length(Sp.MUidTR), length(Sp.MUidTE) );
Sp.TT.NI     = NaN * ones( length(Sp.MUidTR), length(Sp.MUidTE) );
Sp.TT.Offset = NaN * ones( length(Sp.MUidTR), length(Sp.MUidTE) );

%%%%%%%%%% Perform comparison steps.
Sp = step1(Sp);
Sp = step2(Sp);
Sp = step3(Sp);

%%%%%%%%%% Pretty-print confusion matrix, if desired.
if Print, PrintConfuse(Sp); end

%%%%%%%%%% Ready outputs.
Sp = rmfield(Sp, {'TRtim' 'TEtim' 'TRnum' 'TEnum' 'MU_TRtim'});
Sp = rmfield(Sp, {'MU_TEtim' 'TT' 'StartTime' 'StopTime' 'Win'});

return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%% Out = find_unique(In) %%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Out = find_unique(In)
% Return a sorted (ascending) column vector of the unique values in In.
Out = [];  % Initialize output to null vector.
if isempty(In), return, end     % In case of empty input vector.
while length(In)>0
  Out = [Out; In(1)];           % Grab next unique value.
  In = In( find(In ~= In(1)) ); % Remove this value from In.
end;
Out = sort(Out);                % Sort numbers for orderliness.

return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% step1() %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Sk = step1(Sk)
% Step 1: Compute information for all truth-test combinations.  Note that
%     certain comparison algorithms may wish to call step1() after some
%     matches (and annotation pairings) have already occurred.  Thus,
%     step1() goes through every truth-test combination.  If a match has
%     already occurred for a combination, the normal truth-test info
%     is not computed.  Rather, the number of hits and the accuracy
%     are set to zero.  In this way, that truth-test combination will
%     never be selected for matching.  Also note that pre-existing
%     pairings are signified by setting values within TRtim and TEtim
%     to NaN.  Thus, subfunction offset_info() must account for this
%     possibility.

% Extract MU times for each MU for truth, test.
for k=1:length(Sk.MUidTR), Sk.MU_TRtim{k}=Sk.TRtim(find(Sk.TRnum==Sk.MUidTR(k))); end
for k=1:length(Sk.MUidTE), Sk.MU_TEtim{k}=Sk.TEtim(find(Sk.TEnum==Sk.MUidTE(k))); end

for Itrue = 1:length(Sk.MUidTR)
  for Itest = 1:length(Sk.MUidTE)
     % Estimate offset. Compute hits, NIs and NFs.
    if Sk.MUmap(Itest) == Sk.MUidTR(Itrue)  % Already matched?
      Sk.TT.Hits(Itrue,Itest) = 0;  % Yes: Set hits=0; won't be a match.
    else
      Sk = offset_info(Sk, Itrue, Itest); % No: Compute offset info.
    end
    % Compute resulting accuracy.
    if Sk.TT.Hits(Itrue,Itest) == 0  % Check for no pairs before divide.
      Sk.TT.Acc(Itrue,Itest) = 0;
    else
      Sk.TT.Acc(Itrue,Itest) = Sk.TT.Hits(Itrue,Itest) ./ ...
        ( Sk.TT.Hits(Itrue,Itest) + Sk.TT.NF(Itrue,Itest) + Sk.TT.NI(Itrue,Itest) );
    end
  end
end

return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%% offset_info() %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Sk = offset_info(Sk, Itrue, Itest)
% Measure timing differences for every test annotation for this truth-
% test combination.  Use those differences to make an offset estimate.
% Then, use the offset estimate to determine the number of hits,
% Not Includeds and Not Founds.
%      Note that this function can be called after some pairings have
% already occurred.  Thus, MU_TRtim and MU_TEtim can have some (or all)
% NaN entries.  The NaN times should be treated as if they did not exist,
% but the NaN values must remain in the time vectors.  So, need to be sure
% all math works with NaNs.  Also, if no non-NaN differences remain, then
% set "hits" to zero and return.

% If no non-NaN test or true annots --- set "hits" to 0, then return.
TR_OK = find( ~isnan(Sk.MU_TRtim{Itrue}) );  % Non-NaN true indeces.
TE_OK = find( ~isnan(Sk.MU_TEtim{Itest}) );  % Non-NaN test indeces.
if isempty(TR_OK) | isempty(TE_OK), Sk.TT.Hits(Itrue,Itest) = 0; return; end

% Measure distances from TEST spikes. If MU_TEtim(Itest)(k)=NaN, X(k)<==NaN.
X = ones(size(Sk.MU_TEtim{Itest})); % Pre-alloc; Full difference vector.
for k = 1:length(Sk.MU_TEtim{Itest})  % [Below] Locate min distance.
  [Vmin, Imin] = min( abs(Sk.MU_TEtim{Itest}(k) - Sk.MU_TRtim{Itrue}) );
  X(k) = Sk.MU_TRtim{Itrue}(Imin) - Sk.MU_TEtim{Itest}(k);  % Signed diff.
end                            % [Below] Final length(X) is > 0.
X = X(TE_OK);  % Now, eliminate where MU_TEtim was NaN.

% Concatenate distances from TRUTH spikes IF Compare=='Agreement'.
if strcmp(Sk.Compare, 'agreement')
  Y = ones(size(Sk.MU_TRtim{Itrue})); % Pre-alloc; Full difference vector.
  for k = 1:length(Sk.MU_TRtim{Itrue})  % [Below] Locate min distance.
    [Vmin, Imin] = min( abs(Sk.MU_TRtim{Itrue}(k) - Sk.MU_TEtim{Itest}) );
    Y(k) = Sk.MU_TRtim{Itrue}(k) - Sk.MU_TEtim{Itest}(Imin);  % Signed diff.
  end                            % [Below] Final length(Y) is > 0.
  Y = Y(TR_OK);  % Now, eliminate where MU_TRtim was NaN.
  X = [X; Y];  % Concatenate.
end

% Compute mode as offset estimate (ten alignments).
Sk.TT.Offset(Itrue, Itest) = mode_est(X, 10);

% Determine number of "hits," as well as NI and NF.
Sk.TT.Hits(Itrue, Itest) = length( find( abs(X-Sk.TT.Offset(Itrue, Itest)) <= Sk.Win ) );
Sk.TT.NI(Itrue, Itest)   = length(X) - Sk.TT.Hits(Itrue, Itest);
Sk.TT.NF(Itrue, Itest)   = length(X) - Sk.TT.Hits(Itrue, Itest);

return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% mode_est() %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Mode = mode_est(X, Nalign)
% Mode = mode_est(X, Nalign)
%
% Nalign is the number of bin alignments.
% Estimate the mode of sample vector X.  X is expected to be unimodal and
% have a general central tendancy, but may well have outlier values.  The
% general method attributed to Dalenius is used (Tore Dalenius, "The Mode
% --- A Neglected Statistical Paramenter," Journal of the Royal Statistical
% Society, Series A (General), Vol. 128, No. 1, pp. 110--117, 1965).
% Delenius suggested creating a histogram of the data samples, then
% basing the mode on the bin with the largest number of samples.  Delenius
% suggested using the mid-point value of the mode bin.  Other authors
% (e.g., S. Blair Hedges and Prachi Shah, "Comparison of mode estimation
% methods and application in molecular clock analysis," BMC Bioinformatics,
% Vol.4, No. 31, 2003 [Open Access available at:
% http://www.biomedcentral.com/1471-2105/4/31]) have suggested using the
% mean value of the samples within the mode bin.  No specific guidance
% was given by these authors on automated selection of the sizes and
% locations of the bins.
%      Here, we create bins of size Bwidth with Nalign different
% alignments.  The alignments are staggered across the span of Bwidth.
% Bins begin at Start (plus an alignment offset) and extend approximately
% to Stop.
Bwidth = 0.001;  % Bin width in seconds.
%Start = -0.01;  Stop = 0.01;
Start = -0.035;  Stop = 0.035;
Mode = [];

for m = 1:Nalign
  edges = [Start : Bwidth : Stop];  % Set histogram bin locations.
%  n = histc(X, edges);              % Form histogram.
  centers = [Start-Bwidth/2 : Bwidth : Stop+Bwidth/2];
  n = hist (X, centers)';
  n = [n(2:end-1); 0];
  [junk, I1] = max_central(n);      % Find mode bin.
  I2 = find( X>=edges(I1) & X<edges(I1+1) ); % Find samples in mode bin.
  if isempty(I2)                    % In case no pairs in range.
    Mode = [Mode 0];
  else
    Mode = [Mode mean( X(I2) )];    % Average of samples in mode bin.
  end
  Start = Start + Bwidth/Nalign;    % Ready for next pass.
end

Mode = mean(Mode);
return

function [C,I] = max_central(vector)
% Returns C as the largest element in vector.  Returns I as the index of
% the maximum value.  In case of ties, returns the index of the maximum
% value closest to the central index of the array.  If a left-most and
% right-most index are equally close to the center, the left-most index is
% returned.

% Find maximum value.
C = max(vector);

% Find all indeces corresponding to this max value.
I = find(vector==C);

% Resolve ties, if any.
if length(I)==1, return; end       % Else, I is a vector.

X = I - ( (length(vector)+1)/2 );% Distances of indeces from central index.
[Junk, Ifind] = min( abs(X) );   % Index into I of min distance.
I = I(Ifind);                    % Extract appropriate original index.

return;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% step2() %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Sk = step2(Sk)
% Step 2: Determine matches.

% We need to sort the truth-test combination results via the following
% prioritized list: most hits, highest accuracy, fewest unpaired test
% spikes, lowest truth MU ID number, then lowest test MU ID number.
% We also need to track the truth-test combination while doing so.
% The most useful Matlab function seems to be sortrows(), which sorts entire
% rows based on mult-column conditions.  (Just what we want.)  But, there are
% a few issues.  First, for backward compatibility (e.g., Matlab 5.3), we can
% only use sortrows() for ascending sorting.  But, Hits and Acc require
% descending sort.  Since both Hits and Acc are non-negative, we can
% achieve descending sort by sorting their negation.  Second, the truth-
% test comparison information is collected in a 2D array per item.  We
% need each item to be a column.  Thus, we will move the TT information
% from its 2D matrices into a matrix, one item per column.  We will
% also add matrix columns for the truth MU ID number and the test MU
% ID number (for use in sorting).  Third, to track
% the truth-test combination, we will add one column to the matrix to denote
% the truth index (as from MUidTR) and a second column to denote
% the test index (as from MUidTE).  When unwrapping the 2D matrix to a column
% vector, note that unitary index references to Matlab 2D matrices index
% along the columns.  Thus, unitary index (2) corresponds to 2D matrix
% index (2,1).

% TTres: Truth-test results matrix.  Columns, in order, are: (1) -Hits,
%      (2) -Acc, (3) Not Included, (4) Truth MU ID number,
%     (5) Test MU ID number, (6) Itrue, (7) Itest.
%      Note the negative values in front of Hits and Acc.
%      The matrix will be created with row ordering following the unwrapped
%      row ordering of TT.  Then, the rows will be sorted.  Finally,
%      matching will be performed.  Once a row is no longer available for
%      matching, its "Hits" (column 1 value) will be set to NaN.

% Create/assemble the truth-test results matrix.
Ltrue = length(Sk.MUidTR);  Ltest = length(Sk.MUidTE);  % Numbers of MUs.
N = Ltrue * Ltest;  % Number of rows in TTres.
TTres = zeros(N, 7);  % Pre-allocate.
% Use try..catch..end to get matrix dimensions right.  Issues when
%   only one test MU, since unitary indexing of a vector does not change
%   its shape, but unitary indexing of a matrix gives a row vector.
try; TTres(:,1:3) = [-Sk.TT.Hits(1:N)' -Sk.TT.Acc(1:N)' Sk.TT.NI(1:N)'];
catch; TTres(:,1:3) = [-Sk.TT.Hits(1:N)  -Sk.TT.Acc(1:N)  Sk.TT.NI(1:N) ];
end
for k=1:Ltrue:N, TTres(k:k+Ltrue-1,6) = [1:Ltrue]';      end
for k=1:Ltrue:N, TTres(k:k+Ltrue-1,7) = ((k-1)/Ltrue)+1; end
TTres(:,4) = Sk.MUidTR( TTres(:,6) );
TTres(:,5) = Sk.MUidTE( TTres(:,7) );

% Sort the truth-test results matrix.
[TTres, Isort] = sortrows(TTres, [1 2 3 4 5]);

% Mark as unavailable any rows with less than 20% true positives.
% For Compare=TruthTest, base 20% on the number of true spikes.
% For Compare=Agreement, base 20% on the larger of the number
% of true spikes or the number of test spikes.
% Vector Nspike: Holds the number of spikes for 20% comparison,
% arranged in vector to correspond with TTres(1) [number of hits).
Nspike = ones(N,1);                                    % Pre-allocate.
if strcmp(Sk.Compare, 'truthtest')  % Truth-test comparison.
  for k=1:Ltrue, Ltemp(k) = length(Sk.MU_TRtim{k}); end  % One column of TT.
  for k=1:Ltrue:N, Nspike(k:k+Ltrue-1) = Ltemp; end      % Unwrapped.
else  % Agreement comparison.
  Index = 1;
  for m = 1:Ltest
    for k = 1:Ltrue  % [Below] Pick longest length for each combination.
      Nspike(Index) = max(length(Sk.MU_TRtim{k}), length(Sk.MU_TEtim{m}));
      Index = Index + 1;
    end
  end
end
Nspike = Nspike(Isort);  % Sort corresponding to TTres.
TTres( find( (-TTres(:,1) ./ Nspike) < 0.2 ), 1 ) = NaN;% Mark.

% Select matches.
for k = 1:N, if ~isnan(TTres(k,1))  % New match found.
  % Record the match.
  Sk.MUmap( TTres(k,7) ) = Sk.MUidTR( TTres(k,6) );
  % Mark unavailable the truth and test IDs.
  TTres( find(TTres(:,6)==TTres(k,6)), 1 ) = NaN;  % Truth.
  TTres( find(TTres(:,7)==TTres(k,7)), 1 ) = NaN;  % Test.
end, end

return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Sk = step3() %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Sk = step3(Sk)
% Step 3: Form Confusion matrix.

% Pairing for matched MUs
for k = 1:length(Sk.MUmap), if ~isnan(Sk.MUmap(k))  % Loop over matches.
    Itrue = find( Sk.MUidTR == Sk.MUmap(k) );       % Truth index.
    Sk = SeqPair(Sk, Itrue, k);     % Pair; update Confuse.
end, end

% Pairing for unmatched MUs.
Sk = SeqPair(Sk, NaN, NaN);

% Deal with Not Found and Not Included.
Ltrue = length(Sk.MUidTR);  Ltest = length(Sk.MUidTE);
% Not Found.
Sk.TRtim( find(Sk.TRtim<=Sk.StartTime+Sk.Win) ) = NaN;  % Fix head.
Sk.TRtim( find(Sk.TRtim>=Sk.StopTime -Sk.Win) ) = NaN;  % Fix tail.
X = Sk.TRnum( find(~isnan(Sk.TRtim)) );  % All Not Found annotations.
for k=1:Ltrue, Sk.Confuse(k,Ltest+1) = sum(X==Sk.MUidTR(k)); end
% Not Included.
Sk.TEtim( find(Sk.TEtim<=Sk.StartTime+Sk.Win) ) = NaN;  % Fix head.
Sk.TEtim( find(Sk.TEtim>=Sk.StopTime -Sk.Win) ) = NaN;  % Fix tail.
X = Sk.TEnum( find(~isnan(Sk.TEtim)) );  % All Not Included annotations.
for k=1:Ltest, Sk.Confuse(Ltrue+1,k) = sum(X==Sk.MUidTE(k)); end

return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SeqPair() %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Sk = SeqPair(Sk, Itrue, Itest)
% Scans through annotations and finds annotation pairs.  True and test
% annotations can each be limited to one MU number (denoted by Itrue and
% Itest, respectively), or can utilize any MU (by setting Itrue/Itest to
% NaN).  Found pairs are added to Confuse and marked
% as accounted for in Sk.  Unpaired annotations are skipped.
%
% Sk: Spike information structure
% Itrue: Index scalor into Sk.MUidTR of true MU identity to pair.  NaN
%      indicates pairing of any true spike, regardless of MU number.
% Itest: Index scalor into Sk.MUidTE of test MU identity to pair.  NaN
%      indicates pairing of any test spike, regardless of MU number.

% Internal variables:
% Ktrue: Index of current true spike annotation, 1:length(Sk.TRnum).
% Ir: Index into MUidTR of current true spike annotation.
% Ktest: Index of current test spike annotation, 1:length(Sk.TEnum).
% Ie: Index into MUidTE of current test spike annotation.

[Ktrue, Ir] = NextAnn(Sk.TRnum, Sk.TRtim, 0, Sk.MUidTR, Itrue);
[Ktest, Ie] = NextAnn(Sk.TEnum, Sk.TEtim, 0, Sk.MUidTE, Itest);

% Loop while BOTH files still have annots with appropriate IDs.
while ~isnan(Ktrue) & ~isnan(Ktest)
  Offset = ChooseOffset(Sk, Ir, Ie);
  if abs( Sk.TEtim(Ktest)+Offset-Sk.TRtim(Ktrue) ) <= Sk.Win  % Pair found.
    Sk.Confuse(Ir, Ie) = Sk.Confuse(Ir, Ie) + 1;
    Sk.TEasn(Ktest) = Ktrue;
    Sk.TEtim(Ktest) = NaN;  Sk.TRtim(Ktrue) = NaN;  % Mark as accounted.
    [Ktrue, Ir] = NextAnn(Sk.TRnum, Sk.TRtim, Ktrue, Sk.MUidTR, Itrue);%Next
    [Ktest, Ie] = NextAnn(Sk.TEnum, Sk.TEtim, Ktest, Sk.MUidTE, Itest);%pass.
  else % No pair, so earliest (un-offset) annotation is an unpaired error.
    if Sk.TRtim(Ktrue) < Sk.TEtim(Ktest)       % Truth annot comes first.
      [Ktrue, Ir] = NextAnn(Sk.TRnum, Sk.TRtim, Ktrue, Sk.MUidTR, Itrue);%Next.
    else                                       % Test  annot comes first.
      [Ktest, Ie] = NextAnn(Sk.TEnum, Sk.TEtim, Ktest, Sk.MUidTE, Itest);%Next.
    end
  end
end

return

function [Iout, I2] = NextAnn(NumVec, TimVec, Iin, MUid, ID)
% Search NumVec and TimVec beginning after index Iin until find an
%   unaccounted time (in TimVec) with a corresponding number
%   (in NumVec) matching ID.  If ID is set to NaN, then accept
%   any number (but still need an unaccounted time).
% Find index of next value ID in NumVec.  ID=NaN ==> take any ID.
% NumVec: Vector of MU ID values.
% TimVec: Vector of corresponding spike times (NaN ==> already accounted).
% Iin:    Current index into NumVec.
% MUid:   Sorted vector of all distinct MU IDs within NumVec.
% ID:     Index of value within MUid to find.  ID=NaN ==> take any ID.
% Iout:   Output index into NumVec.  Set to NaN if MU ID not found.
% I2:     Output index into MUid corresponding to found MU.  Set to NaN
%         if no MU found.

Iout = NaN;  I2 = NaN;  % Default.

if isnan(ID)  % ID is NaN.  Find next non-NaN spike.
  for i = Iin+1:length(NumVec)
    if ~isnan(NumVec(i)) & ~isnan(TimVec(i))
      Iout=i; I2 = find(MUid==NumVec(i)); return
    end
  end
  return
end

% If reach here, ID is not NaN.  Also, next spike not yet paired.
for i = Iin+1:length(NumVec)
  if NumVec(i)==MUid(ID) & ~isnan(TimVec(i)), Iout=i; I2 = ID; return, end
end

return

function Offset = ChooseOffset(Sk, Ir, Ie)
% Determine the offset to use between MU number MUidTR(Ir) and
% MUidTR(Ie).  If the true unit has a match, use the offset
% corresponding to this match.  Else, use the offset between
% the named true-test combination.
% Sk: Information structure.
% Ir: Index into MUidTR of current true spike annotation.
% Ie: Index into MUidTE of current test spike annotation.

Ifind = find( Sk.MUidTR(Ir) == Sk.MUmap );  % Is this truth MU matched?
if isempty( Ifind )  % Not matched.  Use Ir-Ie combination.
  Offset = Sk.TT.Offset(Ir, Ie);
else  % Is matched.  Use offset of that match.
  Offset = Sk.TT.Offset(Ir, Ifind);
end

return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%% PrintConfuse(Sk) %%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Pretty-print the Confusion matrix and appropriate statistics.
function PrintConfuse(Sk)

if size(Sk.Confuse, 1) == 0, return, end  % Case of no annotations.
% Pretty print confusion matrix.
fprintf('\n            TEST File Motor Unit Numbers\n');
fprintf('TRUTH ');
fprintf('%6d', Sk.MUidTE);  % All test IDs.
fprintf('    NF    Dse   Dpp  Dacc   Ose   Opp  Oacc\n');
for Itrue = 1:size(Sk.Confuse, 1)-1  % Loop over truth IDs.
  fprintf('%6d', Sk.MUidTR(Itrue));
  % D==>Detection, O==>Overall.  se==>sensitivity,
  %   pp==>positive predictivity, acc==>accuracy.
  Dse = NaN;  Dpp = NaN;  Dacc = NaN;  Ose = NaN;  Opp = NaN;  Oacc = NaN;
  for Itest = 1:size(Sk.Confuse, 2)-1  % Loop over test IDs.
    if Sk.MUmap(Itest) == Sk.MUidTR(Itrue)
      fprintf('%5d*', Sk.Confuse(Itrue,Itest));
      Dse  = 100 * sum( Sk.Confuse(Itrue, 1:end-1) ) / ...
        ( sum(Sk.Confuse(Itrue, :)) );
      Dpp  = 100 * sum( Sk.Confuse(Itrue, 1:end-1) ) / ...
        ( sum(Sk.Confuse(Itrue, 1:end-1)) + Sk.Confuse(end,Itest) );
      Dacc = 100 * sum( Sk.Confuse(Itrue, 1:end-1) ) / ...
        ( sum(Sk.Confuse(Itrue, :)) + Sk.Confuse(end,Itest) );
      Ose  = 100 * Sk.Confuse(Itrue,Itest) / ...
        ( sum(Sk.Confuse(Itrue, :)) );
      Opp  = 100 * Sk.Confuse(Itrue,Itest) / ...
        ( Sk.Confuse(Itrue,Itest) + Sk.Confuse(end,Itest) );
      Oacc = 100 * Sk.Confuse(Itrue,Itest) / ...
        ( sum(Sk.Confuse(Itrue,:)) + Sk.Confuse(end,Itest) );
    else
      fprintf( '%6d', Sk.Confuse(Itrue,Itest));
    end
  end
  fprintf('%6d ', Sk.Confuse(Itrue,end));  % NFs.
  fprintf('%6.1f', [Dse Dpp Dacc Ose Opp Oacc]);  % Performance.
  fprintf('\n');
end
fprintf('    NI');
fprintf('%6d', Sk.Confuse(Itrue+1, 1:end-1));  % Last line, so omit last
fprintf('\n\n');                               %   element (not used).

return
