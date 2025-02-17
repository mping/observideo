# Observideo
ClojureScript + Shadow-cljs + Electron + re-frame

## What

Video annotation software: define a template, load your videos and then and annotate blocks of <X> seconds, then download as csv. You can also query your videos for specific annotations.

[image](https://user-images.githubusercontent.com/88425/226198981-b54abd57-3456-46bf-ba51-938bcd44c08c.png)


## Who

Software developed with guidance from with Dra. Guida Veiga, Phd from University of Évora (orcid: https://orcid.org/0000-0002-0575-1757).

## How to Run

```shell
npm i --legacy-peer-deps

sudo chown root:root node_modules/electron/dist/chrome-sandbox
sudo chmod 4755 node_modules/electron/dist/chrome-sandbox

npm run dev
# on another shell
./node_modules/.bin/electron .
```

On the electron window, press `Ctrl+H` to view `re-frame-10x` console.

## Release
```
npm run build
npm run dist-mwl
```

## building locally on win|linux

```
docker run --rm -ti \ --env ELECTRON_CACHE="/root/.cache/electron" \
--env ELECTRON_BUILDER_CACHE="/root/.cache/electron-builder" \
-v ${PWD}:/project \
 -v ${PWD##*/}-node-modules:/project/node_modules \
 -v ~/.cache/electron:/root/.cache/electron \
 -v ~/.cache/electron-builder:/root/.cache/electron-builder \
 electronuserland/builder:wine
```

then you can build (requires java) and dist:
```
npm run build
npm run dist -wl
```

## REPL

```
(:require
 '[shadow.cljs.devtools.api :as shadow])
(shadow/repl :renderer)
```

## Release via GH actions
```
<update package.json>
git commit -am "v0.1.2"
git tag v0.1.2
git p --tags 
```
