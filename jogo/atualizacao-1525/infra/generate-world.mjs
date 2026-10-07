// Original development fixtures for Entre Veus. No game sprite pixels are copied.
// Structural metadata is read from the pinned GPL Canary data for protocol compatibility.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import crypto from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const u8=n=>Buffer.from([n]), u16=n=>{const b=Buffer.alloc(2);b.writeUInt16LE(n);return b},u32=n=>{const b=Buffer.alloc(4);b.writeUInt32LE(n>>>0);return b};
const cat=(...v)=>Buffer.concat(v.flat());
const str=s=>cat(u16(Buffer.byteLength(s)),Buffer.from(s));
function proto(buf){let p=0;const m=new Map();function vi(){let n=0,s=0,c;do{c=buf[p++];n+=(c&127)*2**s;s+=7}while(c&128);return n}while(p<buf.length){const k=vi(),tag=Math.floor(k/8),w=k&7;let v;if(w===0)v=vi();else if(w===2){const n=vi();v=buf.subarray(p,p+n);p+=n}else if(w===5){v=buf.subarray(p,p+4);p+=4}else if(w===1){v=buf.subarray(p,p+8);p+=8}else throw Error('Unsupported protobuf wire '+w);if(!m.has(tag))m.set(tag,[]);m.get(tag).push(v)}return m}
const first=(m,k,d=0)=>m.get(k)?.[0]??d;
// Preserve the pinned upstream metadata and append original project item definitions.
const metadataPath=path.join(root,'servidor/data/items/appearances.dat');
const upstreamPath=path.join(root,'infra/appearances-upstream.dat');
if(!fs.existsSync(upstreamPath))fs.copyFileSync(metadataPath,upstreamPath);
const vi=n=>{const b=[];do{b.push((n&127)|(n>127?128:0));n=Math.floor(n/128)}while(n);return Buffer.from(b)};
const pv=(tag,n)=>cat(vi(tag*8),vi(n));
const pb=(tag,b)=>cat(vi(tag*8+2),vi(b.length),b);
const customNames=['relva das memorias','caminho de pedra','agua do porto','tabuas do cais','telhado de cobre','parede de pedra','praca do porto','jardim de flores','farol de memoria','fragmento luminoso','arvore do veu','lembranca do porto','bolsa da memoria'];
const custom=new Map();
const extra=customNames.map((name,i)=>{
 const ground=i<10,blocked=[2,4,5,8,10].includes(i);
 const flags=cat(ground?pb(1,pv(1,150)):Buffer.alloc(0),blocked?cat(pv(13,1),pv(16,1)):Buffer.alloc(0),pv(14,i>=11?0:1),i>=11?pv(18,1):Buffer.alloc(0),i===12?pv(5,1):Buffer.alloc(0),pb(30,pv(1,[76,210,17,133,133,129,210,76,215,215,76,215,133][i])));
 const appearance=cat(pv(1,62000+i),pb(3,flags),pb(4,Buffer.from(name)),pb(5,Buffer.from('Recurso original de Entre Veus.')));
 custom.set(62000+i,{sprite:i===12?18:4+i});
 return pb(1,appearance);
});
const metadata=cat(fs.readFileSync(upstreamPath),extra);fs.writeFileSync(metadataPath,metadata);
const appearances=proto(metadata);
const objects=new Map((appearances.get(1)||[]).map(b=>{const p=proto(b);return[first(p,1),p]}));
const groundIds=[...objects].filter(([,p])=>proto(first(p,3,Buffer.alloc(0))).has(1)).map(([id])=>id);
const floorId=groundIds.find(id => {
 const flags=proto(first(objects.get(id),3,Buffer.alloc(0)));
 return id>=101 && !first(flags,13,false) && !first(flags,16,false);
});
if(!floorId)throw Error('No valid ground item');
const maxItem=Math.max(...objects.keys());
const maxOutfit=Math.max(128,...(appearances.get(2)||[]).map(b=>first(proto(b),1)));
const maxEffect=Math.max(1,...(appearances.get(3)||[]).map(b=>first(proto(b),1)));
const maxMissile=Math.max(1,...(appearances.get(4)||[]).map(b=>first(proto(b),1)));
// Hand-drawn pixel primitives: no external image or official game sprite is used.
function pixel(kind,x,y){
 const noise=(x*19+y*11+x*y*3)%13;
 const grass=[43+noise,77+noise,61+noise];
 const stone=(x%16===0||y%8===0)?[84,100,99]:[142+noise,150+noise,137+noise];
 if(kind===1||kind===4)return (x*7+y*3)%71===0?[89,130,88]:grass;
 if(kind===2)return Math.abs(x-16)+Math.abs(y-16)<6?[247,218,126]:null;
 if(kind===3||kind===16){
  if(y>27&&Math.abs(x-16)<9)return[27,39,44];
  if(y>23&&y<30&&(x===12||x===13||x===18||x===19))return[63,48,48];
  if((x-16)**2+(y-8)**2<24)return y<7?[56,45,43]:[217,180,142];
  if(y>=13&&y<=27&&Math.abs(x-16)<6+(y-13)/4)return Math.abs(x-16)>6?[38,70,90]:kind===3?[59+noise,137+noise,155+noise]:[199+noise,150+noise,70+noise];
  if(y>13&&y<24&&(x===8||x===24))return[217,180,142];
  return null;
 }
 if(kind===17){const d=(x-16)**2+(y-17)**2;if(d<28)return[213,196,251];if(d<100)return[113+noise,83+noise,169+noise];if(d<145&&noise>6)return[59,59,106];return null;}
 if(kind===5||kind===10)return stone;
 if(kind===6)return (y+x%7)%11===0?[90,167,174]:[35+noise,88+noise,113+noise];
 if(kind===7)return y%8===0||x%16===0?[67,49,41]:[142+noise,107+noise,72+noise];
 if(kind===8)return y%5===0?[67,46,47]:x%8===0?[168,100,62]:[126+noise,69+noise,53+noise];
 if(kind===9){if(x>9&&x<23&&y>6&&y<23)return x===16||y===15?[107,76,51]:[234,184,90];return stone;}
 if(kind===11){if((x-9)**2+(y-12)**2<8||(x-23)**2+(y-24)**2<8)return[202,166,194];return grass;}
 if(kind===12){if(x>8&&x<24){if(y<9)return y<3?[67,85,84]:[242,204,100];return (x===9||x===23)?[76,93,95]:stone;}return grass;}
 if(kind===13){if(Math.abs(x-16)+Math.abs(y-14)/1.5<9)return x<16?[139,219,224]:[68,158,180];return stone;}
 if(kind===14){if((x-16)**2+(y-13)**2<175)return noise>6?[61,106,68]:[40,82,57];if(y>18&&x>12&&x<20)return[111,79,50];return null;}
 if(kind===15)return Math.abs(x-16)+Math.abs(y-16)<8?[234,195,104]:null;
 if(kind===18){if(y>7&&y<29&&x>7&&x<25)return y<12?[87,60,41]:x>13&&x<19&&y<17?[225,186,104]:[148+noise,108+noise,65+noise];return null;}
 return null;
}
function sprite(kind){const chunks=[];let p=0;while(p<1024){let transparent=0;while(p<1024&&!pixel(kind,p%32,Math.floor(p/32))){transparent++;p++}let colored=0;const colors=[];while(p<1024&&pixel(kind,p%32,Math.floor(p/32))){colors.push(...pixel(kind,p%32,Math.floor(p/32)));colored++;p++}chunks.push(u16(transparent),u16(colored),Buffer.from(colors))}const pixels=cat(chunks);return cat(Buffer.from([255,0,255]),u16(pixels.length),pixels)}
const sprites=Array.from({length:18},(_,i)=>sprite(i+1));let offset=8+sprites.length*4;const offsets=sprites.map(b=>{const p=offset;offset+=b.length;return u32(p)});
const spr=cat(u32(0x45564c31),u32(sprites.length),offsets,sprites);
const defs=[];
for(let id=100;id<=maxItem;id++){
 const p=objects.get(id),flags=p?proto(first(p,3,Buffer.alloc(0))):new Map(),attrs=[];
 if(flags.has(1)){const bank=proto(first(flags,1));attrs.push(u8(0),u16(first(bank,1,150)))}
 // Presence and protocol payload flags, omitting names, graphics, sounds and market descriptions.
 const mapping=[[2,1],[3,2],[4,3],[5,4],[6,5],[8,6],[9,7],[12,11],[13,12],[14,13],[15,14],[16,15],[18,17],[19,10]];
 for(const [protoId,datId] of mapping){if(first(flags,protoId,false))attrs.push(u8(datId))}
 if(flags.has(30))attrs.push(u8(29),u16(first(proto(first(flags,30)),1)));
 attrs.push(u8(255));
 const dimensions=Buffer.from([1,1,1,1,1,1,1]);
 defs.push(cat(attrs,dimensions,u32(custom.get(id)?.sprite??(flags.has(1)?1:2))));
}
function basicDef(spriteId,creature=false){return cat(u8(255),creature?Buffer.from([1,0]):Buffer.alloc(0),Buffer.from([1,1,1,creature?4:1,1,1,1]),Array.from({length:creature?4:1},()=>u32(spriteId)))}
for(let i=1;i<=maxOutfit;i++)defs.push(basicDef(i===129?16:i===130?17:3,true));
for(let i=1;i<=maxEffect;i++)defs.push(basicDef(2));
for(let i=1;i<=maxMissile;i++)defs.push(basicDef(2));
const dat=cat(u32(0x45564c31),u16(maxItem),u16(maxOutfit),u16(maxEffect),u16(maxMissile),defs);
const things=path.join(root,'cliente/data/things/1525');fs.mkdirSync(things,{recursive:true});fs.writeFileSync(path.join(things,'Tibia.dat'),dat);fs.writeFileSync(path.join(things,'Tibia.spr'),spr);
fs.writeFileSync(path.join(things,'appearances.dat'),metadata);
// The upstream DAT compatibility loader appends this suffix to its appearances path.
fs.writeFileSync(path.join(things,'appearancesassets.json.sha256'),crypto.createHash('sha256').update(metadata).digest('hex'));
const sounds=path.join(root,'cliente/data/sounds/1525');fs.mkdirSync(sounds,{recursive:true});
fs.writeFileSync(path.join(sounds,'catalog-sound.json'),'[]\n');
function escape(b){const out=[];for(const c of b){if(c>=253)out.push(253);out.push(c)}return Buffer.from(out)}
function node(type,props=Buffer.alloc(0),children=[]){return cat(u8(254),u8(type),escape(props),children,u8(255))}
const tiles=[];const houses=[[88,92,7,6],[98,89,7,5],[108,105,7,5]];
for(let y=80;y<=120;y++)for(let x=70;x<=130;x++){
 let ground=62000;const items=[];
 if(x<83)ground=62002;
 if((y>=99&&y<=101&&x<85)||(x===82&&y>=94&&y<=105))ground=62003;
 if(x>=83&&((y>=99&&y<=101)||(x>=99&&x<=101&&y>=89&&y<=111)))ground=62001;
 if(x>=96&&x<=105&&y>=96&&y<=103)ground=62006;
 for(const [hx,hy,w,h] of houses)if(x>=hx&&x<hx+w&&y>=hy&&y<hy+h){ground=y<hy+h-1?62004:62005;if(y===hy+h-1&&x===hx+Math.floor(w/2))ground=62003;}
 if((x===94||x===106)&&y>=96&&y<=98)ground=62007;
 if(x===87&&y===99)ground=62008;
 if(x===112&&y===96)ground=62009;
 if(ground===62000&&((x*13+y*7)%67===0||x===130||y===80||y===120))items.push(node(6,u16(62010)));
 if(x===100&&y===98)ground=62006;
 const protectedTile=x<114;
 tiles.push(node(5,cat(u8(x),u8(y),u8(3),u32(protectedTile?1:0),u8(9),u16(ground)),items));
}
const mapAttrs=cat(u8(1),str('Entre Veus original laboratory map, 2026-10-02'),u8(11),str('entreveus-monster.xml'),u8(23),str('entreveus-npc.xml'),u8(13),str('entreveus-house.xml'),u8(24),str('entreveus-zones.xml'));
const mapData=node(2,mapAttrs,[node(4,cat(u16(0),u16(0),u8(7)),tiles),node(12,Buffer.alloc(0),[node(13,cat(u32(1),str('Porto da Memoria'),u16(100),u16(100),u8(7)))]),node(15)]);
const map=cat(Buffer.from('OTBM'),node(0,cat(u32(2),u16(160),u16(160),u32(3),u32(57)),[mapData]));
const world=path.join(root,'servidor/data-projeto/world');fs.mkdirSync(world,{recursive:true});fs.writeFileSync(path.join(world,'entreveus.otbm'),map);
for(const [file,tag] of [['monster','monsters'],['npc','npcs'],['house','houses'],['zones','zones']])fs.writeFileSync(path.join(world,`entreveus-${file}.xml`),`<?xml version="1.0" encoding="UTF-8"?>\n<${tag}/>\n`);
for(const folder of ['scripts','scripts/lib','monster','npc','migrations'])fs.mkdirSync(path.join(root,'servidor/data-projeto',folder),{recursive:true});
const report={purpose:'Original Porto da Memoria playable prototype',map:{width:61,height:41,tiles:tiles.length,spawn:{x:100,y:100,z:7},customIds:[62000,62012]},client:{protocol:1525,items:maxItem,outfits:maxOutfit,effects:maxEffect,missiles:maxMissile,sprites:sprites.length},provenance:{pixels:'Original pixel functions in generate-world.mjs',map:'Original Porto da Memoria layout in generate-world.mjs',metadata:'Custom entries plus pinned Canary metadata; inherited UI and metadata release audit remains pending'},sha256:{map:crypto.createHash('sha256').update(map).digest('hex'),dat:crypto.createHash('sha256').update(dat).digest('hex'),spr:crypto.createHash('sha256').update(spr).digest('hex')}};
fs.writeFileSync(path.join(root,'infra/lab-assets.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
