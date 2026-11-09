// Render only registered data types. Artifact content never becomes HTML or code.
export const KINDS = {diagram:'Interactive diagram', checklist:'Interactive checklist', calculator:'Scenario calculator'};
export const formatNumber = value => new Intl.NumberFormat('en', {maximumFractionDigits: 2}).format(value);

export function calculate(artifact, overrides={}) {
  const values = Object.fromEntries(artifact.fields.map(field=>[field.id,overrides[field.id]??field.value]));
  return artifact.outputs.map(output=>{
    const numbers=output.fields.map(id=>values[id]);
    if(numbers.some(value=>!Number.isFinite(value))) throw new Error('Invalid calculator input');
    let value;
    if(output.operation==='sum') value=numbers.reduce((a,b)=>a+b,0);
    else if(output.operation==='product') value=numbers.reduce((a,b)=>a*b,1);
    else throw new Error('Unsupported calculator operation');
    if(!Number.isFinite(value)) throw new Error('Calculator result is out of range');
    return {...output,value};
  });
}

function element(tag, className, text) {
  const node=document.createElement(tag);
  if(className) node.className=className;
  if(text!==undefined) node.textContent=text;
  return node;
}

function checklist(root, artifact, perform) {
  const done=artifact.items.filter(item=>item.done).length;
  const summary=element('div','checklist-summary');
  summary.append(element('strong','completion-count',`${done} / ${artifact.items.length}`),element('p','', 'steps complete'));
  const progress=element('progress');progress.max=artifact.items.length;progress.value=done;
  progress.setAttribute('aria-label','Checklist completion');summary.append(progress);root.append(summary);
  const items=element('div','checklist-items');
  for(const item of artifact.items){
    const row=element('label','checklist-row'+(item.done?' complete':''));
    const input=element('input');input.type='checkbox';input.checked=item.done;input.id='item-'+item.id;
    input.addEventListener('change',()=>perform({type:'set_item',item:item.id,done:input.checked}));
    row.append(input,element('span','',item.label));items.append(row);
  }
  root.append(items,element('p','tool-caption','Tick a step here. Pick up the same checklist on your next screen.'));
}

function calculator(root, artifact, perform) {
  const outputs=element('div','calculator-outputs'), controls=element('div','calculator-fields');
  const draft={}, resultNodes=new Map(), entries=new Map();
  for(const output of artifact.outputs){
    const card=element('div','result-card');
    const result=element('output','result-value');result.id='result-'+output.id;
    card.append(element('span','result-label',output.label),result,element('span','result-unit',output.unit));
    const labels=output.fields.map(id=>artifact.fields.find(f=>f.id===id).label);
    card.append(element('p','formula',labels.join(output.operation==='sum'?' + ':' × ')));
    outputs.append(card);resultNodes.set(output.id,result);
  }
  const hint=element('p','tool-caption','Sliders save on release. After typing, press Enter or Save changes. Transfers save your edits too.');
  function preview(){
    for(const result of calculate(artifact,draft)) resultNodes.get(result.id).value=formatNumber(result.value);
  }
  for(const field of artifact.fields){
    const row=element('div','calculator-field'), header=element('div','field-heading');
    const label=element('label','',field.label);label.htmlFor='range-'+field.id;
    const entry=element('input','number-entry');entry.type='number';entry.id='value-'+field.id;
    entries.set(field.id,entry);
    entry.setAttribute('aria-label',field.label+' value');
    const range=element('input','range-input');range.type='range';range.id='range-'+field.id;
    for(const input of [entry,range]){input.min=field.min;input.max=field.max;input.step=field.step;input.value=field.value;}
    const valueWrap=element('div','field-value');valueWrap.append(entry,element('span','',field.unit));
    header.append(label,valueWrap);
    function draftValue(input, other){
      const value=input.valueAsNumber;
      if(!Number.isFinite(value)||value<field.min||value>field.max)return false;
      draft[field.id]=value;other.value=value;preview();hint.textContent='Preview · finish this change to save it to both devices.';return true;
    }
    for(const [input,other] of [[range,entry],[entry,range]]){
      input.addEventListener('input',()=>draftValue(input,other));
      if(input===range)input.addEventListener('change',()=>perform({type:'save'}));
      input.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();perform({type:'save'});}});
    }
    row.append(header,range);controls.append(row);
  }
  const save=element('button','save-values','Save changes');save.type='button';
  save.addEventListener('click',()=>perform({type:'save'}));
  preview();root.append(outputs,controls,save,hint);
  return {pendingValues(){
    const values={};
    for(const field of artifact.fields){
      const value=entries.get(field.id).valueAsNumber;
      if(!Number.isFinite(value)||value<field.min||value>field.max)throw new Error(`${field.label}: enter a value between ${field.min} and ${field.max}.`);
      if(value!==field.value)values[field.id]=value;
    }
    return values;
  }};
}

const renderers={checklist,calculator};
export function renderTool(root, artifact, perform){
  const focused=document.activeElement?.id;
  root.replaceChildren();
  const render=renderers[artifact.kind];
  let controller;
  if(render)controller=render(root,artifact,perform);
  else root.append(element('p','','This tool type is not supported by this version of Portals.'));
  if(focused){const input=document.getElementById(focused);if(input&&root.contains(input))input.focus({preventScroll:true});}
  return controller;
}
