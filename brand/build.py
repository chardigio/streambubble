import pathlib
import re

P = pathlib.Path(__file__).parent
sq = (P / "squircle.path").read_text().strip()
svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
 <path id="sq" d="{sq}"/>
 <clipPath id="sqc"><use href="#sq"/></clipPath>
 <linearGradient id="bg" x1="0" y1="0" x2="0.35" y2="1">
  <stop offset="0" stop-color="#FF9D5C"/><stop offset="0.5" stop-color="#F8504A"/><stop offset="1" stop-color="#C81E55"/></linearGradient>
 <radialGradient id="bgglow" cx="0.3" cy="0.15" r="0.7"><stop offset="0" stop-color="#FFE7C2" stop-opacity="0.45"/><stop offset="1" stop-color="#FFF4DD" stop-opacity="0"/></radialGradient>
 <filter id="drop" x="-20%" y="-20%" width="140%" height="150%"><feGaussianBlur in="SourceAlpha" stdDeviation="12"/><feOffset dy="14"/><feComponentTransfer><feFuncA type="linear" slope="0.38"/></feComponentTransfer></filter>
 <filter id="soft" x="-30%" y="-30%" width="160%" height="170%"><feGaussianBlur stdDeviation="22"/></filter>
 <filter id="soft8"><feGaussianBlur stdDeviation="8"/></filter>
 <filter id="blur3"><feGaussianBlur stdDeviation="3"/></filter>
 <linearGradient id="glass" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.92"/><stop offset="1" stop-color="#FFF4EF" stop-opacity="0.78"/></linearGradient>
 <linearGradient id="glassEdge" x1="0" y1="0" x2="0.6" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="1"/><stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0.35"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0.8"/></linearGradient>
 <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.75"/><stop offset="0.25" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="0.85" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0.35"/></linearGradient>
 <radialGradient id="lensbg" cx="0.5" cy="0.35" r="0.75"><stop offset="0" stop-color="#2E8C92"/><stop offset="1" stop-color="#0B2E3A"/></radialGradient>
 <radialGradient id="skin" cx="0.4" cy="0.35" r="0.75"><stop offset="0" stop-color="#FFE0C4"/><stop offset="1" stop-color="#E9A57C"/></radialGradient>
 <linearGradient id="shirt" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFD27A"/><stop offset="1" stop-color="#F29A3E"/></linearGradient>
 <linearGradient id="ring" x1="0.15" y1="0" x2="0.85" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="0.55" stop-color="#FFF1EE"/><stop offset="1" stop-color="#F4B9C2"/></linearGradient>
 <radialGradient id="spec" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.9"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>
 <linearGradient id="caustic" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7FF3E8" stop-opacity="0"/><stop offset="1" stop-color="#9FFFF2" stop-opacity="0.55"/></linearGradient>
 <clipPath id="lens"><circle cx="{{BX}}" cy="{{BY}}" r="{{LR}}"/></clipPath>
 <clipPath id="scr"><rect x="{{SX}}" y="{{SY}}" width="{{SW}}" height="{{SH}}" rx="{{SR}}"/></clipPath>
</defs>
<use href="#sq" filter="url(#drop)"/>
<g clip-path="url(#sqc)">
 <use href="#sq" fill="url(#bg)"/>
 <rect width="1024" height="1024" fill="url(#bgglow)"/>
 <!-- screen shadow -->
 <rect x="{{SX}}" y="{{SY+22}}" width="{{SW}}" height="{{SH}}" rx="{{SR}}" fill="#8A1032" opacity="0.35" filter="url(#soft)"/>
 <!-- screen glass -->
 <rect x="{{SX}}" y="{{SY}}" width="{{SW}}" height="{{SH}}" rx="{{SR}}" fill="url(#glass)"/>
 <g clip-path="url(#scr)">
  <rect x="{{SX}}" y="{{SY}}" width="{{SW}}" height="64" fill="#FFFFFF" opacity="0.55"/>
  <circle cx="{{SX+44}}" cy="{{SY+32}}" r="11" fill="#FF5F57"/><circle cx="{{SX+80}}" cy="{{SY+32}}" r="11" fill="#FEBC2E"/><circle cx="{{SX+116}}" cy="{{SY+32}}" r="11" fill="#28C840"/>
  <rect x="{{SX+44}}" y="{{SY+104}}" width="250" height="26" rx="13" fill="#E0425E" opacity="0.85"/>
  <rect x="{{SX+44}}" y="{{SY+150}}" width="360" height="18" rx="9" fill="#B8435E" opacity="0.32"/>
  <rect x="{{SX+44}}" y="{{SY+184}}" width="300" height="18" rx="9" fill="#B8435E" opacity="0.32"/>
  <rect x="{{SX+44}}" y="{{SY+236}}" width="200" height="120" rx="20" fill="#FF7A50" opacity="0.55"/>
 </g>
 <rect x="{{SX+8}}" y="{{SY+SH-30}}" width="{{SW-16}}" height="22" rx="11" fill="#FFFFFF" opacity="0.35" filter="url(#soft8)"/>
 <rect x="{{SX+2}}" y="{{SY+2}}" width="{{SW-4}}" height="{{SH-4}}" rx="{{SR-2}}" fill="none" stroke="url(#glassEdge)" stroke-width="4"/>
 <!-- bubble shadow -->
 <circle cx="{{BX}}" cy="{{BY+30}}" r="{{RR}}" fill="#5A0620" opacity="0.5" filter="url(#soft)"/>
 <!-- ring (record.circle ring): a glass torus with a clear gap to the lens -->
 <mask id="ringm"><circle cx="{{BX}}" cy="{{BY}}" r="{{RR}}" fill="#fff"/><circle cx="{{BX}}" cy="{{BY}}" r="{{RI}}" fill="#000"/></mask>
 <g mask="url(#ringm)">
  <circle cx="{{BX}}" cy="{{BY}}" r="{{RR}}" fill="url(#ring)"/>

  <path d="M{{BX-RR+16}},{{BY+30}} A{{RR-16}},{{RR-16}} 0 0 1 {{BX+30}},{{BY-RR+16}}" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round"/>
  <path d="M{{BX+RR-16}},{{BY+10}} A{{RR-16}},{{RR-16}} 0 0 1 {{BX+10}},{{BY+RR-16}}" fill="none" stroke="#C8405E" stroke-width="10" stroke-linecap="round" opacity="0.25" filter="url(#blur3)"/>
 </g>
 <circle cx="{{BX}}" cy="{{BY}}" r="{{RR-1.5}}" fill="none" stroke="#FFFFFF" stroke-width="3"/>
 <circle cx="{{BX}}" cy="{{BY}}" r="{{RI+1}}" fill="none" stroke="#D0546E" stroke-width="2" opacity="0.5"/>
 <circle cx="{{BX}}" cy="{{BY+14}}" r="{{LR}}" fill="#5A0620" opacity="0.45" filter="url(#soft8)"/>
 <!-- lens (filled dot) with face -->
 <g clip-path="url(#lens)">
  <circle cx="{{BX}}" cy="{{BY}}" r="{{LR}}" fill="url(#lensbg)"/>
  <path d="M{{BX-150}},{{BY+LR+10}} C{{BX-150}},{{BY+60}} {{BX-80}},{{BY+40}} {{BX}},{{BY+40}} C{{BX+80}},{{BY+40}} {{BX+150}},{{BY+60}} {{BX+150}},{{BY+LR+10}} Z" fill="url(#shirt)"/>
  <rect x="{{BX-26}}" y="{{BY+5}}" width="52" height="45" rx="18" fill="#E39C74"/>
  <ellipse cx="{{BX}}" cy="{{BY-40}}" rx="70" ry="78" fill="url(#skin)"/>
  <path d="M{{BX-72}},{{BY-24}} C{{BX-88}},{{BY-118}} {{BX-30}},{{BY-144}} {{BX+8}},{{BY-140}} C{{BX+66}},{{BY-136}} {{BX+90}},{{BY-90}} {{BX+72}},{{BY-24}} C{{BX+66}},{{BY-50}} {{BX+56}},{{BY-66}} {{BX+40}},{{BY-74}} C{{BX+6}},{{BY-70}} {{BX-30}},{{BY-82}} {{BX-52}},{{BY-98}} C{{BX-60}},{{BY-70}} {{BX-66}},{{BY-48}} {{BX-72}},{{BY-24}} Z" fill="#3A2420"/>
  <circle cx="{{BX-24}}" cy="{{BY-36}}" r="7" fill="#3A2420"/><circle cx="{{BX+24}}" cy="{{BY-36}}" r="7" fill="#3A2420"/>
  <path d="M{{BX-24}},{{BY-6}} Q{{BX}},{{BY+14}} {{BX+24}},{{BY-6}}" fill="none" stroke="#9A4A3A" stroke-width="7" stroke-linecap="round"/>
  <!-- glass lens effects -->
  <rect x="{{BX-LR}}" y="{{BY}}" width="{{2*LR}}" height="{{LR}}" fill="url(#caustic)" opacity="0.6"/>
  <ellipse cx="{{BX-60}}" cy="{{BY-LR+46}}" rx="120" ry="48" fill="url(#spec)" opacity="0.75" transform="rotate(-24 {{BX-60}} {{BY-LR+46}})"/>
  <circle cx="{{BX}}" cy="{{BY}}" r="{{LR}}" fill="none" stroke="#06202A" stroke-width="10" opacity="0.45" filter="url(#blur3)"/>
 </g>
 <circle cx="{{BX}}" cy="{{BY}}" r="{{LR}}" fill="none" stroke="#FFFFFF" stroke-width="2" opacity="0.6"/>
 <!-- small red REC dot on screen -->
 <circle cx="{{SX+SW-50}}" cy="{{SY+32}}" r="14" fill="#FF2D46"/>
 <!-- liquid-glass rim light on the squircle -->
 <use href="#sq" fill="none" stroke="url(#rim)" stroke-width="6"/>
</g>
</svg>"""
V = dict(SX=160, SY=200, SW=600, SH=420, SR=54, BX=660, BY=660, RR=236, RI=204, LR=180)


def ev(m):
    return str(eval(m.group(1), {}, V))


svg = re.sub(r"\{([A-Z0-9+\-*/ ]+)\}", ev, svg)
(P / "app-icon.svg").write_text(svg + "\n")
