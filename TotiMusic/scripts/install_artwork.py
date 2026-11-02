from asset_paths import asset_file, asset_output
from pathlib import Path
from PIL import Image,ImageOps
import json,shutil,hashlib

def install(name,im,ext='png'):
 im.save(asset_output(f'Assets.xcassets/{name}.imageset/{name}.{ext}'))
 asset_output(f'Assets.xcassets/{name}.imageset/Contents.json').write_text(json.dumps({'images':[{'filename':name+'.'+ext,'idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2))
names='search live shorts voice chats me settings plus close back heartOutline heartFill star starFill bookmark comment share send play pause flag block trash logout check checkbox checkboxOn clock filter refresh microphone microphoneOff microphoneIvory microphoneOffIvory speaker muted speakerIvory mutedIvory flip phone handset video gift bellOff unreadBadge diamond flower balloon music crown sparkle photo info more grid eye vinyl guitar piano drum spotlight clef equalizer ticket'.split()
atlas=Image.open(asset_file('Design/GeneratedMusic/icons.png')).convert('RGBA');w,h=atlas.size
for i,n in enumerate(names):
 col=i%8;row=i//8
 # Model output has a larger top margin and nonuniform row heights; use observed transparent gutters.
 rowEdges=[40,198,348,503,657,810,958,1088,1254]
 cell=atlas.crop((round(col*w/8),rowEdges[row],round((col+1)*w/8),rowEdges[row+1]))
 box=cell.getchannel('A').getbbox()
 if box: cell=cell.crop(box)
 cell.thumbnail((144,144),Image.Resampling.LANCZOS)
 padded=Image.new('RGBA',(168,168),(0,0,0,0));padded.alpha_composite(cell,((168-cell.width)//2,(168-cell.height)//2))
 install('TotiIcon-'+n,padded)
install('TotiIcon-heart',Image.open(asset_file('Assets.xcassets/TotiIcon-heartFill.imageset/TotiIcon-heartFill.png')))
install('TotiIcon-phrases',Image.open(asset_file('Assets.xcassets/TotiIcon-music.imageset/TotiIcon-music.png')))
mark=Image.open(asset_file('Design/GeneratedMusic/mark.png')).convert('RGB');mark=mark.resize((1024,1024),Image.Resampling.LANCZOS)
for name in ['TotiMark','TotiWordmark']:install(name,mark)
mark.save(asset_output('Assets.xcassets/AppIcon.appiconset/AppIcon.png'))
asset_output('Assets.xcassets/AppIcon.appiconset/Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2))
install('TotiEntryMusic',Image.open(asset_file('Design/GeneratedMusic/welcome.png')))
p=asset_file('Assets.xcassets/TotiLaunchBackground.colorset/Contents.json');data=json.loads(p.read_text());data['colors']=[{'idiom':'universal','color':{'color-space':'srgb','components':{'red':'1.000','green':'0.973','blue':'0.945','alpha':'1.000'}}}];asset_output('Assets.xcassets/TotiLaunchBackground.colorset/Contents.json').write_text(json.dumps(data,indent=2))
portraits=json.loads(asset_file('Design/MusicPortraits/manifest.json').read_text())
for x in portraits:
 im=Image.open(asset_file(f'Design/MusicPortraits/{x["id"]}.jpg')).convert('RGB')
 # Source photos are real. Square thumbnail cropping is only resource preparation.
 if not x['asset'].startswith('Music'): im=ImageOps.fit(im,(480,480),centering=(.5,.25))
 install(x['asset'],im,'jpg')
 x['runtimeSHA256']=hashlib.sha256(asset_file(f'Assets.xcassets/{x["asset"]}.imageset/{x["asset"]}.jpg').read_bytes()).hexdigest()
asset_output('Design/MusicPortraits/manifest.json').write_text(json.dumps(portraits,indent=2))
# Room artwork comes from distinct reviewed music recordings, with explicit provenance mappings.
roomNames=['RoomCoverHipHop','RoomCoverKPop','RoomCoverJazz','RoomCoverFreestyle','RoomCoverCamera','RoomCoverBallet','RoomCoverHouse','RoomCoverPractice']
clips=json.loads(asset_file('Design/MusicSources/manifest.json').read_text());mappings=[]
for name,item in zip(roomNames,clips):
 im=Image.open(asset_file(f'MusicMedia/{item["assetName"]}.jpg'));install(name,im,'jpg');mappings.append({'asset':name,'sourceVideoID':item['id'],'frameTime':item['inspectionTimes'][0]})
for i,name in enumerate(['RoomCoverDraft1','RoomCoverDraft2','RoomCoverDraft3','RoomCoverDraft4','LifestyleStudioPractice','LifestyleDanceRehearsal']):
 item=clips[(i+3)%len(clips)];install(name,Image.open(asset_file(f'Design/MediaReview/{item["id"]}-1.jpg')),'jpg');mappings.append({'asset':name,'sourceVideoID':item['id'],'frameTime':item['inspectionTimes'][1]})
asset_output('Design/MusicSources/photo-mappings.json').write_text(json.dumps(mappings,indent=2))
print('Generated 64-icon atlas installed; app icon, welcome art, portraits and room covers replaced. Atlas size:',atlas.size)
