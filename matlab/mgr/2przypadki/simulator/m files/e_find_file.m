function OutName = e_find_file(Fname, OmitFinder, default_path)
% OutName = e_find_file(Fname [,OmitFinder])
% Try to find files and return a string name suitable for use by fopen() (to open
% the file).  Finding files that are not directly on the MATLAB path (e.g., data
% files that might be placed within experiment and/or subject directories) can
% be troublesome.  In addition, I've not had great success using partial pathnames
% in searching for files.  This routine looks in up to four categories of places to
% find file Fname.
%   Fname is a file name, which may optionally include a partial path or a complete
% (absolute) path.  OutName is a file name suitable for use by fopen().  If Fname
% is not found, OutName is set to ''.
%   First, Fname is searched for directly using the exist() command.  If found as a
% file, Fname is returned in OutName.  Note that this search will identify
% files specified with their complete path.
%   Second, Fname is concatenated with the present working directory.  A search
% using exist() is repeated.  If found as a file, OutName returns the complete
% (absolute) path to the file specified by Fname.
%   Third, if variable OmitFinder is NOT specified, then the script looks for a
% user-created script named 'e_my_find_file'.  If created by the user and placed
% in the MATLAB path, then this script must have the same arguments as e_find_file.
% The user can write their own script that finds the file, based on input Fname.
% For example, some investigators embed the experiment and subject names into
% Fname.  Thus, their user-created routine could extract this information and use
% it to find the location of the file.  Note that the user-created routine can
% recursively call e_find_file IF the OmitFinder variable is set to any value (thus
% preventing deeper recursion).  The user supplied routine should return an
% OutName suitable for use by fopen.  If the user supplied routine cannot find the
% file, OutName = '' should be returned.
%   Fourth, the routine appends Fname to each path location within the MATLAB path,
% each time using exist() to look for a file with this name.  If found, the complete
% (absolute) path name of the found file is returned.
%   Note that only file names are found.  The script ignores directory names,
% MATLAB variable names, built-in MATLAB functions and Java class names.

% Copyright (c) 2006. Edward A. Clancy, Kevin C. McGill and others.
% This work is licensed under the Aladdin free public license.
% For copying permissions see license.txt.
% email: emglab@emglab.stanford.edu

if nargin<1, error('No input argument supplied.'); end
if length(Fname)<1, error('Input argument cannot be null.'); end

% 1) Does Fname exist directly as a file?
switch exist(Fname)
  case {2 3 4 6}
    OutName = which(Fname);  % Fails for some complete path Fnames.
    if isempty(OutName), OutName = Fname; end  % Here's the fix.
    % Note: Logic here still fails for Unix-like "../" and "./" notations.
    return;  % Found.
end

% Hereafter, don't let Fname start with the file separator character.
if Fname(1) == filesep, Fname = Fname(2:end); end

% 1a) Did the caller tell you where it is?
if nargin>2;
    if exist (fullfile(default_path, Fname))==2;
        OutName = fullfile(default_path, Fname);
        return;
    end;
end;

% 2) Check the current MATLAB directory (with possible partial path).
switch exist([pwd filesep Fname])
  case {2 3 4 6}, OutName = [pwd filesep Fname]; return;  % Found.
end

% 3) See if user supplied a "finder" program.
if ~exist('OmitFinder') & exist('e_my_find_file')
  OutName = e_my_find_file(Fname);
  if length(OutName) > 0, return; end
end

% 4) Search each directory in MATLAB path (with possible partial path).
remain = matlabpath;  % Gets full MATLAB path.
[token remain] = strtok(remain, pathsep);  % Pulls off first directory.
while ~isempty(token)
  switch exist([token filesep Fname])  % Is file in/off this directory?
    case {2 3 4 6}, OutName = [token filesep Fname]; return;  % Found.
  end
  [token remain] = strtok(remain, pathsep);  % Ready for next pass.
end

% If we get here, then the file was not found.
OutName = '';

return
