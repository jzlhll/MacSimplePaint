export const drawingTools = ['brush', 'pencil', 'eraser', 'fill', 'picker', 'text'];
export const basicLines = ['line', 'dashedLine', 'arrow', 'doubleArrow', 'dashedArrow'];
export const basicShapes = ['rectangle', 'roundedRectangle', 'ellipse', 'ellipseBubble', 'heart'];
export const extraShapes = ['roundedBubble', 'ellipseBubble', 'thoughtBubble', 'hexagon', 'blockArrow', 'leftArrow', 'upArrow', 'downArrow', 'triangle', 'rightTriangle', 'diamond', 'pentagon', 'star', 'fourPointStar', 'sixPointStar', 'trapezoid', 'parallelogram', 'singleRoundedRectangle', 'chevron', 'heart', 'cloud', 'cylinder', 'cube', 'cone'];
export const lineTools = ['line', 'dashedLine', 'dashDotLine', ...['', 'hollow', 'solid'].flatMap(style => ['', 'dashed', 'dashDot'].flatMap(dash => ['Arrow', 'DoubleArrow'].map(head => {
  const name = dash + (dash ? style.charAt(0).toUpperCase() + style.slice(1) : style) + head;
  return name.charAt(0).toLowerCase() + name.slice(1);
})))];
const names = {
  brush: '画笔', pencil: '铅笔', eraser: '橡皮', fill: '填色', picker: '取色', text: '文字',
  line: '直线', dashedLine: '虚线', dashDotLine: '长短虚线', arrow: '单箭头', doubleArrow: '双箭头', dashedArrow: '虚线箭头',
  rectangle: '矩形', roundedRectangle: '圆角', ellipse: '椭圆', more: '更多', moreLines: '更多线条', selection: '选区',
  triangle: '三角形', rightTriangle: '直角三角形', diamond: '菱形', pentagon: '五边形', hexagon: '六边形', star: '五角星', fourPointStar: '四角星', sixPointStar: '六角星',
  trapezoid: '梯形', parallelogram: '平行四边形', singleRoundedRectangle: '半圆头矩形', chevron: '燕尾形', blockArrow: '右向箭头', leftArrow: '左向箭头', upArrow: '向上箭头', downArrow: '向下箭头',
  heart: '心形', roundedBubble: '圆角气泡', ellipseBubble: '椭圆气泡', thoughtBubble: '思考气泡', cloud: '云朵', cylinder: '圆柱体', cube: '立方体', cone: '圆锥体',
  crop: '裁剪', clear: '清空', rotate: '旋转', resize: '尺寸', actions: '更多',
};
export const shortcuts = { brush: 'B', pencil: 'P', eraser: 'E', fill: 'G', picker: 'I', text: 'T', line: 'L', dashedLine: 'D', rectangle: 'R', ellipse: 'O', selection: 'M' };
export function title(tool) {
  if (names[tool]) return names[tool];
  const lower = tool.toLowerCase();
  return [lower.includes('dashdot') ? '长短虚线' : lower.includes('dashed') ? '虚线' : '直线', lower.includes('hollow') ? '空心三角' : lower.includes('solid') ? '实心三角' : '', lower.includes('double') ? '双箭头' : '单箭头'].filter(Boolean).join(' · ');
}
export function tagline(tool) {
  return ({ brush: '让灵感，落在画布上。', pencil: '轻轻起笔，勾勒心中的模样。', eraser: '擦去一切烦恼。', fill: '给平凡的日子，填一点色彩。', picker: '收藏眼前，恰好的那一抹色。', text: '把心里话，写进画里。', selection: '框住喜欢的，留下想要的。', heart: '把喜欢的事，认真放在心上。' })[tool] || '多一点形状，多一种想象。';
}
export const isLine = tool => lineTools.includes(tool);
export function drawLine(ctx, tool, start, end, color, width, preview = false) {
  const distance = Math.hypot(end.x - start.x, end.y - start.y);
  if (!distance) return;
  const lower = tool.toLowerCase(), two = lower.includes('double');
  const head = !lower.includes('arrow') ? 0 : lower.includes('hollow') ? 2 : lower.includes('solid') ? 3 : 1;
  const length = Math.min(distance * (two ? .4 : .65), preview ? 7 : Math.max(14, width * 3));
  const angle = Math.atan2(end.y - start.y, end.x - start.x), inset = head >= 2 ? length * Math.cos(Math.PI / 6) : 0;
  const unit = preview ? 1 : Math.max(1, width / 2);
  ctx.save(); ctx.strokeStyle = color; ctx.fillStyle = color; ctx.lineWidth = width; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  ctx.setLineDash(lower.includes('dashdot') ? [7 * unit, 3 * unit, 2 * unit, 3 * unit] : lower.includes('dashed') ? [4 * unit, 3 * unit] : []);
  ctx.beginPath(); ctx.moveTo(start.x + Math.cos(angle) * (two ? inset : 0), start.y + Math.sin(angle) * (two ? inset : 0));
  ctx.lineTo(end.x - Math.cos(angle) * inset, end.y - Math.sin(angle) * inset); ctx.stroke(); ctx.setLineDash([]);
  function arrow(tip, direction) {
    ctx.beginPath(); ctx.moveTo(tip.x - Math.cos(direction - Math.PI / 6) * length, tip.y - Math.sin(direction - Math.PI / 6) * length);
    ctx.lineTo(tip.x, tip.y); ctx.lineTo(tip.x - Math.cos(direction + Math.PI / 6) * length, tip.y - Math.sin(direction + Math.PI / 6) * length);
    if (head >= 2) ctx.closePath();
    if (head === 3) ctx.fill();
    ctx.stroke();
  }
  if (head) { arrow(end, angle); if (two) arrow(start, angle + Math.PI); }
  ctx.restore();
}

// 图标和画布共用形状路径，保持预览与实际绘制一致。
export function shapePaths(tool, x, y, w, h) {
  const path = new Path2D(), details = new Path2D(), hidden = new Path2D();
  const move = (a, b) => path.moveTo(x + a * w, y + b * h);
  const line = (a, b) => path.lineTo(x + a * w, y + b * h);
  const curve = (a, b, c, d, e, f) => path.bezierCurveTo(x + a * w, y + b * h, x + c * w, y + d * h, x + e * w, y + f * h);
  const poly = points => { move(...points[0]); points.slice(1).forEach(p => line(...p)); path.closePath(); };
  switch (tool) {
    case 'rectangle': path.rect(x, y, w, h); break;
    case 'roundedRectangle': path.roundRect(x, y, w, h, Math.min(18, w / 4, h / 4)); break;
    case 'singleRoundedRectangle': { const r = Math.min(w / 2, h / 2); path.roundRect(x, y, w, h, [0, r, r, 0]); break; }
    case 'ellipse': path.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, 0, 0, Math.PI * 2); break;
    case 'triangle': poly([[.5, 0], [1, 1], [0, 1]]); break;
    case 'rightTriangle': poly([[0, 0], [1, 1], [0, 1]]); break;
    case 'diamond': poly([[.5, 0], [1, .5], [.5, 1], [0, .5]]); break;
    case 'pentagon': case 'hexagon': case 'star': case 'fourPointStar': case 'sixPointStar': {
      const star = tool.toLowerCase().includes('star'), count = tool === 'fourPointStar' ? 4 : ['hexagon', 'sixPointStar'].includes(tool) ? 6 : 5;
      poly(Array.from({ length: star ? count * 2 : count }, (_, i) => {
        const angle = i * Math.PI * 2 / (star ? count * 2 : count) - Math.PI / 2;
        const radius = star && i % 2 ? (count === 4 ? .11 : .215) : .5;
        return [.5 + Math.cos(angle) * radius, .5 + Math.sin(angle) * radius];
      })); break;
    }
    case 'trapezoid': poly([[.22, 0], [.78, 0], [1, 1], [0, 1]]); break;
    case 'parallelogram': poly([[.25, 0], [1, 0], [.75, 1], [0, 1]]); break;
    case 'chevron': poly([[0, 0], [.65, 0], [1, .5], [.65, 1], [0, 1], [.35, .5]]); break;
    case 'blockArrow': poly([[0, .28], [.62, .28], [.62, 0], [1, .5], [.62, 1], [.62, .72], [0, .72]]); break;
    case 'leftArrow': poly([[1, .28], [.38, .28], [.38, 0], [0, .5], [.38, 1], [.38, .72], [1, .72]]); break;
    case 'upArrow': poly([[.5, 0], [1, .38], [.72, .38], [.72, 1], [.28, 1], [.28, .38], [0, .38]]); break;
    case 'downArrow': poly([[.28, 0], [.72, 0], [.72, .62], [1, .62], [.5, 1], [0, .62], [.28, .62]]); break;
    case 'heart':
      move(.5, .98); curve(.26, .8, .02, .6, .02, .32); curve(.02, .15, .13, .04, .28, .04); curve(.38, .04, .46, .09, .5, .18);
      curve(.54, .09, .62, .04, .72, .04); curve(.87, .04, .98, .15, .98, .32); curve(.98, .6, .74, .8, .5, .98); path.closePath(); break;
    case 'roundedBubble':
      move(.12, 0); line(.88, 0); curve(1, 0, 1, 0, 1, .12); line(1, .66); curve(1, .78, 1, .78, .88, .78); line(.45, .78); line(.12, 1); line(.2, .78); line(.12, .78); curve(0, .78, 0, .78, 0, .66); line(0, .12); curve(0, 0, 0, 0, .12, 0); path.closePath(); break;
    case 'ellipseBubble':
      move(.5, 0); curve(.78, 0, 1, .17, 1, .38); curve(1, .59, .78, .76, .5, .76); line(.16, 1); line(.24, .7); curve(.09, .62, 0, .52, 0, .38); curve(0, .17, .22, 0, .5, 0); path.closePath(); break;
    case 'cloud': case 'thoughtBubble': {
      const cloud = new Path2D('M .2 .85 C -.06 .85 -.04 .38 .16 .35 C .1 -.02 .5 -.08 .58 .17 C .8 0 1.02 .13 .88 .4 C 1.13 .48 1.04 .87 .83 .85 Z');
      path.addPath(cloud, new DOMMatrix([w, 0, 0, h * (tool === 'thoughtBubble' ? .78 : 1), x, y]));
      if (tool === 'thoughtBubble') { path.moveTo(x + .33 * w, y + .82 * h); path.ellipse(x + .26 * w, y + .82 * h, w * .07, h * .06, 0, 0, Math.PI * 2); path.moveTo(x + .14 * w, y + .965 * h); path.ellipse(x + .105 * w, y + .965 * h, w * .035, h * .035, 0, 0, Math.PI * 2); }
      break;
    }
    case 'cylinder':
      move(0, .15); curve(0, -.05, 1, -.05, 1, .15); line(1, .85); curve(1, 1.05, 0, 1.05, 0, .85); path.closePath();
      details.moveTo(x, y + h * .15); details.bezierCurveTo(x, y + h * .35, x + w, y + h * .35, x + w, y + h * .15);
      hidden.moveTo(x, y + h * .85); hidden.bezierCurveTo(x, y + h * .65, x + w, y + h * .65, x + w, y + h * .85); break;
    case 'cube':
      poly([[.25, 0], [1, 0], [1, .75], [.75, 1], [0, 1], [0, .25]]);
      details.moveTo(x, y + h * .25); details.lineTo(x + w * .75, y + h * .25); details.lineTo(x + w, y); details.moveTo(x + w * .75, y + h * .25); details.lineTo(x + w * .75, y + h); break;
    case 'cone':
      move(.5, 0); line(1, .82); curve(1, 1.05, 0, 1.05, 0, .82); path.closePath();
      hidden.moveTo(x, y + h * .82); hidden.bezierCurveTo(x, y + h * .59, x + w, y + h * .59, x + w, y + h * .82); break;
  }
  return { path, details, hidden };
}
export function drawShape(ctx, tool, rect, color, width, filled) {
  if (!rect.w || !rect.h) return;
  const paths = shapePaths(tool, rect.x, rect.y, rect.w, rect.h);
  ctx.save(); ctx.strokeStyle = color; ctx.fillStyle = color; ctx.lineWidth = width; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  if (filled) ctx.fill(paths.path);
  ctx.stroke(paths.path); ctx.stroke(paths.details);
  if (!filled) { ctx.setLineDash([width * 3, width * 2]); ctx.stroke(paths.hidden); }
  ctx.restore();
}

const icons = {
  plus: 'M12 4v16M4 12h16', minus: 'M4 12h16', folder: 'M3 7V5h7l2 2h9v13H3z M3 10h18', save: 'M5 11H3v10h18V11h-2M12 3v12m-4-4 4 4 4-4',
  undo: 'M8 5 3 10l5 5M3 10h11a6 6 0 0 1 0 12', redo: 'm16 5 5 5-5 5M21 10H10a6 6 0 0 0 0 12',
  brush: 'm10 14 8-12 4 2-8 12M10 14c-5-1-3 6-7 6 5 3 11 1 11-4z', pencil: 'm4 15 12-12 5 5L9 20l-7 2zM13 6l5 5M4 15l5 5',
  eraser: 'm3 15 10-12 9 8-10 11H9zM8 9l9 8M12 22h10', fill: 'm5 10 8-8 9 10-8 8zM5 10h15M4 17s-4 4-1 5 3-2 1-5',
  picker: 'm15 3 6 6M15 7 3 19l-1 4 4-1L18 10M13 5l6 6', text: 'M3 3h18M12 3v19M8 22h8',
  selection: 'M3 8V3h5M12 3h3M19 3h3v5M22 12v3M22 19v3h-5M13 22h-3M6 22H3v-5M3 13v-2',
  crop: 'M6 2v16h16M2 6h16v16M2 22 22 2', clear: 'm10 9 9 9-6 5-9-9zM13 12l8-9M4 2v6M1 5h6M15 23h8',
  rotate: 'M6 5h14v16H6zM6 1 2 5l4 4M2 5h9', resize: 'M3 9V3h6M3 3l7 7M21 15v6h-6M21 21l-7-7',
  more: 'M5 6h.01M19 6h.01M5 18h.01M19 18h.01', moreLines: 'M5 6h.01M19 6h.01M5 18h.01M19 18h.01', actions: 'M4 12h.01M12 12h.01M20 12h.01',
  outline: 'M5 4h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z',
};
export function icon(name) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', '0 0 24 24'); svg.setAttribute('aria-hidden', 'true');
  if (icons[name] || name === 'filled') {
    const path = document.createElementNS(svg.namespaceURI, 'path'); path.setAttribute('d', icons[name === 'filled' ? 'outline' : name]);
    if (['more', 'moreLines', 'actions'].includes(name)) path.setAttribute('stroke-width', '5');
    if (name === 'filled') path.setAttribute('fill', 'currentColor');
    svg.append(path); return svg;
  }
  // 线条和复杂形状预览直接使用绘图路径。
  const canvas = document.createElement('canvas'); canvas.width = 72; canvas.height = 72;
  const ctx = canvas.getContext('2d'); ctx.scale(3, 3);
  if (isLine(name)) drawLine(ctx, name, { x: 4, y: 20 }, { x: 20, y: 4 }, '#808080', 1.5, true);
  else drawShape(ctx, name, { x: 3, y: 3, w: 18, h: 18 }, '#808080', 1.5, false);
  const image = document.createElementNS(svg.namespaceURI, 'image'); image.setAttribute('href', canvas.toDataURL()); image.setAttribute('width', '24'); image.setAttribute('height', '24'); svg.append(image); return svg;
}
