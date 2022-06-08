(ns observideo.renderer.core
  (:require [reagent.core :as reagent]
            [re-frame.core :as rf]
            [goog.object :as gobj]
            [devtools.core :as devtools]
            [observideo.renderer.views :refer [ui]]
            [observideo.renderer.subs]
            [observideo.renderer.events]
            [observideo.renderer.ipcrenderer :as ipc]
            [observideo.renderer.ipcrenderer :as ipcrenderer]
            ["electron" :as electron :refer [ipcRenderer]]))


;; (devtools/install!)       ;; we love https://github.com/binaryage/cljs-devtools
(enable-console-print!)

(def ipcRenderer (gobj/get electron "ipcRenderer"))
(def dom-root (js/document.getElementById "app"))
;; -- Entry Point -------------------------------------------------------------


(defn ^:export init []
  (rf/dispatch-sync [:db/initialize])
  (reagent/render [observideo.renderer.views/ui]
                  dom-root)
  (rf/dispatch [:ui/ready])
  (.on ipcRenderer "event" ipc/handle-message))

(defn ^:dev/after-load start []
  (println "START!")
  (reagent/render [observideo.renderer.views/ui] dom-root))

(init)
