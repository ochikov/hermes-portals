import {ThrowGesture} from './gesture.mjs';

// Match object-fit: cover in the video and landmark canvas, including cropping.
export function previewPoint(point,videoWidth,videoHeight,width,height){
  if(!point||![videoWidth,videoHeight,width,height].every(n=>Number.isFinite(n)&&n>0))return null;
  const scale=Math.max(width/videoWidth,height/videoHeight);
  const x=(point.x*videoWidth*scale-(videoWidth*scale-width)/2)/width;
  const y=(point.y*videoHeight*scale-(videoHeight*scale-height)/2)/height;
  return x<0||x>1||y<0||y>1?null:{...point,x,y};
}

/** Page-local exercise only: no transport, camera, DOM or OS input. */
export class PracticeRoom {
  constructor(){this.offline=true;this.counts={camera:0,pointer:0,keyboard:0};this.reset();}
  reset(){
    this.gesture=new ThrowGesture();this.phase='ready';this.position={x:.31,y:.5};
    this.location='laptop';this.drag=null;this.lastPoint=null;this.hold=0;
  }
  hit({x,y}){return Math.abs(x-this.position.x)<.18&&Math.abs(y-this.position.y)<.24;}
  valid(point){return point&&[point.x,point.y].every(Number.isFinite);}
  move(point){
    this.position={x:Math.max(.1,Math.min(.9,point.x+this.drag.x)),y:Math.max(.18,Math.min(.82,point.y+this.drag.y))};
    this.lastPoint=point;this.phase=point.x>.80&&point.y>.12&&point.y<.88?'release':'dragging';
  }
  deliver(source){this.counts[source]++;this.location='phone';this.phase='delivered';this.position={x:.89,y:.5};this.drag=null;this.hold=0;}
  cancel(reason='cancelled'){
    this.gesture.reset();this.drag=null;this.lastPoint=null;this.hold=0;
    if(this.location==='laptop'){this.phase=reason;this.position={x:.31,y:.5};}
  }
  camera({time,point,hands=1}){
    if(this.location==='phone')return;
    if(hands>1){this.cancel('one-hand');return;}
    const valid=hands===1&&this.valid(point)&&Number.isFinite(point.pinch);
    const was=this.gesture.phase;
    const enabled=valid&&(was!=='idle'||this.hit(point));
    const result=this.gesture.update({time,visible:valid,...(valid?point:{}),enabled:valid?enabled:true});
    if(!valid){
      // Freeze a brief gap, then cancel; losing a hand is never a release.
      if(this.gesture.phase==='idle')this.cancel(hands>1?'one-hand':'lost');
      else this.phase='lost';
      return;
    }
    if(result.thrown){this.deliver('camera');return;}
    if(result.phase==='holding'){
      if(was==='idle')this.drag={x:this.position.x-point.x,y:this.position.y-point.y};
      this.phase='holding';this.hold=Math.max(0,Math.min(1,(time-this.gesture.started)/180));return;
    }
    if(result.phase==='grabbed'){
      this.drag??={x:0,y:0};this.hold=1;this.move(point);return;
    }
    if(was==='grabbed'||was==='holding'){this.cancel();return;}
    this.phase=this.hit(point)?'hover':'ready';this.hold=0;
  }
  begin(point,source='pointer'){
    if(!['pointer','keyboard'].includes(source)||this.location==='phone'||!this.valid(point)||!this.hit(point))return false;
    this.drag={x:this.position.x-point.x,y:this.position.y-point.y,source};this.lastPoint=point;this.phase='dragging';return true;
  }
  pointer(point){if(this.drag&&this.valid(point))this.move(point);}
  release(point){
    if(!this.drag)return false;
    const source=this.drag.source||'pointer';
    if(this.valid(point)&&point.x>.80&&point.y>.12&&point.y<.88){this.deliver(source);return true;}
    this.cancel();return false;
  }
}
