(ns observideo.renderer.subs
  (:require
   [clojure.set :as set]
   [re-frame.core :as rf :refer [reg-sub subscribe]]
   [reagent.ratom :as r :refer-macros [reaction]]
   [taoensso.timbre :as log]
   [observideo.common.utils :as utils]))

;;;;
;; UI

(rf/reg-sub :ui/active-tab
  (fn [db _] (:ui/tab db)))

;;;;
;; Main

(rf/reg-sub :videos/folder
  (fn [db _] (:videos/folder db)))

(rf/reg-sub :videos/all
  (fn [db _] (:videos/all db)))

(rf/reg-sub :videos/current
  (fn [db _] (:videos/current db)))

(rf/reg-sub-raw :videos/current-section
  (fn [db _]
    (reaction
      (get-in @db [:videos/current :current-section]))))

(rf/reg-sub-raw :videos/current-template
  (fn [db _]
    (reaction
      (let [template-id (get-in @db [:videos/current :template-id])]
        (get-in @db [:templates/all template-id])))))

(rf/reg-sub-raw :videos/current-observation
  (fn [db _]
    (reaction
      (let [{:keys [index]} (get-in @db [:videos/current :current-section])
            current-observation (get-in @db [:videos/current :observations index])]
        current-observation))))

(rf/reg-sub-raw :templates/video-count
  (fn [db _]
    (reaction
      (let [aggr (map :template-id (vals (get @db :videos/all)))
            cnt  (frequencies aggr)]
        cnt))))

(rf/reg-sub :templates/all
  (fn [db _] (:templates/all db)))

(rf/reg-sub :templates/current
  (fn [db _] (:templates/current db)))

;;;;
;; queries

(rf/reg-sub :query/current
  (fn [db _] (:query/current db)))


;;;;
;; query helpers

(defn- matches? [obs qry]
  (if (empty? (filter identity (vals qry)))
    true
    (let [prune        #(reduce-kv (fn [m k v]
                                     (if (nil? v)
                                       m
                                       (assoc m k v))) {} %)
          observations (prune obs)
          query        (prune qry)]
      ;; maps are converted to #{[k v] .. [k v]} so the can match based on element equality
      ;; [k1 v1] == [k2 v2]
      (set/subset? (set query)
        (set observations)))))

(comment
  (matches? {"Peer" "Alone" "Gender" "Male"} {"Peer" "Alone" "Gender" nil})) ;;true

(defn- agg->normalize-fn [all-filenames agg-type]
  "Returns a map indexed by type of aggregation.
  Aggregation is used to normalize similar filenames into something that can be grouped."
  (get {:identity  identity
        :by-prefix (fn [n]
                     (-> (utils/fname n)
                         (subs 0 8)))}

    agg-type
    ;; fallback
    identity))

(defn- run-query2
  "Returns a vector [query {video num-of-observations}]
   Example: [ (\"Alone, Group\") {\"SampleVideo.mpg\" 5 \"OtherVideo.mpg\" 1}]
"
  [videos aggregator query]
  (let [all-filenames (map :filename videos)
        normalize-fn  (agg->normalize-fn all-filenames aggregator)]
    (->> videos
      (map (fn [{:keys [filename observations]}]
             [(normalize-fn filename)
              (count (filter #(matches? % query) observations))
              (count observations)]))
      ;; filter only positives
      (filter (fn [[filename matches total]] (> matches 0)))
      ;; aggregate {filename [matches total]}
      (reduce (fn [m [filename matches total]]
                (update m filename (fn [[m t]] [(+ (or m 0) matches) (+ (or t 0) total)])))
        {}))))

(comment
  (let [db     @re-frame.db/app-db
        {:keys [template-id aggregator top bottom]} (:query/current db)
        videos (:videos/all db)
        videos (filter #(= template-id (:template-id %)) (vals videos))
        videos (filter #(not (:missing? %)) videos)]
    (def *v videos)
    (def *q top)
    ;(run-query videos aggregator bottom)
    (run-query2 videos :by-prefix top))
  "")



(rf/reg-sub :query/result
  (fn [db _]
    (let [{:keys [template-id aggregator top bottom]} (:query/current db)
          videos (:videos/all db)
          videos (filter #(= template-id (:template-id %)) (vals videos))
          videos (filter #(not (:missing? %)) videos)]
      {:top    [(vals top) (run-query2 videos aggregator top)]
       :bottom [(vals bottom) (run-query2 videos aggregator bottom)]})))
