# Observideo
ClojureScript + Shadow-cljs + Electron + re-frame

## How to Run
```
yarn install electron -g
yarn install shadow-cljs -g
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