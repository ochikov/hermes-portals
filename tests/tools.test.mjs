import test from 'node:test';
import assert from 'node:assert/strict';
import {calculate} from '../web/tools.mjs';

const calculator={fields:[{id:'people',value:3},{id:'days',value:20},{id:'rate',value:500}],outputs:[
  {id:'effort',operation:'product',fields:['people','days']},
  {id:'cost',operation:'product',fields:['people','days','rate']},
  {id:'sum',operation:'sum',fields:['people','days']},
]};
test('calculator preview and committed snapshot have identical results',()=>{
  assert.deepEqual(calculate(calculator).map(o=>o.value),[60,30000,23]);
  const saved=structuredClone(calculator);saved.fields[1].value=42;
  assert.deepEqual(calculate(calculator,{days:42}),calculate(saved));
  assert.equal(calculator.fields[1].value,20);
});
test('calculator accepts zero overrides and refuses unknown operations or fields',()=>{
  assert.equal(calculate(calculator,{people:0})[0].value,0);
  const invalid=structuredClone(calculator);invalid.outputs[0].operation='eval';
  assert.throws(()=>calculate(invalid));
  invalid.outputs[0]={operation:'sum',fields:['missing']};
  assert.throws(()=>calculate(invalid));
  assert.throws(()=>calculate(calculator,{days:Infinity}));
});
