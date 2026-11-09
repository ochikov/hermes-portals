/** Illustrative landmarks in mirrored preview coordinates. No camera or OS input. */
export const BONES = [[0,1],[1,2],[2,3],[3,4],[0,5],[5,6],[6,7],[7,8],
  [5,9],[9,10],[10,11],[11,12],[9,13],[13,14],[14,15],[15,16],
  [13,17],[0,17],[17,18],[18,19],[19,20]];
export const MODES = ['transfer','tap','scroll','switch'];
export const DURATION = 6.8;
export const STEP_TIMES = {transfer:[.7,2,3.8,5.8],tap:[.7,2,3.05,5.8],
  scroll:[.7,2,3.4,5.8],switch:[.7,2,3.05,5.8]};
const OPEN = [[0,.42],[-.10,.25],[-.20,.15],[-.28,0],[-.31,-.13],
  [-.12,.02],[-.15,-.25],[-.15,-.43],[-.15,-.58],
  [0,-.01],[0,-.31],[0,-.49],[0,-.65],
  [.12,.02],[.14,-.25],[.14,-.41],[.13,-.55],
  [.22,.08],[.26,-.11],[.27,-.24],[.27,-.36]];
const clamp = x => Math.max(0,Math.min(1,x));
const ease = x => {x=clamp(x);return x*x*(3-2*x);};
const ramp = (t,a,b) => ease((t-a)/(b-a));
const mix = (a,b,t) => a+(b-a)*t;
function blend(a,b,t) {return a.map((p,i)=>p.map((v,j)=>mix(v,b[i][j],t)));}
function curled(pose,fingers) {
  const p=pose.map(v=>[...v]);
  for(const start of fingers){
    const [x,y]=p[start];
    p[start+1]=[x,y-.10];p[start+2]=[x+.025,y+.04];p[start+3]=[x+.015,y+.15];
  }
  return p;
}
const PINCH = OPEN.map(v=>[...v]);
PINCH[2]=[-.19,.12];PINCH[3]=[-.21,-.09];PINCH[4]=[-.17,-.20];
PINCH[6]=[-.15,-.30];PINCH[7]=[-.21,-.28];PINCH[8]=[-.17,-.22];
const POINT=curled(OPEN,[9,13,17]);
const TAP=curled(POINT,[5]);
const TWO=curled(OPEN,[13,17]);

export function sampleGesture(mode,time) {
  if(!MODES.includes(mode))throw new RangeError('Unknown demonstration gesture');
  const t=Number.isFinite(time)?Math.max(0,Math.min(DURATION,time)):0;
  const step=t<1.3?0:t<2.6?1:t<5?2:3;
  let pose=OPEN,x=.34,y=.60,grip=0,amount=0,result=false;
  if(mode==='transfer'){
    grip=ramp(t,1.3,1.9)*(1-ramp(t,4.6,5));
    pose=blend(OPEN,PINCH,grip);
    x=mix(.31,.905,ramp(t,2.6,4.45));
    result=t>=4.9;amount=ramp(t,4.9,5.6);
  } else if(mode==='tap'){
    const bend=ramp(t,2.6,3)*(1-ramp(t,3.15,3.5));
    pose=blend(POINT,TAP,bend);grip=bend;
    result=t>=3.5;amount=result?1:0;
  } else if(mode==='scroll'){
    pose=blend(POINT,TWO,ramp(t,1.3,2));
    amount=t<3.7?ramp(t,2.6,3.7):1-ramp(t,3.7,5);
    y-=amount*.17;result=t>=5;pose=blend(pose,POINT,ramp(t,5,5.8));
  } else {
    x+=ramp(t,2.6,3.35)*.26;
    pose=blend(OPEN,curled(OPEN,[5,9,13,17]),ramp(t,4.3,5)*.7);
    result=t>=3.35;amount=result?1:0;
  }
  const landmarks=pose.map(([px,py])=>({x:x+px*.34,y:y+py*.55,z:0}));
  const point={x:(landmarks[4].x+landmarks[8].x)/2,y:(landmarks[4].y+landmarks[8].y)/2};
  return {time:t,step,landmarks,point,grip,amount,result,mode};
}
