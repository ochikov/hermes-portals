import test from 'node:test';
import assert from 'node:assert/strict';
import {MODES,DURATION,sampleGesture} from '../web/hand-demo-motion.mjs';
import {ThrowGesture,handPoint} from '../web/gesture.mjs';

test('illustrated transfer teaches a sequence accepted exactly once by the real recognizer',()=>{
  const recognizer=new ThrowGesture();let throws=0;
  for(let ms=0;ms<=DURATION*1000;ms+=40){
    const sample=sampleGesture('transfer',ms/1000);
    // The demo draws in mirrored coordinates; the real tracker supplies camera coordinates.
    const raw=sample.landmarks.map(p=>({...p,x:1-p.x}));
    const result=recognizer.update({time:ms,visible:true,enabled:true,...handPoint(raw)});
    if(result.thrown) throws++;
  }
  assert.equal(throws,1);
});

test('illustrated hands remain finite and within the preview through every gesture',()=>{
  for(const mode of MODES)for(let t=0;t<=DURATION;t+=.04){
    const sample=sampleGesture(mode,t);
    assert.equal(sample.landmarks.length,21);
    for(const p of sample.landmarks){
      assert.ok(Number.isFinite(p.x)&&p.x>=0&&p.x<=1,`${mode}: x at ${t}`);
      assert.ok(Number.isFinite(p.y)&&p.y>=0&&p.y<=1,`${mode}: y at ${t}`);
    }
  }
});
