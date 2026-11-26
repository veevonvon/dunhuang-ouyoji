"""Rebuild the small registration plates when an original landscape is repainted.

Run at development time with Pillow, NumPy and SciPy. The game only reads the PNGs.
From the Godot project root:
    python3 scripts/landmarks/scenic_masks/build.py --require-complete --force
    python3 scripts/landmarks/scenic_masks/build.py --site mogao --season winter --force
Red registers the sky edge, green open water and blue foliage. Each water boundary
is a hand-drawn polygon in the coordinates of its own original painting.
"""
from pathlib import Path
from io import BytesIO
import argparse
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = Path(__file__).resolve().parent
ART = HERE.parents[2] / 'assets' / 'landmarks' / 'paintings'
SIZE = (512, 288)
# Approximate height of the distant ground, from left to right. This is a soft
# colour prior. It never trims a continuous region of sky at a fixed height.
HORIZON = {
    'crescent':[.24,.21,.22,.20,.14,.13,.16,.17,.21],
    'mogao':[.23,.24,.23,.13,.24,.34,.40,.45,.49],
    'yardang':[.47,.46,.48,.40,.35,.29,.46,.44,.47],
    'yumen':[.37,.38,.36,.34,.37,.34,.35,.38,.39],
    'danxia':[.27,.25,.28,.29,.27,.24,.31,.30,.31],
    'matisi':[0,0,0,.08,.17,.31,.47,.45,.46],
    'dafosi':[.42,.34,.27,.33,.36,.4,.43,.40,.39],
    'wenmiao':[.48,.46,.42,.30,.25,.30,.45,.45,.37],
    'tiantishan':[0,0,0,.025,.15,.35,.42,.46,.49],
    'leitai':[.56,.51,.45,.40,.36,.43,.46,.50,.49],
    'poplar':[.57,.55,.53,.53,.55,.55,.54,.54,.52],
    'drum_tower':[.51,.51,.52,.24,.08,.26,.49,.53,.52],
    'jiuquan_spring':[.47,.46,.35,.27,.41,.38,.34,.32,.32],
    'jiayu_fort':[.37,.29,.40,.32,.17,.24,.40,.35,.38],
    'hanging_wall':[.14,.07,.15,.24,.23,.30,.49,.48,.49],
    'first_beacon':[.26,.25,.21,.20,.29,.31,.32,.34,.36],
    'shuangta':[.26,.24,.27,.26,.27,.29,.32,.32,.33],
    'suoyang':[.30,.29,.30,.32,.31,.33,.34,.35,.35],
    'yulin':[.18,.34,.39,.36,.31,.26,.22,.18,.15],
}
WATER = {
    'crescent': [[(.07,.47),(.14,.39),(.20,.375),(.165,.43),(.145,.5),(.22,.54),(.39,.60),(.62,.62),(.82,.61),(.957,.535),(.958,.57),(.91,.65),(.77,.699),(.55,.75),(.395,.752),(.22,.684),(.094,.587)]],
    'jiuquan_spring': [[(.22,.675),(.34,.591),(.52,.566),(.68,.585),(.791,.674),(.738,.762),(.59,.81),(.36,.797),(.237,.737)],[(.63,.429),(.99,.39),(.999,.61),(.91,.566),(.76,.515),(.65,.515)]],
    'poplar': [[(.22,.596),(.49,.593),(.67,.593),(.83,.590),(.992,.575),(.999,.943),(.86,.901),(.63,.859),(.46,.81),(.29,.797),(.18,.717)]],
}
WATER.update({
    'wenmiao': [[(.02,.73),(.14,.69),(.33,.675),(.405,.69),(.45,.655),(.49,.66),(.55,.795),(.36,.83),(.15,.856),(.044,.824)],[(.92,.69),(.998,.67),(.998,.77),(.96,.74)]],
    'first_beacon': [[(.739,.52),(.702,.57),(.674,.61),(.697,.663),(.796,.72),(.805,.765),(.763,.802),(.805,.866),(.976,.946),(.998,.932),(.89,.853),(.821,.806),(.843,.752),(.82,.705),(.735,.65),(.712,.60),(.761,.542)]],
    'yulin': [[(.367,.72),(.45,.695),(.50,.702),(.463,.741),(.51,.773),(.62,.802),(.78,.832),(.94,.884),(.998,.908),(.998,.985),(.87,.945),(.71,.90),(.574,.849),(.467,.812),(.39,.762)]],
    'tiantishan': [[(.105,.715),(.35,.705),(.59,.703),(.83,.69),(.999,.675),(.999,.976),(.76,.95),(.52,.909),(.34,.911),(.161,.846),(.164,.784)]],
    'shuangta': [[(.075,.418),(.38,.376),(.697,.349),(.998,.349),(.998,.394),(.73,.426),(.317,.463),(.239,.475),(.161,.46)],[(.177,.54),(.467,.49),(.82,.457),(.998,.457),(.998,.803),(.866,.805),(.71,.856),(.48,.813),(.263,.733),(.114,.614)]],
})
NO_FOLIAGE={'yardang','danxia'}

def smooth(a,b,v):
    t=np.clip((v-a)/(b-a),0,1)
    return t*t*(3-2*t)

def polygon(points):
    canvas=Image.new('L',SIZE)
    ImageDraw.Draw(canvas).polygon([(int(x*(SIZE[0]-1)),int(y*(SIZE[1]-1))) for x,y in points],fill=255)
    return np.asarray(canvas,dtype=float)/255

def far_ridge(rgb, affinity, prior):
    """Follow the real upper contour of a distant blue ridge beneath open sky.

    Watercolour wash and distant mountains may share hue. A smooth, locally
    supported edge path separates them using colour and pigment texture on both sides.
    """
    mean=ndimage.gaussian_filter(rgb,(1.8,1.5,0))
    pigment=np.sqrt(np.maximum(0,ndimage.gaussian_filter(rgb*rgb,(1.5,1.5,0))-ndimage.gaussian_filter(rgb,(1.5,1.5,0))**2)).mean(axis=2)
    top=np.roll(mean,3,axis=0); base=np.roll(mean,-3,axis=0)
    change=np.sqrt(((top-base)**2).sum(axis=2))
    texture=np.maximum(0,np.roll(pigment,-3,axis=0)-np.roll(pigment,3,axis=0))
    blue_before=np.roll(affinity,3,axis=0)
    height,width=affinity.shape
    ys=np.arange(height)[:,None]/height
    signal=np.clip(change/.16,0,1.7)+.48*np.clip(texture/.035,0,1.4)
    scores=signal+blue_before*.32-2.7*((ys-prior)/.12)**2
    # Discourage sudden jumps between a cloud edge and the ground at the next column.
    offsets=np.arange(-5,6)
    steps=np.zeros((height,width),np.int8)
    best=scores[:,0].copy()
    for col in range(1,width):
        scores_from=np.stack([np.roll(best,int(d))-.12*abs(d) for d in offsets])
        from_ix=np.argmax(scores_from,axis=0)
        steps[:,col]=offsets[from_ix]
        best=scores_from[from_ix,np.arange(height)]+scores[:,col]
    line=np.zeros(width,int);line[-1]=best.argmax()
    for col in range(width-1,0,-1): line[col-1]=(line[col]-steps[line[col],col])%height
    local=signal[line,np.arange(width)]
    strength=ndimage.gaussian_filter1d(smooth(.12,.55,local),3.5)
    return line,strength

def make(path, force=False):
    target=HERE/path.relative_to(ART).with_suffix('.png')
    if not force and target.exists() and target.stat().st_mtime >= max(path.stat().st_mtime,Path(__file__).stat().st_mtime): return False
    ident=path.stem
    arr=np.asarray(Image.open(path).convert('RGB').resize(SIZE,Image.Resampling.LANCZOS),dtype=float)/255
    r,g,b=arr.transpose(2,0,1)
    ys,xs=np.mgrid[:SIZE[1],:SIZE[0]]
    y=ys/SIZE[1]; x=xs/SIZE[0]
    light=.28*r+.56*g+.16*b
    blue=smooth(.012,.100,b-r)*smooth(-.020,.075,b-g)*smooth(.30,.63,light)
    heights=HORIZON[ident]
    horizon=np.interp(x,np.linspace(0,1,len(heights)),heights)
    below=y-horizon
    chroma=arr.max(axis=2)-arr.min(axis=2)
    pale=smooth(.54,.86,light)*(1-smooth(.08,.22,chroma))*smooth(-.047,.017,b-r)
    # Pale cloud pigment joins the high-saturation blues through a top-connected
    # component; blue water separated by the terrain cannot become celestial sky.
    affinity=np.maximum(blue,pale*(1-smooth(.025,.09,below)))
    possible=ndimage.gaussian_filter(affinity,.4)>.085
    labels,_=ndimage.label(possible)
    candidates=np.unique(np.r_[labels[:4].ravel(),labels[:int(SIZE[1]*.12),0],labels[:int(SIZE[1]*.12),-1]])
    connected=np.isin(labels,candidates[candidates>0])
    # Catch small real blue pinholes between crowns that do not join the top.
    holes=blue*smooth(.76,.95,blue)*(1-smooth(-.035,.08,below))
    confidence=np.maximum(connected.astype(float),holes)
    confidence*=1-.94*smooth(.025,.145,below)*(1-smooth(.24,.75,blue))
    if ident not in {'mogao','wenmiao','leitai','poplar','jiuquan_spring','yulin','crescent'}:
        ridge,strength=far_ridge(arr,affinity,horizon)
        below_ridge=ys-ridge[None,:]
        confidence*=1-strength[None,:]*smooth(-.7,2.7,below_ridge)
    sky=ndimage.gaussian_filter(confidence,.62)
    water=np.zeros_like(r)
    for poly in WATER.get(ident,[]): water=np.maximum(water,polygon(poly))
    cyan=smooth(-.065,.075,g-r)*smooth(-.22,.13,b-r)
    water=ndimage.gaussian_filter(water,1.6)*np.clip(.09+.94*cyan,0,1)
    foliage=smooth(-.095,.045,g-r)*smooth(.004,.105,g-b)*smooth(.11,.38,light)*(1-water)*(1-sky)
    if ident in NO_FOLIAGE: foliage*=0
    result=np.stack([sky,water,foliage],axis=2)
    target.parent.mkdir(parents=True,exist_ok=True)
    buffer=BytesIO()
    Image.fromarray(np.uint8(np.clip(result,0,1)*255)).save(buffer,'PNG',optimize=True)
    data=buffer.getvalue()
    if not target.exists() or data!=target.read_bytes():
        target.write_bytes(data)
        return True
    return False

def main():
    parser=argparse.ArgumentParser(description="为现场夏图和逐季原画生成注册到同机位的天空、水面、植被 RGB 掩模。")
    parser.add_argument('--site',choices=sorted(HORIZON),help='只处理指定景点，默认为19处。')
    parser.add_argument('--season',choices=('spring','summer','autumn','winter'),help='只处理指定季节，默认为四季。')
    parser.add_argument('--force',action='store_true',help='重新计算，即使输入时间戳未变。像素相同的成果保留原文件。')
    parser.add_argument('--require-complete',action='store_true',help='所选范围任一季节原画缺失时返回非零。')
    args=parser.parse_args()
    sites=[args.site] if args.site else sorted(HORIZON)
    seasons=[args.season] if args.season else ['spring','summer','autumn','winter']
    sources=[ART/('' if season=='summer' else season)/(site+'.webp') for site in sites for season in seasons]
    missing=[str(path.relative_to(ART)) for path in sources if not path.is_file()]
    if missing and (args.require_complete or (args.site and args.season)):
        parser.exit(1,'缺少季节原画：'+', '.join(missing)+'\n')
    changed=sum(make(path,args.force) for path in sources if path.is_file())
    print(f'已校验 {len(sources)-len(missing)}/{len(sources)} 张原画，更新 {changed} 张掩模。')

if __name__=='__main__': main()
