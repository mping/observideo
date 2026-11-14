# Codec fixtures

`mpeg4_part2_red.mp4.b64` is a 1-second, 64×64 synthetic red MPEG-4 Part 2
video generated with FFmpeg's `color` source. It contains no third-party
content. The integration test decodes it into a temporary file so the binary
does not require special patch handling.

Regenerate it with:

```sh
ffmpeg -f lavfi -i 'color=c=red:size=64x64:rate=2:duration=1' \
  -c:v mpeg4 -q:v 12 -an -y mpeg4_part2_red.mp4
base64 -i mpeg4_part2_red.mp4 > mpeg4_part2_red.mp4.b64
```

