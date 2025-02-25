(ns observideo.renderer.chromajs
 (:require ["chroma-js" :as chromajs]))

(defn scale [total]
  ;;chroma.scale(['#fafa6e', '#2A4858']) .mode('lch').colors(6)
  (-> (.scale chromajs (clj->js ["#fafa6e" "#2A4858"]))
      (.mode "lch")
      (.colors total)))
