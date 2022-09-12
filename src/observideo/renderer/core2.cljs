(ns observideo.renderer.core2
  (:require [reagent.core :refer [atom]]
            [reagent.dom :as rd]
            [reagent.core :as reagent]
            [re-frame.core :as rf]
            [goog.object :as gobj]
            [devtools.core :as devtools]
            [observideo.renderer.views :refer [ui]]
            [observideo.renderer.subs]
            [observideo.renderer.events]
            [observideo.renderer.ipcrenderer :as ipc]
            [observideo.renderer.ipcrenderer :as ipcrenderer]
            ["electron" :as electron :refer [ipcRenderer]]))

(enable-console-print!)

(defonce state (atom 0))

(defn root-component []
  [:div
   [:div.logos
    [:img.electron {:src "img/electron-logo.png"}]
    [:img.cljs {:src "img/cljs-logo.svg"}]
    [:img.reagent {:src "img/reagent-logo.png"}]]
   [:button
    {:on-click #(swap! state inc)}
    (str "Clicked " @state " times")]])

(defn ^:dev/after-load start! []
  (rd/render
    [root-component]
    (js/document.getElementById "app")))
