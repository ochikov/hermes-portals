import test from 'node:test';
import assert from 'node:assert/strict';
import {ThrowGesture,handPoint} from '../web/gesture.mjs';
import {route} from '../web/graph.mjs';

const frame=(time,x,pinch=.1,extra={})=>({time,x,y:.5,pinch,visible:true,...extra});
test('pinch, hold, move right, release throws once',()=>{
  const g=new ThrowGesture();
  assert.equal(g.update(frame(100,.2)).phase,'holding');
  assert.equal(g.update(frame(300,.22)).phase,'grabbed');
  assert.equal(g.update(frame(500,.9)).ready,true);
  assert.equal(g.update(frame(600,.9,.7)).thrown,true);
  assert.equal(g.update(frame(650,.3)).phase,'cooldown');
});
test('brief pinch, leftward motion and release outside portal never throw',()=>{
  for(const frames of [
    [frame(100,.2),frame(180,.9,.7)],
    [frame(100,.5),frame(300,.5),frame(400,.2,.7)],
    [frame(100,.2),frame(300,.2),frame(400,.7,.7)],
    [frame(100,.2),frame(300,.2),frame(400,.9,.7,{y:.05})],
  ]){const g=new ThrowGesture();assert(frames.every(f=>!g.update(f).thrown));}
});
test('losing hand cancels, it never substitutes for releasing',()=>{
  const g=new ThrowGesture();g.update(frame(100,.2));g.update(frame(300,.3));
  g.update({time:510,visible:false});
  assert.equal(g.update(frame(650,.9,.7)).phase,'idle');
});
test('disabled target, stale grab and invalid tracking do not transfer',()=>{
  const g=new ThrowGesture();g.update(frame(100,.2));g.update(frame(300,.3));
  assert.equal(g.update(frame(400,.9,.7,{enabled:false})).phase,'disabled');
  g.update(frame(600,.2));g.update(frame(800,.2));
  assert(!g.update(frame(5000,.9,.7)).thrown);
  assert.equal(g.update(frame(5100,NaN)).phase,'no-hand');
});
test('tracking uses palm scale and mirrored screen coordinates',()=>{
  const points=Array.from({length:21},()=>({x:.4,y:.4}));
  points[0]={x:.4,y:.8};points[9]={x:.4,y:.4};
  points[4]={x:.25,y:.4};points[8]={x:.29,y:.4};
  const p=handPoint(points);
  assert(Math.abs(p.x-.73)<1e-9);assert(Math.abs(p.pinch-.1)<1e-9);
  assert.equal(handPoint([]),null);
});
test('diagram routes around failed nodes and reports complete disconnection',()=>{
  const obj={source:'in',sink:'db',disabled:[],edges:[['in','a'],['in','b'],['a','db'],['b','db'],['b','in']]};
  assert.deepEqual(route(obj),['in','a','db']);
  assert.deepEqual(route({...obj,disabled:['a']}),['in','b','db']);
  assert.deepEqual(route({...obj,disabled:['a','b']}),[]);
  assert.deepEqual(route({...obj,disabled:['db']}),[]);
});
