# Observideo
ClojureScript + Shadow-cljs + Electron + re-frame

## What

Video annotation software: define a template, load your videos and then and annotate blocks of <X> seconds, then download as csv. You can also query your videos for specific annotations.

screenshot.png![image](https://user-images.githubusercontent.com/88425/226198981-b54abd57-3456-46bf-ba51-938bcd44c08c.png)

### macOS

On macOS, you might need to un-quarantine the `.dmg` file:

```shell
xattr -d com.apple.quarantine observideo-0.2.5-arm64.dmg
```

## Who

Software developed with guidance from with Dra. Guida Veiga, Phd from University of Évora (orcid: https://orcid.org/0000-0002-0575-1757).

## How to Run
```
yarn global add electron
yarn global add shadow-cljs
yarn install

yarn run dev

# on another shell
yarn start
```
On the electron window, press `Ctrl+H` to view `re-frame-10x` console.

## Release
```
yarn build
yarn dist-mwl ;; or yarn dist
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
yarn build
yarn dist -wl
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
