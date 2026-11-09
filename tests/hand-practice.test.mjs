import test from 'node:test';
import assert from 'node:assert/strict';
import {PracticeRoom,previewPoint} from '../web/hand-practice-model.mjs';
import {HandCamera} from '../web/camera.mjs';

const frame=(time,x,pinch=.1,extra={})=>({time,point:{x,y:.5,pinch},hands:1,...extra});
function grab(room){room.camera(frame(100,.31));room.camera(frame(300,.31));}

test('live practice uses the real recognizer, counts once, and preserves card edits on return',()=>{
  const room=new PracticeRoom();room.offline=false;grab(room);
  room.camera(frame(500,.9));assert.equal(room.phase,'release');
  room.camera(frame(600,.9,.7));room.camera(frame(700,.9,.7));
  assert.equal(room.location,'phone');assert.deepEqual(room.counts,{camera:1,pointer:0,keyboard:0});
  room.reset();assert.equal(room.offline,false);assert.equal(room.counts.camera,1);
});
test('practice requires a grab over the card and a release inside the portal',()=>{
  for(const start of [.05,.62]){
    const room=new PracticeRoom();room.camera(frame(100,start));room.camera(frame(300,start));
    room.camera(frame(500,.9,.7));assert.equal(room.counts.camera,0);
  }
  const room=new PracticeRoom();grab(room);room.camera(frame(500,.7,.7));
  assert.equal(room.location,'laptop');assert.equal(room.counts.camera,0);
});
test('lost tracking or a second hand cancels without a phantom transfer',()=>{
  for(const gap of [{time:510,point:null,hands:0},{time:350,point:null,hands:2}]){
    const room=new PracticeRoom();grab(room);room.camera(gap);room.camera(frame(650,.9,.7));
    assert.equal(room.location,'laptop');assert.equal(room.counts.camera,0);
  }
});
test('brief tracking gap freezes then recovers the same grab',()=>{
  const room=new PracticeRoom();grab(room);room.camera(frame(400,.6));
  const position={...room.position};room.camera({time:460,point:null,hands:0});
  assert.deepEqual(room.position,position);room.camera(frame(510,.88));room.camera(frame(590,.88,.7));
  assert.equal(room.counts.camera,1);
});
test('pointer and keyboard successes stay separate from camera; cancellation is not a release',()=>{
  const room=new PracticeRoom();
  for(const source of ['pointer','keyboard']){
    assert(room.begin({x:.31,y:.5},source));room.pointer({x:.9,y:.5});assert(room.release({x:.9,y:.5}));room.reset();
  }
  assert.deepEqual(room.counts,{camera:0,pointer:1,keyboard:1});
  room.begin({x:.31,y:.5});room.pointer({x:.9,y:.5});room.cancel();assert.equal(room.release({x:.9,y:.5}),false);
  assert.equal(room.counts.pointer,1);
});
test('camera point projection matches cropped video and rejects cropped-out hands',()=>{
  assert.deepEqual(previewPoint({x:.5,y:.5,pinch:.2},640,480,1000,360),{x:.5,y:.5,pinch:.2});
  assert.equal(previewPoint({x:.5,y:0,pinch:.2},640,480,1000,360),null);
  assert.equal(previewPoint({x:.5,y:.5},0,480,1000,360),null);
  assert.equal(previewPoint({x:.75,y:.5,pinch:.2},1280,720,320,400),null);
  const p=previewPoint({x:.6,y:.5,pinch:.2},1280,720,320,400);
  assert(Math.abs(p.x-.7222222222222222)<.0001);
});
test('raw camera preview cannot call handoff or its enabled predicate and releases capture on stop',t=>{
  const previousRaf=globalThis.requestAnimationFrame,previousCancel=globalThis.cancelAnimationFrame;
  globalThis.requestAnimationFrame=()=>1;globalThis.cancelAnimationFrame=()=>{};
  t.after(()=>{globalThis.requestAnimationFrame=previousRaf;globalThis.cancelAnimationFrame=previousCancel;});
  let frames=0,tracksStopped=0,trackersClosed=0;
  const video={readyState:2,currentTime:1,srcObject:{}},pointer={hidden:false};
  const camera=new HandCamera({video,pointer,canvas:{width:640,height:480,getContext:()=>({clearRect(){}})},status:{},
    enabled:()=>assert.fail('preview consulted production readiness'),onThrow:()=>assert.fail('preview invoked a real handoff'),
    onFrame:frame=>{frames++;assert.equal(frame.hands,0);},
  });
  camera.draw=()=>{};camera.active=true;camera.tracker={detectForVideo:()=>({landmarks:[]}),close:()=>trackersClosed++};
  camera.stream={getTracks:()=>[{stop:()=>tracksStopped++}]};camera.tick(100);
  assert.equal(frames,1);camera.stop();camera.tick(200);
  assert.equal(frames,1);assert.equal(tracksStopped,1);assert.equal(trackersClosed,1);
  assert.equal(video.srcObject,null);assert.equal(pointer.hidden,true);
});
