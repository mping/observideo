(ns observideo.common.datamodel
  (:require [spec-tools.data-spec :as ds]
            [clojure.spec.alpha :as s]
            [goog.string :as gstr]
            [goog.string.format]
            [taoensso.timbre :as log]))

(def demo-template {:id         "fb52dd46-85cc-4864-b11e-44b8a5b28331"
                    :name       "Demo"
                    :type       :freeform
                    :attributes {"Peer"   {:index 0 :values ["Alone" "Adults" "Peers" "Adults and Peers" "N/A"]}
                                 "Gender" {:index 1 :values ["Same" "Opposite" "Both" "N/A"]}
                                 "Type"   {:index 2 :values ["Roleplay" "Rough and Tumble" "Exercise"]}}})


(def demo-video {:filename     "/home/mping/Download … deo_720x480_30mb.mp4"
                 :duration     183.318
                 :info         {:a "changeme"}
                 :md5sum       "changeme"
                 :size         31551484
                 :missing?     false
                 :observations [{"Peer" nil "Gender" "Same" "Type" "Exercise"}, {}]
                 :template-id  "7dd2479d-e829-4762-a0ac-de51a68461b5"})

(def demo-query {:template-id "fb52dd46-85cc-4864-b11e-44b8a5b28331"
                 :aggregator  :identity                     ;; OR :by-prefix
                 :top         {"Peer" nil "Gender" "Same" "Type" "Exercise"}
                 :bottom      {"Peer" nil "Gender" "Same" "Type" "Exercise"}})

;;;;
;; Specs

(def attribute-spec
  (ds/spec {:name ::atribute
            :spec {:index int? :values [string?]}}))

(def template-spec
  (ds/spec {:name ::template
            :spec {:id         string?
                   :name       string?
                   :attributes (s/map-of string? attribute-spec)}}))

(def section-spec
  (ds/spec {:name ::section
            :spec {:time number? :index int?}}))

(def observation-spec
  (ds/spec {:name ::observation
            :spec (s/map-of string? (s/nilable string?))}))

(def video-spec
  (ds/spec {:name ::video
            :spec {:filename                    string?
                   :duration                    number?
                   :info                        any?
                   :md5sum                      string?
                   :size                        int?
                   :missing?                    boolean?
                   (ds/opt :observations)       [observation-spec]
                   (ds/opt :template-id)        string?}}))


(def db-spec
  (ds/spec {:name ::db
            :spec {:observideo/filename (s/nilable string?)
                   :ui/tab              keyword?
                   :videos/folder       (s/nilable string?)
                   :videos/all          (s/nilable (s/map-of string? video-spec))
                   :videos/current      (s/nilable video-spec)
                   :templates/all       (s/nilable (s/map-of string? template-spec))
                   :templates/current   (s/nilable template-spec)}}))

(defn empty-db []
  {:observideo/filename   nil
   :ui/tab                :videos

   ;; videos list is a vec because they are in the filesystem
   :videos/folder         nil                               ;;string
   :videos/all            nil                               ;;map {filename > video}
   :videos/current        nil                               ;;video

   ;; templates are keyed by :id because it facilitates CRUD operations
   :templates/all         {(:id demo-template) demo-template} ;; {uuid -> template}
   :templates/current     nil

   ;;transient data, doesnt need to be persisteed
   :query/current         nil                               ;; query
   ;; notifs
   :notifications/current nil})

;;;;
;; Data export facilities

(defn- errors [filename template observation]
  (->> observation
       (map-indexed (fn [i [attr val]]
                      (let [values (get-in template [attr :values] [])
                            idx    (.indexOf values val)]
                        (when (and (some? val) (< idx 0))
                          (let [message (gstr/format "An issue occured with video '%s'" filename)
                                descr   (gstr/format "Observation number %s: Failed to find index for attribute '%s' with value '%s'"
                                                     (inc i) attr val filename)]
                            (log/warnf "'%s': Failed to find index for attr '%s' value '%s'" filename attr val)
                            {:message     message
                             :description descr})))))
       (filter identity)
       (flatten)))


(defn- observation->index0
  "Maps observations to 0-based indexes according to template, or -1 if not found"
  [template observation]
  (mapv (fn [[attr val]]
          (let [values (get-in template [attr :values] [])
                idx    (.indexOf values val)]
            ;; nil      -> nil
            ;; "xxx"    -> index
            ;; notfound -> -1
            (or (and val idx)
                nil)))
        observation))


(defn observation->index1
  "1-based version ov observation->index0, keeping -1 for not found"
  [template observation]
  (mapv #(if (>= % 0) (inc %) %)
        (observation->index0 template observation)))


(defn- video->csv
  "Exports the video data as csv. Exposes a map"
  [{:keys [attributes] :as template}
   {:keys [observations filename] :as video}]
  (log/infof "Converting video '%s' to csv" filename)
  (let [headers           (keys attributes)
        observation-vals  (mapv #(into [] (vals %)) observations)
        errors            (mapv #(errors filename attributes %) observations)
        observations-idx0 (mapv #(observation->index0 attributes %) observations)
        observations-idx1 (mapv #(observation->index1 attributes %) observations)]
    {:filename  filename
     :errors    (filter #(not (empty? %)) errors)
     :by-name   (concat [headers] observation-vals)
     :by-index0 (concat [headers] observations-idx0)
     :by-index1 (concat [headers] observations-idx1)}))


(defn db->csv
  "Exports the database as a csv"
  [database]
  (let [{videos :videos/all templates :templates/all} database]
    (for [vid (keys videos)
          :let [video       (get videos vid)
                template-id (get video :template-id)
                template    (get templates template-id)]
          :when (some? template)]
      (video->csv template video))))

(comment
  (db->csv (observideo.main.db/read-db)))
