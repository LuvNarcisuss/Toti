from asset_paths import asset_output
from pathlib import Path
import json,subprocess,concurrent.futures
root=Path(__file__).resolve().parents[1]
photos=[(16002543,'Alexander Krivitskiy','Portrait7'),(18762059,'Weavehall Collective','MusicStudioBackdrop'),(17815329,'Göksu Taymaz','MusicPianoRoom'),(8132809,'Anna Pou','MusicProductionRoom'),(1165720,'Min An','Portrait1'),(20319703,'Yusuf Çelik','Portrait2'),(18095046,'Oss Leos','Portrait3'),(9759917,'Ron Lach','Portrait4'),(11900129,'Tamara Elnova','Portrait5'),(7773876,'Artem Podrez','Portrait6'),(28736497,'Jean Marc Bonnel','Portrait8')]
def get(row):
 id,author,asset=row;url=f'https://images.pexels.com/photos/{id}/pexels-photo-{id}.jpeg?auto=compress&cs=tinysrgb&w=640'
 p=asset_output(f'Design/MusicPortraits/{id}.jpg');r=subprocess.run(['curl','-L','--fail','--silent','--max-time','40',url,'-o',str(p)])
 if r.returncode: return None
 print('PHOTO',id,flush=True);return dict(id=id,author=author,asset=asset,downloadURL=url,sourceURL=f'https://www.pexels.com/photo/{id}/',license='Pexels License',licenseURL='https://www.pexels.com/license/',identityNote='Fictional profile artwork; photographed subjects are not represented as actual app accounts or endorsers. Nationality is not inferred from appearance.')
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:r=list(pool.map(get,photos))
asset_output('Design/MusicPortraits/manifest.json').write_text(json.dumps([x for x in r if x],indent=2))
