(ns observideo.common.utils
  (:require [clojure.string :as s]
            ["path" :as path]))

(def separator (.-sep path))

(defn fname [path]
  (subs path (inc (s/last-index-of path separator))))

(defn relname [basedir path]
  (subs path (inc (count basedir))))
