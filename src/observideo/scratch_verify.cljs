;; TEMPORARY verification script -- not part of the app. Exercises the
;; pure functions in common/datamodel.cljs directly (no Electron/re-frame
;; involved, so it can run as a plain node script). Delete this file and
;; the :verify build in shadow-cljs.edn once checked.
(ns observideo.scratch-verify
  (:require [observideo.common.datamodel :as datamodel]))

(defonce failures (atom 0))

(defn- check [desc actual expected]
  (if (= actual expected)
    (println "PASS:" desc)
    (do
      (println "FAIL:" desc)
      (println "  expected:" (pr-str expected))
      (println "  actual:  " (pr-str actual))
      (swap! failures inc))))

(defn main [& _]
  ;; --- CSV escaping (item: "CSV values are never quoted") ---
  (check "csv-escape-field: plain" (datamodel/csv-escape-field "plain") "plain")
  (check "csv-escape-field: comma" (datamodel/csv-escape-field "a,b") "\"a,b\"")
  (check "csv-escape-field: quote" (datamodel/csv-escape-field "a\"b") "\"a\"\"b\"")
  (check "csv-line quotes a demo-template-style value"
    (datamodel/csv-line ["1" "Lutas (murros, pontapés, ...)"])
    "1,\"Lutas (murros, pontapés, ...)\"")

  ;; --- CSV column alignment (item: "CSV columns can misalign") ---
  (let [template {:id "t1"
                   :attributes {"Peer"   {:index 0 :values ["Alone" "Group"]}
                                "Gender" {:index 1 :values ["Same" "Both"]}}}
        obs      {"Gender" "Same"}] ;; "Peer" was toggled off -> dissoc'd, per video_edit.cljs
    (let [db   {:videos/all    {"v.mp4" {:filename "v.mp4" :template-id "t1" :observations [obs]}}
                :templates/all {"t1" template}}
          rows (datamodel/db->csv db)
          row  (first rows)]
      (check "csv header order follows :index, not map iteration order"
        (first (:by-name row)) ["Peer" "Gender"])
      (check "csv row aligns with the header despite a missing (dissoc'd) key"
        (second (:by-name row)) [nil "Same"])))

  ;; --- attribute rename propagation (item: "Renaming an attribute orphans existing annotations") ---
  (let [old-t  {:id "t1" :interval 15 :attributes {"OldName" {:index 0 :values ["A" "B"]}}}
        new-t  {:id "t1" :interval 15 :attributes {"NewName" {:index 0 :values ["A" "B"]}}}
        videos {"v.mp4"     {:template-id "t1" :duration 15 :observations [{"OldName" "A"}]}
                "other.mp4" {:template-id "t2" :duration 15 :observations [{"OldName" "A"}]}}
        result (datamodel/reconcile-videos-for-template old-t new-t videos)]
    (check "renaming an attribute renames the key in existing observations"
      (get-in result ["v.mp4" :observations 0]) {"NewName" "A"})
    (check "a video annotated with a DIFFERENT template is untouched"
      (get-in result ["other.mp4" :observations 0]) {"OldName" "A"}))

  ;; --- interval-change resize (item: "doesn't resize the observation lists that already exist") ---
  (let [old-t  {:id "t1" :interval 15 :attributes {"A" {:index 0 :values ["x"]}}}
        new-t  {:id "t1" :interval 10 :attributes {"A" {:index 0 :values ["x"]}}}
        videos {"v.mp4" {:template-id "t1" :duration 30 :observations [{"A" "x"} {"A" nil}]}}
        result (datamodel/reconcile-videos-for-template old-t new-t videos)]
    (check "shrinking the interval grows observations to match (30s/10s=3)"
      (count (get-in result ["v.mp4" :observations])) 3)
    (check "existing entries are preserved, not reset, when growing"
      (get-in result ["v.mp4" :observations 0]) {"A" "x"}))

  (let [old-t  {:id "t1" :interval 10 :attributes {"A" {:index 0 :values ["x"]}}}
        new-t  {:id "t1" :interval 30 :attributes {"A" {:index 0 :values ["x"]}}}
        videos {"v.mp4" {:template-id "t1" :duration 30 :observations [{"A" "x"} {"A" nil} {"A" nil}]}}
        result (datamodel/reconcile-videos-for-template old-t new-t videos)]
    (check "growing the interval shrinks observations to match (30s/30s=1)"
      (count (get-in result ["v.mp4" :observations])) 1))

  (let [n @failures]
    (if (pos? n)
      (do (println (str "\n" n " check(s) FAILED"))
          (set! (.-exitCode js/process) 1))
      (println "\nAll checks passed"))))
