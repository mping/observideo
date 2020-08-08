(ns observideo.renderer.components.queries
  (:require [observideo.renderer.components.antd :as antd]
            [re-frame.core :as rf]
            [taoensso.timbre :as log]
            [reagent.core :as r]
            [clojure.string :as str]
            [observideo.common.utils :as utils]))

(defn- render-row [[values videos]]
  (let [query-vals (map #(or % "<empty>") values)
        totals     (apply + (map (fn [[_ c]] c) videos))
        datasource (mapv (fn [[v c]] {:v v :c c :key v}) videos)
        datasource (conj datasource {:v "Total" :c totals :key :total})]
    [:div
     [:pre (str/join "," query-vals)]
     [antd/table {:size       "small"
                  :dataSource datasource
                  :columns    [{:title "Video" :dataIndex :v :key :v}
                               {:title "Matched observations" :dataIndex :c :key :c}]}]]))


(defn- render-result [{:keys [top bottom]}]
  [:div
   (render-row top)
   [:hr]
   (render-row bottom)])

(def indifferent "-indifferent-")

(defn ui
  []
  (let [templates-map     @(rf/subscribe [:templates/all])
        templates         (vals templates-map)

        ;; local state
        current-template! (r/atom nil)
        top-selection!    (r/atom {})
        bottom-selection! (r/atom {})
        make-selection    (fn [t]
                            (let [attributes (:attributes t)]
                              (reduce (fn [acc k] (assoc acc k nil)) {} (keys attributes))))]

    ;; form-2 component
    (fn []
      (let [query-result    @(rf/subscribe [:query/result])
            current-query   @(rf/subscribe [:query/current])
            attributes      (:attributes @current-template!)
            aggregation     "some_video_prefix_aggregator"
            dispatch-update (fn [r k v]
                              (let [proper-value (if (= v indifferent) nil v)]
                                (swap! r assoc k proper-value)
                                (rf/dispatch [:query/update (:id @current-template!) aggregation @top-selection! @bottom-selection!])))]

        [:div
         [:h1 "Queries"]
         ;; select a component
         [antd/select {:onChange #(do (reset! current-template! (get templates-map %))
                                      (reset! top-selection! (make-selection @current-template!))
                                      (reset! bottom-selection! (make-selection @current-template!)))}
          (for [tmpl templates
                :let [{:keys [id name]} tmpl]]
            [antd/option {:key id} name])]
         [:p "Select a template"]

         [:div
          [:table
           [:tbody
            [:tr
             (for [[k v] attributes
                   :let [vals (:values v)]]
               [:td {:key k}
                [:b k " "]
                [antd/select {:onChange #(dispatch-update top-selection! k %)
                              :allowClear false
                              :defaultValue indifferent}
                 [antd/option {:key :-indifferent-} indifferent]
                 (for [opt vals]
                   [antd/option {:key opt} opt])]])]]]
          [:hr]
          [:table
           [:tbody
            [:tr
             (for [[k v] attributes
                   :let [vals (:values v)]]
               [:td {:key k}
                [:b k " "]
                [antd/select {:onChange #(dispatch-update bottom-selection! k %)
                              :allowClear false
                              :defaultValue indifferent}
                 [antd/option {:key :indifferent} indifferent]
                 (for [opt vals]
                   [antd/option {:key opt} opt])]])]]]
          [:hr]
          (render-result query-result)]]))))
