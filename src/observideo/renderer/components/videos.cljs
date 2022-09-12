(ns observideo.renderer.components.videos
  (:require [clojure.string :as s]
            [promesa.core :as p]
            [reagent.core :as r]
            [re-frame.core :as rf]
            [taoensso.timbre :as log]
            [observideo.common.utils :as utils]
            [observideo.renderer.ipcrenderer :as ipcrenderer]
            [observideo.renderer.components.video-edit :as video-edit]
            [observideo.renderer.components.video-list :as video-list]
            [observideo.renderer.components.antd :as antd]
            ["electron" :as electron]))

;;;;
;; UI

(defn- show-video-panel [current]
  (if (some? current)
    video-edit/root
    video-list/root))

(defn- breadcrumbs []
  (let [folder  @(rf/subscribe [:videos/folder])
        current @(rf/subscribe [:videos/current])
        vname   (:filename current)]
    [antd/breadcrumb
     [antd/breadcrumb-item "videos"]
     [antd/breadcrumb-item
      [:a {:onClick #(rf/dispatch [:ui/deselect-video])} folder]]
     (when vname
       [antd/breadcrumb-item (utils/fname vname)])]))

(defn ui []
  (let [current @(rf/subscribe [:videos/current])]
    [:div
     [breadcrumbs]
     [(show-video-panel current)]]))
