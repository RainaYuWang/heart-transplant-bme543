function result = demo_wall_thickness
% DEMO_WALL_THICKNESS Preview six-site result layout without DICOM data.
% All curves and the stylized wall image are SYNTHETIC, not validation data.
[x,y]=meshgrid(1:240,1:280);
r=sqrt(((x-120)/65).^2+((y-140)/110).^2);
img=.12+.65*exp(-((r-1)/.10).^2);
names={'Left Upper','Left Middle','Left Lower','Right Upper','Right Middle','Right Lower'};
initial=cell(1,6); rows=[70 140 210];
for side=1:2
    signX=2*side-3;
    for j=1:3
        angle=asin((rows(j)-140)/110);
        p=[120+signX*65*cos(angle), rows(j)];
        normal=[(p(1)-120)/65^2,(p(2)-140)/110^2]; normal=normal/norm(normal);
        initial{(side-1)*3+j}=[p-14*normal;p+14*normal];
    end
end
frames=1:20; values=zeros(20,6);
for k=1:6
    values(:,k)=6+.5*k+(2+.15*k)*sin(linspace(0,pi,20)'-.06*k).^2;
end
values(10,3)=nan; state=repmat({'synthetic'},20,6); state{10,3}='skipped_demo';
result=struct('is_demo',true,'site_names',{names},'site_colors',lines(6), ...
    'initial_image',img,'initial_lines',{initial});
result.table=wall.sixResults(frames,values,state,names);
wall.plotResults(result);
end
