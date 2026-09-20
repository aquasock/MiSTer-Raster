/* GPL-2.0-or-later. Accessible tool tabs; switching preserves both workflows. */
(()=>{
 'use strict';const names=['playlist','convert'];
 function show(name,focus=false){for(const n of names){const selected=n===name,t=document.getElementById(n+'Tab');t.setAttribute('aria-selected',String(selected));t.tabIndex=selected?0:-1;document.getElementById(n+'Panel').hidden=!selected;if(selected&&focus)t.focus()}}
 names.forEach((name,index)=>{const t=document.getElementById(name+'Tab');t.onclick=()=>show(name);t.onkeydown=e=>{if(['ArrowLeft','ArrowRight','Home','End'].includes(e.key)){e.preventDefault();show(names[e.key==='Home'?0:e.key==='End'?1:1-index],true)}}});
 globalThis.RasterTabs={show};
})();
