(ns observideo.renderer.components.queries
  (:require [observideo.renderer.components.antd :as antd]
            [re-frame.core :as rf]
            [taoensso.timbre :as log]
            [reagent.core :as r]
            [clojure.string :as str]
            [observideo.common.utils :as utils]))

(def indifferent "<empty>")

(defn- render-result-row [[values videos]]
  ;; c=count, t=total (per video)
  (let [query-vals  (map #(or % indifferent) values)
        query-title (str "Matching: " (str/join "," query-vals))
        totals      (reduce + (map (fn [[_ [c t]]] c) videos))
        datasource  (mapv (fn [[v [c t]]]
                            {:v v :label (str c " of " t) :key v})
                      videos)
        datasource  (conj datasource {:v "Total" :label totals :key :total})]
    [:div
     [antd/table {:size       "small"
                  :dataSource datasource
                  :columns    [{:title query-title :dataIndex :v :key :v}
                               {:title "Matched observations" :dataIndex :label :key :v}]}]]))

(defn- render-result [{:keys [top bottom]}]
  [:div
   (render-result-row top)
   [:hr]
   (render-result-row bottom)])

(defn- export-current-query [query-result]
  (rf/dispatch [:query/export query-result]))

(defn ui
  []
  (let [templates-map       @(rf/subscribe [:templates/all])
        templates           (vals templates-map)

        ;; local state
        current-template!   (r/atom nil)
        current-aggregator! (r/atom :identity)
        top-selection!      (r/atom {})
        bottom-selection!   (r/atom {})
        make-selection      (fn [t]
                              (let [attributes (:attributes t)]
                                (reduce (fn [acc k] (assoc acc k nil)) {} (keys attributes))))]

    ;; reset screen
    (rf/dispatch [:query/reset])

    ;; form-2 component
    (fn []
      (let [query-result    @(rf/subscribe [:query/result])
            current-query   @(rf/subscribe [:query/current])
            attributes      (:attributes @current-template!)
            update-fn       (fn []
                              (rf/dispatch [:query/update (:id @current-template!) @current-aggregator! @top-selection! @bottom-selection!]))
            dispatch-update (fn [r k v]
                              (let [proper-value (if (= v indifferent) nil v)]
                                (swap! r assoc k proper-value)
                                (update-fn)))]

        [:div
         [:h1 "Queries"]

         [antd/form {:layout     "inline"
                     :name       "basic"
                     :size       "small"
                     :ref        "form"}
          ;; main name
          [antd/form-item {:label "Template"}
           [antd/select {:placeholder "Select a template"
                         :onChange    #(do (reset! current-template! (get templates-map %))
                                           (reset! top-selection! (make-selection @current-template!))
                                           (reset! bottom-selection! (make-selection @current-template!))
                                           (update-fn))}
            (for [tmpl templates
                  :let [{:keys [id name]} tmpl]]
              [antd/option {:key id} name])]]

          [antd/form-item {:label "Aggregation"}
           [antd/select {:placeholder "Combine videos?"
                         :disabled    (nil? @current-template!)
                         :onChange    #(do (reset! current-aggregator! (keyword %))
                                           (update-fn))}
            [antd/option {:key :identity} "Combine videos: no"]
            [antd/option {:key :by-prefix} "Combine by name"]]]

          [antd/form-item
           [antd/button {:href     "#"
                         :disabled (nil? @current-template!)
                         :onClick  #(export-current-query query-result)}
            [antd/download-icon] " export"]]]

         [:hr]

         [:div
          [:table
           [:tbody
            [:tr
             (for [[k v] attributes
                   :let [vals (:values v)]]
               [:td {:key k}
                [:b k " "]
                [antd/select {:onChange     #(dispatch-update top-selection! k %)
                              :allowClear   false
                              :defaultValue indifferent}
                 [antd/option {:key indifferent} indifferent]
                 (for [opt vals] [antd/option {:key opt} opt])]])]]]
          [:hr]
          [:table
           [:tbody
            [:tr
             (for [[k v] attributes
                   :let [vals (:values v)]]
               [:td {:key k}
                [:b k " "]
                [antd/select {:onChange     #(dispatch-update bottom-selection! k %)
                              :allowClear   false
                              :defaultValue indifferent}
                 [antd/option {:key indifferent} indifferent]
                 (for [opt vals] [antd/option {:key opt} opt])]])]]]
          [:hr]
          (render-result query-result)]]))))
