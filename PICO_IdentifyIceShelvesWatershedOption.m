function [ShelfNum,BoxID,Ak,floating] = PICO_IdentifyIceShelvesWatershedOption(UserVar,CtrlVar,MUA,GF,PICOres,minArea,minNumS,nmax,FloatingCriteria,FillHoles)
%
% Function to generate unique shelf IDs with corresponding areas,
% subdivided into boxes using the method described in Reese (2018).
%
% Usage: [ShelfNum,BoxID,ShelfArea] = IdentifyIceShelvesWatershedOption(CtrlVar,MUA,GF,PICOres,minArea,minNumS,nmax)
%
% PICOres = 10000; % the resolution used in the watershed algorithm, lower numbers will be slower but will capture more detailed ice shelf geometries that might be missed otherwise
% minArea = 2e9; % minimum ice shelf area in m^2 - lower numbers may slow code quite significantly
% minNumS = 20; % minimum number of floating nodes needed to be considered
% an ice shelf, this is only needed to deal with a few cases where an ice shelf may cover a large area in the structured grid but only actually consist of a few nodes
% nmax= 5; % maximum number of boxes per ice shelf


%% this section calculates a unique ID for each shelf using the watershed function

% PICOres = 10000; % the resolution used in the watershed algorithm, will potentially slow things down a lot if this is increased
% minArea = 1e9; % minimum shelf area in m^2
% nmax= 5; % maximum number of boxes per ice shelf

[~,~,Zi,in] = tri2grid(MUA,GF.node,PICOres);

notshelf = Zi>0.99 | ~in;
% ws = watershed(notshelf); %bwlabel seems to do a better and MUCH faster job
inshelf = ~notshelf;
ws = bwlabel(inshelf,8);
% CC = bwconncomp(inshelf,8); ws = labelmatrix(CC);  this seems to be slower

grounded_regions = bwlabel(Zi>0.99,8);
gr_vec = reshape(grounded_regions,[],1);
[num_occur,ind] = hist(gr_vec,unique(gr_vec));

gdGL = num_occur>1000 & ind'>0; %ignore background (b=0)
gdGLind = ind(gdGL);

loc1 = ismember(grounded_regions,gdGLind); %matrix where 1 = 'continental' grounded ice and 0 is islands/ocean/ice shelf

dGLmat = bwdist(loc1);

if FillHoles % if there are holes inside your mesh these will need filling otherwise they are treated as ice fronts
    
    grid_holes = bwfill(in,'holes');
    grid_noholes = ~grid_holes;
    dIFmat = bwdist(grid_noholes);
    
else

    dIFmat = bwdist(~in);

end

x = MUA.coordinates(:,1); y= MUA.coordinates(:,2);

x2 = floor((x-min(x))./PICOres) + 1;
y2 = floor((y-min(y))./PICOres) + 1;
ShelfID = zeros(MUA.Nnodes,1);
dIF = ShelfID;
dGL = dIF;

for ii = 1:numel(x)
    ShelfID(ii) = ws(y2(ii),x2(ii));
    dGL(ii) = dGLmat(y2(ii),x2(ii));
    dIF(ii) = dIFmat(y2(ii),x2(ii));
end

% possibly add here - if any triangle has a node beloning to an ice shelf
% then make all nodes of that triangle belong to the same ice shelf (this
% will hopefully deal with some edge issues

switch FloatingCriteria
    case 'GLthreshold'
    floating = GF.node < CtrlVar.GLthreshold;
    case 'StrictDownstream'
    GF=IceSheetIceShelves(CtrlVar,MUA,GF,[],[],[]);
    floating = GF.NodesDownstreamOfGroundingLines;
    otherwise
    error('Invalid value for PICO_opts.FloatingCriteria');
end
ShelfID(~floating) = -1;

%% this section roughly calculates the area of each ice shelf and removes ice shelves below some minimum area
ws2 = ws; ws2(notshelf)=nan; ws2 = reshape(ws2,[],1);
numshelf = histc(ws2,1:max(max(ws2)));
numshelf2 = histc(ShelfID,1:max(ShelfID));

minNumG = round(minArea/PICOres^2);
badShelf1 = find(numshelf<minNumG);
badShelf2 = find(numshelf2<minNumS);
badShelf = union(badShelf1,badShelf2);
idx = ismember(ShelfID,badShelf); % find the indices of shelves considered bad
ShelfID(idx) = -1; % replace the shelf ID in these locations
ShelfID(ShelfID==0) = -1; % watershed algorithm gives 0 along watershed boundaries, not sure of the best way to deal with this right now...
[~,~,unShelfID] = unique(ShelfID); % replaces all shelf IDs with ascending numbers from 1 (note at this point 1 is grounded ice)
unShelfID(unShelfID<2) = nan;
ShelfNum = unShelfID-1;


if max(ShelfID)==-1
    error('No valid ice shelves detected - check shelf size and shelf area cutoffs are sensible for your domain');
end


%% now calculate the box numbers for each ice shelf

dmax = max(dGL);
BoxID = zeros(size(dGL));

for ii = 1:max(ShelfNum) %need a second loop because only now do we know dmax
    ind = ShelfNum==ii;
    dglmax = max(dGL(ind));
    nD = 1 + round(sqrt(dglmax./dmax)*(nmax-1));
    
    rbox = dGL(ind)./(dGL(ind)+dIF(ind));
    blnkBox = rbox*0;
    
    for k = 1:nD
        p1 = 1-sqrt((nD-k+1)/nD);
        p2 = 1-sqrt((nD-k)/nD);
        blnkBox(p1 <= rbox & rbox <= p2) = k;
    end
    
    BoxID(ind) = blnkBox;
    
end

%% finally calculate the area of each box in each ice shelf

Ak = zeros(max(ShelfNum),nmax);

PBoxEle=ceil(SNodes2EleMean(MUA.connectivity,BoxID));
ShelfIDEle = round(SNodes2EleMean(MUA.connectivity,ShelfNum));
[Areas,~,~,~]=TriAreaFE(MUA.coordinates,MUA.connectivity);

% Each row of Ak is a unique shelf and each column is a box number within
% that shelf, each element of Ak is the total area of a box in a shelf
for ii = 1:max(ShelfNum)
    for k = 1:nmax
       ind = ShelfIDEle==ii & PBoxEle==k;
       Ak(ii,k) = sum(Areas(ind));
    end
end


end