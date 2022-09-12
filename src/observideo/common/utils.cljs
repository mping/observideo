(ns observideo.common.utils
  (:require [clojure.string :as s]
            ["path" :as path]))

(def separator (.-sep path))

(defn fname
  [p]
  (.basename path p))
  ;(subs path (inc (s/last-index-of path sep)))))

(defn relname [basedir p]
  (subs p (inc (count basedir))))

