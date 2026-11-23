function measurement = contourThickness(innerPixel, outerPixel, spacing, sampleCount, sector)
% CONTOURTHICKNESS Uniform physical inner-arc sampling, shortest outer distance.
% Coordinates are [image column, image row]; spacing is [column, row] in mm.
% sector = [start angle, counterclockwise extent] in degrees: right=0, up=90.
% This is a one-sided 2D distance estimate, not normal or 3D wall thickness.
validateattributes(spacing, {'numeric'}, {'real','finite','positive','numel',2});
validateattributes(sampleCount, {'numeric'}, {'real','finite','scalar','integer','>=',12,'<=',2000});
validateattributes(sector, {'numeric'}, {'real','finite','numel',2});
assert(sector(2)>0 && sector(2)<=360, 'wall:Sector', 'Sector extent must be in (0, 360].');
spacing=reshape(spacing,1,2);
inner=cleanPolygon(innerPixel.*spacing);
outer=cleanPolygon(outerPixel.*spacing);
scale=max([1; abs(inner(:)); abs(outer(:))]);
tol=1e-9*scale;
checkSimple(inner,tol); checkSimple(outer,tol);
[inside,on]=inpolygon(inner(:,1),inner(:,2),outer(:,1),outer(:,2));
assert(all(inside & ~on) && ~boundariesIntersect(inner,outer,tol), ...
    'wall:Contours', 'The inner contour must be strictly inside the outer contour; contours must not touch or cross.');

% Canonical order makes sampling independent of drawing direction/start vertex.
inner=canonical(inner); outer=canonical(outer);
closed=[inner;inner(1,:)]; lengths=sqrt(sum(diff(closed).^2,2));
arc=[0;cumsum(lengths)]; perimeter=arc(end);
distances=((0:sampleCount-1)'+0.5)*perimeter/sampleCount;
samples=interp1(arc,closed,distances,'linear');
next=inner([2:end 1],:);
crossTerm=inner(:,1).*next(:,2)-next(:,1).*inner(:,2);
center=sum((inner+next).*crossTerm,1)/(3*sum(crossTerm));
angles=mod(atan2d(-(samples(:,2)-center(2)),samples(:,1)-center(1)),360);
selected=mod(angles-mod(sector(1),360),360)<sector(2);
if sector(2)==360, selected(:)=true; end
assert(nnz(selected)>=3, 'wall:SectorSamples', ...
    'Fewer than three samples fall in this sector. Increase sample count or widen the sector.');

% Project onto every outer LINE SEGMENT, not merely the drawn vertices.
a=outer; b=outer([2:end 1],:); edge=b-a;
lengthSquared=sum(edge.^2,2);
nearest=zeros(sampleCount,2); thickness=zeros(sampleCount,1);
for k=1:sampleCount
    u=sum((samples(k,:)-a).*edge,2)./lengthSquared;
    u=max(0,min(1,u)); candidates=a+u.*edge;
    d2=sum((candidates-samples(k,:)).^2,2);
    [minimum,index]=min(d2);
    nearest(k,:)=candidates(index,:); thickness(k)=sqrt(minimum);
end
% Reject selected shortest paths that re-enter the cavity in concave contours.
% Silently dropping these paths would bias the reported regional mean.
for k=find(selected)'
    segment=nearest(k,:)-samples(k,:);
    for j=1:size(inner,1)
        [hit,t]=segmentHit(samples(k,:),nearest(k,:),inner(j,:),next(j,:),tol);
        if hit && t>tol/max(norm(segment),tol)
            error('wall:AmbiguousPath', ...
                'A selected shortest-distance line crosses the cavity. Review contours or choose a different region/plane.');
        end
    end
    midpoint=(samples(k,:)+nearest(k,:))/2;
    if inpolygon(midpoint(1),midpoint(2),inner(:,1),inner(:,2))
        error('wall:AmbiguousPath','A selected shortest-distance line passes through the cavity. Review the contours.');
    end
end
measurement=struct('inner_pixel',inner./spacing,'outer_pixel',outer./spacing, ...
    'sample_pixel',samples./spacing,'nearest_outer_pixel',nearest./spacing, ...
    'thickness_mm',thickness,'selected',selected,'angle_deg',angles, ...
    'center_pixel',center./spacing,'mean_mm',mean(thickness(selected)), ...
    'median_mm',median(thickness(selected)),'sample_count',nnz(selected), ...
    'inner_perimeter_mm',perimeter,'arc_step_mm',perimeter/sampleCount);
end

function p=cleanPolygon(p)
validateattributes(p,{'numeric'},{'real','finite','2d','size',[nan 2]});
assert(size(p,1)>=3,'wall:Contours','Each contour needs at least three distinct vertices.');
tol=1e-9*max([1;abs(p(:))]);
p=p([true;sqrt(sum(diff(p).^2,2))>tol],:);
if size(p,1)>1 && norm(p(end,:)-p(1,:))<=tol, p(end,:)=[]; end
assert(size(p,1)>=3 && polyarea(p(:,1),p(:,2))>tol^2, ...
    'wall:Contours','Each contour must enclose a nonzero area.');
end

function p=canonical(p)
q=p([2:end 1],:);
if sum(p(:,1).*q(:,2)-q(:,1).*p(:,2))<0, p=flipud(p); end
[~,order]=sortrows(p,[1 2]); first=order(1);
p=p([first:end 1:first-1],:);
end

function checkSimple(p,tol)
n=size(p,1);
for i=1:n
    a=p(i,:); b=p(mod(i,n)+1,:); c=p(mod(i+1,n)+1,:);
    % Adjacent edges may share a vertex, but may not double back/overlap.
    if abs(cross2(b-a,c-b))<=tol*(norm(b-a)+norm(c-b)) && dot(b-a,c-b)<0
        error('wall:Contours','A contour doubles back on itself. Redraw it without overlapping edges.');
    end
    for j=i+2:n
        if i==1 && j==n, continue; end
        if segmentHit(a,b,p(j,:),p(mod(j,n)+1,:),tol)
            error('wall:Contours','A contour intersects itself. Redraw it without crossing edges.');
        end
    end
end
end

function yes=boundariesIntersect(p,q,tol)
yes=false;
for i=1:size(p,1)
    for j=1:size(q,1)
        if segmentHit(p(i,:),p(mod(i,size(p,1))+1,:),q(j,:),q(mod(j,size(q,1))+1,:),tol)
            yes=true; return;
        end
    end
end
end

function [hit,t]=segmentHit(a,b,c,d,tol)
r=b-a; s=d-c; denominator=cross2(r,s); t=nan;
if abs(denominator)<=tol*(norm(r)+norm(s))
    hit=false;
    if abs(cross2(c-a,r))>tol*norm(r), return; end
    u=[dot(c-a,r) dot(d-a,r)]/dot(r,r);
    lo=max(0,min(u)); hi=min(1,max(u));
    hit=lo<=hi+tol/norm(r); t=hi;
else
    t=cross2(c-a,s)/denominator; u=cross2(c-a,r)/denominator;
    hit=t>=-tol/norm(r) && t<=1+tol/norm(r) && u>=-tol/norm(s) && u<=1+tol/norm(s);
end
end

function z=cross2(a,b)
z=a(1)*b(2)-a(2)*b(1);
end
