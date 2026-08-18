import sys
try:
    from PIL import Image
except ImportError:
    print("Please install Pillow by running: pip install Pillow")
    sys.exit(1)
import re

def get_ascii_image(image_path, new_width=45, new_height=25):
    try:
        image = Image.open(image_path)
    except Exception as e:
        print(f"Error opening image: {e}")
        return None

    image = image.convert('L')
    
    # We want a 45x25 character grid to fit perfectly in the SVG
    image = image.resize((new_width, new_height))
    
    # Brightness mapping, space for the darkest so background is transparent
    chars = [" ", " ", ".", ":", "-", "=", "+", "*", "#", "%", "@"]
    
    pixels = image.getdata()
    ascii_str = ""
    for pixel_val in pixels:
        ascii_str += chars[pixel_val * len(chars) // 256]
        
    ascii_lines = [ascii_str[index: index + new_width] for index in range(0, len(ascii_str), new_width)]
    
    tspan_lines = []
    y = 30
    for line in ascii_lines:
        # Escape characters for SVG
        safe_line = line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        tspan_lines.append(f'<tspan x="15" y="{y}">{safe_line}</tspan>')
        y += 20
        
    return "\n".join(tspan_lines)

def replace_in_svg(svg_path, tspan_content):
    with open(svg_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    pattern = re.compile(r'(<text[^>]*class="ascii"[^>]*>\n)(.*?)(</text>)', re.DOTALL)
    
    def replacer(match):
        return match.group(1) + tspan_content + "\n" + match.group(3)
        
    new_content = pattern.sub(replacer, content)
    
    with open(svg_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"Updated {svg_path}")

def main():
    print("Generating ASCII art from image.jpeg...")
    ascii_content = get_ascii_image('image.jpeg')
    if not ascii_content:
        return
        
    replace_in_svg('dark_mode.svg', ascii_content)
    replace_in_svg('light_mode.svg', ascii_content)
    print("Done! You can now commit and push the SVG changes.")

if __name__ == '__main__':
    main()
