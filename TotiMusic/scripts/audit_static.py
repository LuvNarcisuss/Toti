"""Inspect files and metadata only. Does not compile, typecheck, launch or test application behavior."""
from pathlib import Path
from tempfile import TemporaryDirectory
from asset_paths import ASSETS, asset_file
from prepare_asset_catalog import generate_catalog
import json,plistlib,re,hashlib,subprocess,xml.etree.ElementTree as ET
from PIL import Image
r=Path(__file__).resolve().parents[1];src=r/'Toti';issues=[];checks={}
catalog_tmp=TemporaryDirectory(prefix='toti-static-catalog-');assets=Path(catalog_tmp.name)/'FlatAssets.xcassets'
generate_catalog(ASSETS,r/'Configuration/AssetCatalog.json',assets)
def note(condition,message):
 if not condition:issues.append(message)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
note(not any(p.is_dir() for p in ASSETS.iterdir()),'Source Assets must contain files only')
jsons=list(r.rglob('*.json'))+list((r.parent/'Assets').rglob('*.json'))
for p in jsons:
 try:json.loads(p.read_text())
 except Exception as e:issues.append(str(p.relative_to(r.parent))+': '+str(e))
checks['jsonFilesParsed']=len(jsons)
for p in src.rglob('*.plist'):plistlib.loads(p.read_bytes())
scheme=r/'Toti.xcodeproj/xcshareddata/xcschemes/toti.xcscheme';ET.parse(scheme)
checks['sharedScheme']='toti'
for p in assets.rglob('Contents.json'):
 d=json.loads(p.read_text())
 for image in d.get('images',[]):
  if 'filename' in image:
   f=p.parent/image['filename'];note(f.exists(),'Missing asset '+str(f))
   if f.exists():
    if f.suffix.lower()==".svg": ET.parse(f)
    else: Image.open(f).verify()
checks['assetCatalogs']=len(list(assets.rglob('Contents.json')))
text='\n'.join(p.read_text() for p in src.rglob('*.swift'))
names={p.stem for p in assets.iterdir()}
literals=set(re.findall(r'UIImage\(named:\s*"([^"\\]+)"',text))
for n in literals - {"TotiIcon-"}:note(n in names,'Missing literal image '+n)
icon=(src/'DesignSystem/TotiIcons.swift').read_text();cases=[]
for line in icon.splitlines():
 if line.strip().startswith('case '):cases+=line.strip()[5:].split(', ')
for n in cases:note('TotiIcon-'+('back' if n=='forward' else n) in names,'Missing icon '+n)
checks['iconCasesResolved']=len(cases)
for p in assets.glob('TotiIcon-*.imageset/TotiIcon-*.png'):
 im=Image.open(p).convert('RGBA');box=im.getchannel('A').getbbox()
 note(box is not None and box[0]>=10 and box[1]>=10 and box[2]<=im.width-10 and box[3]<=im.height-10,'Icon padding missing '+p.parent.name)
checks['exportedIconPadding']='All generated exported silhouettes have transparent padding'

media=json.loads(asset_file('Design/MusicSources/manifest.json').read_text());checks['videoCount']=len(media);checks['liveCount']=sum(x['surface']=='live' for x in media);checks['shortsCount']=sum(x['surface']=='shorts' for x in media)
for key in ['uuid','assetName','runtimeSHA256']:note(len({x[key] for x in media})==len(media),'Duplicate video '+key)
for x in media:
 f=asset_file(f'MusicMedia/{x["assetName"]}.mp4');cover=f.with_suffix('.jpg');note(digest(f)==x['runtimeSHA256'],'Video hash mismatch '+x['assetName']);note(digest(cover)==x['coverSHA256'],'Cover hash mismatch '+x['assetName'])
 info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(f)]));note(abs(float(info['format']['duration'])-x['duration'])<.1,'Duration changed '+x['assetName']);note(sum(v['codec_type']=='audio' for v in info['streams'])==x['audioTracks'],'Audio mapping mismatch')
 note(len(x['inspectionTimes'])==3 and 'visualReview' in x,'Missing frame review')
checks['silentRecordings']=sum(x['audioTracks']==0 for x in media)
photos=json.loads(asset_file('Design/current-photography.json').read_text())
for x in photos:
 d=assets/(x['asset']+'.imageset');c=json.loads((d/'Contents.json').read_text());f=d/next(v['filename'] for v in c['images'] if 'filename' in v);note(digest(f)==x['runtimeSHA256'],'Photo hash mismatch '+x['asset'])
checks['photographyRecords']=len(photos);checks['newPhotographyRecords']=len(json.loads(asset_file('Design/MusicPortraits/manifest.json').read_text()))
for key in ['savedDemoVideoIDs','isDance','danceCategory']:note(key in (src/'Domain/LocalLibrary.swift').read_text(),'Missing compatibility key '+key)
for illegal in ['import SwiftUI','UIHostingController','UIImage(systemName:','com.teto.dance','18781461148@163.com','1PBHnF3UNjCBkEuzOyETCUOWgMEz4eiPfGj_PooGJM4c','hoewtkchclzkuruf']:note(illegal not in text,'Forbidden active source '+illegal)
note(not list(src.rglob('*.m')),'Objective-C source');note(not (src/'Resources/DanceMedia').exists(),'Old dance videos remain')
pbx=(r/'Toti.xcodeproj/project.pbxproj').read_text();note('com.toti.music' in pbx,'Bundle identity missing');note('IPHONEOS_DEPLOYMENT_TARGET = 16.0' in pbx,'Deployment target missing');note('SWIFT_VERSION = 5.0' in pbx,'Swift mode missing');note('DEVELOPMENT_TEAM' not in pbx,'Inherited signing team');note('MediaCreditsController.swift' in pbx,'New controller excluded');note('MediaCredits.json' in pbx,'Credits resource excluded')
app=(src/'App/TotiApplication.swift').read_text();note(all(label in app for label in ['"Lounge"', '"Voice"', '"Notebook"', '"Chats"', '"Me"']),'Five-tab identity changed')
checks['swiftFiles']=len(list(src.rglob('*.swift')));checks['runtimeResourceBytes']=sum(p.stat().st_size for p in assets.rglob('*') if p.is_file()) + sum((ASSETS/name).stat().st_size for name in ['TetoRhythm-Display.ttf','TetoRhythm-Text.ttf','TermsOfService.html','PrivacyPolicy.html','MediaCredits.json'])
checks['verificationScope']='Static source/resource/configuration inspection only; no build, typecheck, app execution or tests.'
report={'date':'2026-10-26','checks':checks,'issues':issues}
(r/'docs/static-audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));raise SystemExit(bool(issues))
