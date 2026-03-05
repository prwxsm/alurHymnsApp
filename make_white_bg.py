from PIL import Image

try:
    img = Image.open('assets/final_icon.png').convert('RGBA')
    white_bg = Image.new('RGBA', img.size, (255, 255, 255, 255))
    white_bg.paste(img, (0, 0), img)
    # Give it a tiny bit of padding since it's going to be adaptive
    margin = int(img.width * 0.1)
    padded = Image.new('RGBA', (img.width + margin*2, img.height + margin*2), (255, 255, 255, 255))
    padded.paste(white_bg, (margin, margin))
    padded.convert('RGB').save('assets/final_icon_solid.png', 'PNG')
    # Save a non-padded solid version for the drawer
    white_bg.convert('RGB').save('assets/final_icon_drawer.png', 'PNG')
    print("Successfully created solid white background logo")
except Exception as e:
    print(f"Error: {e}")
