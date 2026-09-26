# Third-Party Notices

Observideo is distributed under GPLv3. Release bundles include Flutter,
media_kit, libmpv, FFmpeg, and their transitive dependencies. The release
pipeline must place each dependency's license text and corresponding source
offer in the application bundle.

The controlled media runtime is built with `--enable-gpl --enable-version3`
and without `--enable-nonfree`. Every release must retain:

- `ffmpeg-build.txt`
- `ffmpeg-decoders.txt`
- `mpv-version.txt`
- `codec-manifest.json`

These generated files document the shipped configuration; they do not replace
the upstream license texts or any territory-specific codec-patent review.

