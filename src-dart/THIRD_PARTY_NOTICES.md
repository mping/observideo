# Third-Party Notices

Observideo is distributed under GPLv3. Release bundles include Flutter,
media_kit, libmpv, FFmpeg, and their transitive dependencies. The release
pipeline must place each dependency's license text and corresponding source
offer in the application bundle.

`vendor/media_kit_video` is media_kit_video 2.0.1 (MIT, license retained in
that directory) with one Windows change: it no longer binds the ANGLE pbuffer
to a GL texture, which current ANGLE rejects. Drop the copy once upstream
ships the fix.

The controlled media runtime is built with `--enable-gpl --enable-version3`
and without `--enable-nonfree`. Every release must retain:

- `ffmpeg-build.txt`
- `ffmpeg-decoders.txt`
- `mpv-version.txt`
- `codec-manifest.json`

These generated files document the shipped configuration; they do not replace
the upstream license texts or any territory-specific codec-patent review.

