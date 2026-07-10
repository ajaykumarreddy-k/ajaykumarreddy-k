import re
import os

def replace_svg_info(filename):
    filepath = os.path.join('/home/prince/Downloads/trying new/Andrew6rant-main', filename)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_text = """<tspan x="390" y="30">ajay@kumar-reddy-k</tspan> -———————————————————————————————————————————-—-
<tspan x="390" y="50" class="cc">. </tspan><tspan class="key">OS</tspan>:<tspan class="cc"> .............................. </tspan><tspan class="value">Ubuntu, Windows</tspan>
<tspan x="390" y="70" class="cc">. </tspan><tspan class="key">Education</tspan>:<tspan class="cc"> ............. </tspan><tspan class="value">B.Tech CSE @ SRM IST Ramapuram</tspan>
<tspan x="390" y="90" class="cc">. </tspan><tspan class="key">Role</tspan>:<tspan class="cc"> ......................... </tspan><tspan class="value">Design Lead @ SLUGnPLUG</tspan>
<tspan x="390" y="110" class="cc">. </tspan><tspan class="key">Focus</tspan>:<tspan class="cc"> ....................... </tspan><tspan class="value">AI, LLMs, RAG &amp; Automation</tspan>
<tspan x="390" y="130" class="cc">. </tspan><tspan class="key">Tools</tspan>:<tspan class="cc"> ............................... </tspan><tspan class="value">Docker, Git, Figma</tspan>
<tspan x="390" y="150" class="cc">. </tspan>
<tspan x="390" y="170" class="cc">. </tspan><tspan class="key">Languages</tspan>.<tspan class="key">Programming</tspan>:<tspan class="cc"> ..... </tspan><tspan class="value">Python, TS, JS, Kotlin, C++</tspan>
<tspan x="390" y="190" class="cc">. </tspan><tspan class="key">Frameworks</tspan>.<tspan class="key">AI/ML</tspan>:<tspan class="cc"> ........ </tspan><tspan class="value">PyTorch, TensorFlow, Scikit-Learn</tspan>
<tspan x="390" y="210" class="cc">. </tspan><tspan class="key">Languages</tspan>.<tspan class="key">Real</tspan>:<tspan class="cc"> ........... </tspan><tspan class="value">Telugu, English, Hindi, Tamil, French</tspan>
<tspan x="390" y="230" class="cc">. </tspan>
<tspan x="390" y="250" class="cc">. </tspan><tspan class="key">Interests</tspan>.<tspan class="key">Tech</tspan>:<tspan class="cc"> ......... </tspan><tspan class="value">Building AI Products, Full-Stack Apps</tspan>
<tspan x="390" y="270" class="cc">. </tspan><tspan class="key">Interests</tspan>.<tspan class="key">Design</tspan>:<tspan class="cc"> ....... </tspan><tspan class="value">UI/UX Design Systems</tspan>
<tspan x="390" y="310">- Contact</tspan> -——————————————————————————————————————————————-—-
<tspan x="390" y="330" class="cc">. </tspan><tspan class="key">Portfolio</tspan>:<tspan class="cc"> ............... </tspan><tspan class="value">AjayKumarReddyK.github.io</tspan>
<tspan x="390" y="350" class="cc">. </tspan><tspan class="key">Email</tspan>:<tspan class="cc"> ................... </tspan><tspan class="value">ajay@example.com</tspan>
<tspan x="390" y="370" class="cc">. </tspan><tspan class="key">LinkedIn</tspan>:<tspan class="cc"> ................ </tspan><tspan class="value">AjayKumarReddyK</tspan>
<tspan x="390" y="390" class="cc">. </tspan><tspan class="key">GitHub</tspan>:<tspan class="cc"> .................. </tspan><tspan class="value">AjayKumarReddyK</tspan>"""

    start_str = '<tspan x="390" y="30">andrew@grant</tspan>'
    end_str = '<tspan x="390" y="450">- GitHub Stats</tspan>'
    
    start_idx = content.find(start_str)
    end_idx = content.find(end_str)
    
    if start_idx != -1 and end_idx != -1:
        updated = content[:start_idx] + new_text + "\n" + content[end_idx:]
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(updated)
        print(f"Updated {filename}")
    else:
        print(f"Failed to find boundaries in {filename}")

replace_svg_info('dark_mode.svg')
replace_svg_info('light_mode.svg')
