import json, struct, sys, io
from PIL import Image

src = r'D:\DEV\portfolio-02\public\models\unitychan\sd_unitychan.glb'
dst = r'D:\DEV\portfolio-02\godot\assets\models\unitychan\sd_unitychan.glb'

with open(src, 'rb') as f:
    data = f.read()

magic, version, length = struct.unpack_from('<4sII', data, 0)
assert magic == b'glTF', magic
offset = 12
json_chunk = None
bin_chunk = None
while offset < length:
    chunk_len, chunk_type = struct.unpack_from('<II', data, offset)
    chunk_data = data[offset+8:offset+8+chunk_len]
    if chunk_type == 0x4E4F534A:
        json_chunk = chunk_data
    elif chunk_type == 0x004E4942:
        bin_chunk = chunk_data
    offset += 8 + chunk_len

gltf = json.loads(json_chunk.rstrip(b' \t\r\n\x00').decode('utf-8'))
print('extensionsUsed', gltf.get('extensionsUsed'))
print('textures', json.dumps(gltf.get('textures'), indent=1)[:1000])
print('images', gltf.get('images'))

# Extract the embedded WebP image.
img = gltf['images'][0]
bv = gltf['bufferViews'][img['bufferView']]
start = bv.get('byteOffset', 0)
end = start + bv['byteLength']
webp_bytes = bin_chunk[start:end]
image = Image.open(io.BytesIO(webp_bytes))
print('image', image.format, image.mode, image.size)
out = io.BytesIO()
image.save(out, format='PNG', optimize=True)
png_bytes = out.getvalue()

# Append PNG to the binary chunk, aligned to 4 bytes.
while len(bin_chunk) % 4:
    bin_chunk += b'\x00'
png_offset = len(bin_chunk)
bin_chunk += png_bytes
while len(bin_chunk) % 4:
    bin_chunk += b'\x00'

gltf['bufferViews'].append({
    'buffer': 0,
    'byteOffset': png_offset,
    'byteLength': len(png_bytes),
})
gltf['images'][0] = {
    'bufferView': len(gltf['bufferViews']) - 1,
    'mimeType': 'image/png',
}
gltf['buffers'][0]['byteLength'] = len(bin_chunk)

# EXT_texture_webp puts the source in a texture extension; move it to the core field.
for texture in gltf.get('textures', []):
    ext = texture.get('extensions', {}).pop('EXT_texture_webp', None)
    if ext and 'source' not in texture:
        texture['source'] = ext['source']
    if not texture.get('extensions'):
        texture.pop('extensions', None)
gltf['extensionsUsed'] = [e for e in gltf.get('extensionsUsed', []) if e != 'EXT_texture_webp']
gltf['extensionsRequired'] = [e for e in gltf.get('extensionsRequired', []) if e != 'EXT_texture_webp']
if not gltf['extensionsUsed']:
    gltf.pop('extensionsUsed', None)
if not gltf['extensionsRequired']:
    gltf.pop('extensionsRequired', None)

new_json = json.dumps(gltf, separators=(',', ':')).encode('utf-8')
while len(new_json) % 4:
    new_json += b' '
while len(bin_chunk) % 4:
    bin_chunk += b'\x00'
total = 12 + 8 + len(new_json) + 8 + len(bin_chunk)
with open(dst, 'wb') as f:
    f.write(struct.pack('<4sII', b'glTF', 2, total))
    f.write(struct.pack('<II', len(new_json), 0x4E4F534A))
    f.write(new_json)
    f.write(struct.pack('<II', len(bin_chunk), 0x004E4942))
    f.write(bin_chunk)
print('wrote', dst, total)
