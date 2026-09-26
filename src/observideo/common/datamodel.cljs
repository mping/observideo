(ns observideo.common.datamodel
  (:require [spec-tools.data-spec :as ds]
            [clojure.spec.alpha :as s]
            [clojure.set :as set]
            [clojure.string :as str]
            [goog.string :as gstr]
            [goog.string.format]
            [taoensso.timbre :as log]))

(def demo-template {:id         "fb52dd46-85cc-4864-b11e-44b8a5b28331"
                    :name       "Observação BLP"
                    :interval   15
                    :next-index 3                           ;;monotonic counter to ensure old indexes preserve their value
                    :attributes {"Comportamento" {:index 0 :values ["Lutas (murros, pontapés, deitar ao chão, empurrar, ...)"
                                                                    "Lutas com componente simbólica (super heróis, bons e maus, ...)"
                                                                    "Perseguição"
                                                                    "Cócegas"
                                                                    "Outra"
                                                                    "N/A"]}
                                 "Afetividade"   {:index 1 :values ["Negativa"
                                                                    "Positiva"
                                                                    "Neutra"
                                                                    "N/A"]}
                                 "Interação"     {:index 2 :values ["Unilateral"
                                                                    "Recíproca"
                                                                    "Outra"
                                                                    "N/A"]}
                                 "Contacto"      {:index 3 :values ["Sem contacto"
                                                                    "Com contacto"
                                                                    "N/A"]}
                                 "Força"         {:index 4 :values ["Pouca força"
                                                                    "Força indiferenciada"
                                                                    "Muita força"
                                                                    "N/A"]}
                                 "Movimentos"    {:index 5 :values ["Diretos"
                                                                    "Curvilíneos"
                                                                    "Outros"
                                                                    "N/A"]}
                                 "Pares"         {:index 6 :values ["1"
                                                                    "2"
                                                                    "3 ou mais"
                                                                    "N/A"]}
                                 "Género"        {:index 7 :values ["Mesmo"
                                                                    "Oposto"
                                                                    "Misto"
                                                                    "N/A"]}}})

;; reference only
(def demo-video {:filename        "/home/mping/Download/"
                 :duration        183.318
                 :info            {:a "changeme"}
                 :md5sum          "changeme"
                 :size            31551484
                 :missing?        false
                 :current-section {:time 0, :index 0}
                 :observations    [{"Peer" nil "Gender" "Same" "Type" "Exercise"}, {}]
                 :template-id     "7dd2479d-e829-4762-a0ac-de51a68461b5"})

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
                   :interval   int?
                   :next-index int?
                   :attributes (s/map-of string? attribute-spec)}}))

(def section-spec
  (ds/spec {:name ::section
            :spec {:time number? :index int?}}))

(def observation-spec
  (ds/spec {:name ::observation
            :spec (s/map-of string? (s/nilable string?))}))

(def video-spec
  (ds/spec {:name ::video
            :spec {:filename                 string?
                   :duration                 number?
                   :info                     any?
                   :md5sum                   string?
                   :size                     int?
                   :missing?                 boolean?
                   (ds/opt :current-section) section-spec
                   (ds/opt :observations)    [observation-spec]
                   (ds/opt :template-id)     string?}}))


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
;; Interval / observation helpers
;;
;; Shared by renderer/events.cljs so applying a template
;; (:ui/update-current-video-template) and editing one later
;; (:ui/update-template) use the exact same counting/shaping rules.

(defn count-observations
  "How many interval-sized slots a video of `duration` seconds needs at
   `step-interval` seconds per slot."
  [duration step-interval]
  (+ (int (/ duration step-interval))
    (if (> (mod duration step-interval) 0) 1 0)))

(defn make-empty-observations
  "n empty observation maps shaped for `template` (every attribute present,
   mapped to nil)."
  [template n]
  (->> (range)
    (take n)
    (map (fn [_]
           (let [attrs (:attributes template)]
             ;; create a mapping {"name" => nil}
             (reduce-kv (fn [m k _] (assoc m (str k) nil)) {} attrs))))
    (vec)))

(defn- attribute-rename-map
  "{old-name new-name} for attributes present in both templates under the
   same :index but a different key -- i.e. attributes that were renamed.
   :index is the only stable identity attributes have in this data model
   (they are otherwise keyed by their own display name in :attributes), so
   renames have to be detected via that, not via the name itself."
  [old-template new-template]
  (let [by-index     (fn [attrs] (into {} (map (fn [[k v]] [(:index v) k]) attrs)))
        old-by-index (by-index (:attributes old-template))
        new-by-index (by-index (:attributes new-template))]
    (reduce-kv (fn [acc idx old-name]
                 (if-let [new-name (get new-by-index idx)]
                   (if (= old-name new-name) acc (assoc acc old-name new-name))
                   acc))
      {}
      old-by-index)))

(defn- resize-observations
  "Resizes `observations` to exactly `n` entries: pads with empty
   observations shaped for `template`, or truncates trailing entries."
  [template observations n]
  (let [current (count observations)]
    (cond
      (= current n) (vec observations)
      (< current n) (into (vec observations) (make-empty-observations template (- n current)))
      :else         (subvec (vec observations) 0 n))))

(defn reconcile-videos-for-template
  "After a template is edited (old-template -> new-template), keeps every
   video annotated with it consistent instead of silently drifting out of
   sync with its own template:
   - renamed attributes (matched by :index) are renamed in each stored
     observation. Previously, renaming an attribute only touched the
     template's own :attributes map (clojure.set/rename-keys in
     update-template-col) -- every video's already-recorded observations
     still referenced the OLD attribute name, orphaning them.
   - if the interval changed, each video's :observations is resized to
     match its own :duration under the NEW interval. Previously the
     observation count was frozen at whatever it was when the template
     was first applied.
   Videos annotated with a different template (or old-template being nil,
   e.g. a template that did not exist before) are returned unchanged."
  [old-template new-template videos]
  (if (or (nil? old-template) (nil? videos))
    videos
    (let [id            (:id new-template)
          rename-map    (attribute-rename-map old-template new-template)
          interval-chg? (not= (:interval old-template) (:interval new-template))]
      (into {}
        (for [[fname video] videos]
          [fname
           (if (not= (:template-id video) id)
             video
             (let [renamed (if (empty? rename-map)
                             (:observations video)
                             (mapv #(set/rename-keys % rename-map) (:observations video)))
                   resized (if interval-chg?
                             (resize-observations new-template renamed
                               (count-observations (:duration video) (:interval new-template)))
                             renamed)]
               (assoc video :observations resized)))])))))

;;;;
;; Data export facilities

(defn csv-escape-field
  "Quotes a CSV field per RFC 4180 when it contains a comma, a double
   quote, or a newline, doubling any embedded quotes. Without this,
   attribute/value names containing a comma -- like the demo template's
   own \"Lutas (murros, pontapés, ...)\" -- silently split into extra
   columns."
  [field]
  (let [s (str field)]
    (if (re-find #"[,\"\r\n]" s)
      (str "\"" (str/replace s "\"" "\"\"") "\"")
      s)))

(defn csv-line
  "Joins a row of values into one escaped CSV line (no trailing newline)."
  [row]
  (->> row
    (map csv-escape-field)
    (str/join ",")))

(defn- sorted-attribute-names
  "Attribute (column) names in display order, i.e. sorted by :index -- the
   same order the UI shows them in. `keys` on a map has unspecified order;
   that -- combined with each row being built from (vals observation)
   below, whose own key order can differ from the header's, and which
   shrinks whenever a cell is toggled off (see
   :ui/update-current-video-current-section-observation, which dissocs
   the key) -- is why CSV columns could end up misaligned or short. Every
   row must be built from this same explicit header list instead."
  [attributes]
  (->> attributes
    (sort-by (fn [[_ v]] (:index v)))
    (mapv first)))

(defn- row-errors [filename attributes headers observation]
  (->> headers
    (map-indexed (fn [i attr]
                   (let [val    (get observation attr)
                         values (get-in attributes [attr :values] [])
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

(defn- observation->row-by-name
  "One CSV row of value names in header order."
  [headers observation]
  (mapv #(get observation %) headers))

(defn- observation->row-by-index0
  "One CSV row of 0-based value indexes in header order, or nil for unset
   or not-found values."
  [attributes headers observation]
  (mapv (fn [attr]
          (let [val    (get observation attr)
                values (get-in attributes [attr :values] [])
                idx    (.indexOf values val)]
            ;; nil      -> nil
            ;; "xxx"    -> index
            ;; notfound -> -1
            (or (and val idx)
                nil)))
        headers))

(defn- observation->row-by-index1
  "1-based version of observation->row-by-index0, keeping -1 for not found."
  [attributes headers observation]
  (mapv #(cond
           (nil? %) nil
           (>= % 0) (inc %)
           :else    %)
    (observation->row-by-index0 attributes headers observation)))

(defn- video->csv
  "Exports the video data as csv-ready rows (not yet escaped/joined -- see
   csv-line). Every row is built from the same header order regardless of
   which keys happen to be present in a given observation map."
  [{:keys [attributes] :as template}
   {:keys [observations filename] :as video}]
  (log/infof "Converting video '%s' to csv" filename)
  (let [headers           (sorted-attribute-names attributes)
        observation-vals  (mapv #(observation->row-by-name headers %) observations)
        errors            (mapv #(row-errors filename attributes headers %) observations)
        observations-idx0 (mapv #(observation->row-by-index0 attributes headers %) observations)
        observations-idx1 (mapv #(observation->row-by-index1 attributes headers %) observations)]
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
