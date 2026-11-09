export function route(artifact) {
  const off = new Set(artifact.disabled);
  if (off.has(artifact.source) || off.has(artifact.sink)) return [];
  const queue = [[artifact.source]], visited = new Set([artifact.source]);
  while (queue.length) {
    const path = queue.shift(), current = path.at(-1);
    if (current === artifact.sink) return path;
    for (const [from, to] of artifact.edges) {
      if (from === current && !off.has(to) && !visited.has(to)) {
        visited.add(to); queue.push([...path, to]);
      }
    }
  }
  return [];
}

const NS = 'http://www.w3.org/2000/svg';
function svgNode(tag, attributes, text) {
  const node = document.createElementNS(NS, tag);
  for (const [key,value] of Object.entries(attributes)) node.setAttribute(key,String(value));
  if (text !== undefined) node.textContent = text;
  return node;
}

export function drawGraph(svg, artifact, onSelect) {
  svg.replaceChildren();
  const width=Math.max(260,svg.clientWidth), compact=width<550;
  const height=compact?420:Math.max(300,width*.49);
  const nodeWidth=compact?94:124;
  svg.setAttribute('viewBox',`0 0 ${width} ${height}`);
  svg.setAttribute('aria-label', `${artifact.title}. ${artifact.disabled.length} nodes disabled.`);
  const path = route(artifact), off = new Set(artifact.disabled);
  const nodes = Object.fromEntries(artifact.nodes.map(n => [n.id,n]));
  const used = new Set(path.slice(1).map((n,i)=>`${path[i]}:${n}`));
  const position=n=>({x:Math.max(nodeWidth/2+4,Math.min(width-nodeWidth/2-4,(compact?n.y:n.x)*width)),
    y:Math.max(35,Math.min(height-35,(compact?n.x:n.y)*height))});
  for (const [from,to] of artifact.edges) {
    const a = position(nodes[from]), b = position(nodes[to]), live = used.has(`${from}:${to}`);
    svg.append(svgNode('line', {
      x1:a.x, y1:a.y, x2:b.x, y2:b.y,
      class:`edge ${live?'live':''} ${off.has(from)||off.has(to)?'offline':''}`,
    }));
  }
  for (const n of artifact.nodes) {
    const at=position(n);
    const group = svgNode('g', {transform:`translate(${at.x},${at.y})`,
      class:`node ${off.has(n.id)?'offline':''} ${path.includes(n.id)?'on-route':''} ${artifact.selected===n.id?'selected':''}`});
    group.append(svgNode('rect', {x:-nodeWidth/2,y:-30,width:nodeWidth,height:60,rx:16}));
    const limit=compact?11:17;
    group.append(svgNode('text', {y:-1,'text-anchor':'middle',class:compact?'compact-label':''}, n.label.length>limit?n.label.slice(0,limit-1)+'…':n.label));
    group.append(svgNode('text', {y:18,'text-anchor':'middle',class:'node-state'}, off.has(n.id)?'OFFLINE':'ONLINE'));
    // SVG supplements the full-size, keyboard-accessible node buttons below.
    group.addEventListener('click',()=>onSelect(n.id));
    svg.append(group);
  }
  return path;
}
