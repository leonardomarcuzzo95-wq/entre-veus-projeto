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
const appearances=proto(fs.readFileSync(path.join(root,'servidor/data/items/appearances.dat')));
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
// Three hand-coded geometric sprites: moss tile, test item, cloaked traveller.
function pixel(kind,x,y){if(kind===1){const v=(x*7+y*13)%11;return[36+v,73+v,66+v]};if(kind===2){return x>7&&x<24&&y>7&&y<24?[193,157,78]:null};if((x-16)**2+(y-8)**2<22)return[216,227,214];if(y>=13&&y<=27&&Math.abs(x-16)<(y-10)/2)return[84,149,177];return null}
function sprite(kind){const chunks=[];let p=0;while(p<1024){let transparent=0;while(p<1024&&!pixel(kind,p%32,Math.floor(p/32))){transparent++;p++}let colored=0;const colors=[];while(p<1024&&pixel(kind,p%32,Math.floor(p/32))){colors.push(...pixel(kind,p%32,Math.floor(p/32)));colored++;p++}chunks.push(u16(transparent),u16(colored),Buffer.from(colors))}const pixels=cat(chunks);return cat(Buffer.from([255,0,255]),u16(pixels.length),pixels)}
const sprites=[sprite(1),sprite(2),sprite(3)];let offset=8+sprites.length*4;const offsets=sprites.map(b=>{const p=offset;offset+=b.length;return u32(p)});
const spr=cat(u32(0x45564c31),u32(sprites.length),offsets,sprites);
const defs=[];
for(let id=100;id<=maxItem;id++){
 const p=objects.get(id),flags=p?proto(first(p,3,Buffer.alloc(0))):new Map(),attrs=[];
 if(flags.has(1)){const bank=proto(first(flags,1));attrs.push(u8(0),u16(first(bank,1,150)))}
 // Presence and protocol payload flags, omitting names, graphics, sounds and market descriptions.
 const mapping=[[2,1],[3,2],[4,3],[5,4],[6,5],[8,6],[9,7],[12,11],[13,12],[14,13],[15,14],[16,15],[18,17],[19,10]];
 for(const [protoId,datId] of mapping){if(first(flags,protoId,false))attrs.push(u8(datId))}
 attrs.push(u8(255));
 const dimensions=Buffer.from([1,1,1,1,1,1,1]);
 defs.push(cat(attrs,dimensions,u32(flags.has(1)?1:2)));
}
function basicDef(spriteId,creature=false){return cat(u8(255),creature?Buffer.from([1,0]):Buffer.alloc(0),Buffer.from([1,1,1,creature?4:1,1,1,1]),Array.from({length:creature?4:1},()=>u32(spriteId)))}
for(let i=1;i<=maxOutfit;i++)defs.push(basicDef(3,true));
for(let i=1;i<=maxEffect;i++)defs.push(basicDef(2));
for(let i=1;i<=maxMissile;i++)defs.push(basicDef(2));
const dat=cat(u32(0x45564c31),u16(maxItem),u16(maxOutfit),u16(maxEffect),u16(maxMissile),defs);
const things=path.join(root,'cliente/data/things/1511');fs.mkdirSync(things,{recursive:true});fs.writeFileSync(path.join(things,'Tibia.dat'),dat);fs.writeFileSync(path.join(things,'Tibia.spr'),spr);
const metadata=fs.readFileSync(path.join(root,'servidor/data/items/appearances.dat'));
fs.writeFileSync(path.join(things,'appearances.dat'),metadata);
// The upstream DAT compatibility loader appends this suffix to its appearances path.
fs.writeFileSync(path.join(things,'appearancesassets.json.sha256'),crypto.createHash('sha256').update(metadata).digest('hex'));
const sounds=path.join(root,'cliente/data/sounds/1511');fs.mkdirSync(sounds,{recursive:true});
fs.writeFileSync(path.join(sounds,'catalog-sound.json'),'[]\n');
function escape(b){const out=[];for(const c of b){if(c>=253)out.push(253);out.push(c)}return Buffer.from(out)}
function node(type,props=Buffer.alloc(0),children=[]){return cat(u8(254),u8(type),escape(props),children,u8(255))}
const tiles=[];for(let y=85;y<=115;y++)for(let x=85;x<=115;x++)tiles.push(node(5,cat(u8(x),u8(y),u8(3),u32(1),u8(9),u16(floorId))));
const mapAttrs=cat(u8(1),str('Entre Veus original laboratory map, 2026-10-02'),u8(11),str('entreveus-monster.xml'),u8(23),str('entreveus-npc.xml'),u8(13),str('entreveus-house.xml'),u8(24),str('entreveus-zones.xml'));
const mapData=node(2,mapAttrs,[node(4,cat(u16(0),u16(0),u8(7)),tiles),node(12,Buffer.alloc(0),[node(13,cat(u32(1),str('Porto da Memoria'),u16(100),u16(100),u8(7)))]),node(15)]);
const map=cat(Buffer.from('OTBM'),node(0,cat(u32(2),u16(160),u16(160),u32(3),u32(57)),[mapData]));
const world=path.join(root,'servidor/data-projeto/world');fs.mkdirSync(world,{recursive:true});fs.writeFileSync(path.join(world,'entreveus.otbm'),map);
for(const [file,tag] of [['monster','monsters'],['npc','npcs'],['house','houses'],['zones','zones']])fs.writeFileSync(path.join(world,`entreveus-${file}.xml`),`<?xml version="1.0" encoding="UTF-8"?>\n<${tag}/>\n`);
for(const folder of ['scripts','scripts/lib','monster','npc','migrations'])fs.mkdirSync(path.join(root,'servidor/data-projeto',folder),{recursive:true});
const report={purpose:'Local protocol and persistence test only; not final artwork',map:{width:31,height:31,tiles:tiles.length,spawn:{x:100,y:100,z:7},floorId},client:{protocol:1511,items:maxItem,outfits:maxOutfit,effects:maxEffect,missiles:maxMissile,sprites:3},provenance:{pixels:'Original geometric pixel generator in generate-lab.mjs',map:'Original generated grid in generate-lab.mjs',metadata:'Compatibility fields from pinned Canary GPL appearance metadata; release audit remains pending'},sha256:{map:crypto.createHash('sha256').update(map).digest('hex'),dat:crypto.createHash('sha256').update(dat).digest('hex'),spr:crypto.createHash('sha256').update(spr).digest('hex')}};
fs.writeFileSync(path.join(root,'infra/lab-assets.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
