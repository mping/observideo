(ns observideo.renderer.components.video-edit
  (:require [clojure.string :as s]
            [reagent.core :as r]
            [reagent.ratom :refer [reaction]]
            [re-frame.core :as rf]
            [observideo.common.utils :as utils]
            [goog.string :as gstring]
            [goog.string.format]
            [observideo.renderer.components.antd :as antd]
            [observideo.renderer.components.player :as player]
            ["electron" :as electron]))

(defn- select-template [video id]
  (rf/dispatch [:ui/update-current-video-template (str id)]))

(defn- observation-table []
  (let [template     (rf/subscribe [:videos/current-template])
        observation  (rf/subscribe [:videos/current-observation])
        ;video        (rf/subscribe [:videos/current])
        attributes   (:attributes @template)
        sorted-attrs (sort-by (fn [[_ v]] (:index v)) attributes)]

    [:div.ant-table.ant-table-middle
     [:div.ant-table-container
      [:div.ant-table-content
       ;; dynamic fields
       [:table {:style {:width "100%"}}
        [:thead.ant-table-thead
         ;; col header
         [:tr nil
          (concat (map-indexed (fn [i [header v]]
                                 [:th.ant-table-cell {:key (:index v)} (name header)])
                               sorted-attrs))]]

        [:tbody.ant-table-tbody
         [:tr nil
          ;; attrs list per header
          (doall
            (for [[header v] sorted-attrs
                  :let [vals  (:values v)
                        pairs (sort-by last (zipmap vals (range)))
                        tdkey (str "attr" (:index v))]]
              [:td {:style {:padding 0} :key tdkey :valign "top"}
               [:table nil
                [:tbody nil
                 ;; build an indexed [val, index]
                 (doall
                   (for [pair pairs
                         :let [[attribute i] pair
                               attribute-on? (= attribute (get @observation header))
                               rowkey        (str "row-" i)
                               tdkey         (str "cell-" i)]]

                     [:tr {:key rowkey}
                      [:td {:key     tdkey
                            :style   {:color      ""
                                      :background (cond
                                                    attribute-on? "#1890ff")}
                            :onClick #(do
                                        (if attribute-on?
                                          (rf/dispatch [:ui/update-current-video-current-section-observation
                                                        (dissoc @observation header)])
                                          (rf/dispatch [:ui/update-current-video-current-section-observation
                                                        (assoc @observation header attribute)])))}
                       attribute]]))]]]))]]]]]]))

(defn root []
  (let [templates     (vals @(rf/subscribe [:templates/all]))
        template       (rf/subscribe [:videos/current-template])
        video         (rf/subscribe [:videos/current])
        filename      (reaction (:filename @video))

        ;; these are "local component state"
        ;; some can be used to re-trigger a render (r/atom)
        ;; others are just vars (clojure.core/atom)
        !video-player (atom nil)
        video-time    (r/atom 0)]

    ;; form-2 component
    (fn []
      ;; trigger re-render when some attr on the video changes
      (let [selected-template (rf/subscribe [:videos/current-template])]

        [:div
         [antd/row {:gutter [8, 8]}
          ;;;;
          ;; left col - video player
          [antd/col {:span 12}
           [antd/page-header {:title    (utils/fname @filename)
                              :subTitle @filename
                              :onBack   #(rf/dispatch [:ui/deselect-video])}]
           [player/video-player {:playsInline true
                                 :src         (str "file://" @filename)
                                 :ref         (fn [^js/Player el]
                                                (when (some? el)
                                                  (.subscribeToStateChange el
                                                                           (fn [jsobj]
                                                                             (let [secs (.-currentTime jsobj)]
                                                                               (when-not (= secs @video-time)
                                                                                 (reset! video-time (int secs))
                                                                                 (rf/dispatch [:ui/update-current-video-section secs])))))
                                                  ;(.pause el)))))
                                                  (reset! !video-player el)))}]]

          ;;;;
          ;; right col - template application
          [antd/col {:span 12}
           [antd/page-header {:title "Template"}]

           [:div
            [antd/select {:defaultValue (:id @selected-template)
                          :placeholder  "Select a template"
                          :onChange     #(select-template video %)}
             (doall
               (for [tmpl templates
                     :let [{:keys [id name]} tmpl]]
                 [antd/option {:key id} (str name)]))]

            [:br]]

           ;; for videos in portrait mode, observation-table may get out of viewport
           ;; affix sticks it on top
           [antd/affix {}
            [observation-table]]]]

         [antd/row {:gutter [1 1] :style {:padding-top "1rem"}}
          [antd/col {:span 2}]
          [antd/col {:span 22}
           (let [update-scroll-left (fn [element-id percent]
                                      (let [el (.getElementById js/document element-id)]
                                        (let [max-scroll (- (.-scrollWidth el) (.-clientWidth el))
                                              new-scroll (* (/ percent 100) max-scroll)]
                                          (set! (.-scrollLeft el) new-scroll))))]

             [antd/slider {:onChange #(update-scroll-left "heatmap" %)}])]]

         (let [labels        (reaction
                               (mapv first (:attributes @template)))
               colors        ["#ebedf0" "#c6e48b" "#7bc96f" "#239a3b" "red"]

               rows          (count @labels)
               cols          (int (:duration @video))
               data          (r/atom
                               (vec (map #(rand-int 5) (range (* rows cols)))))

               cell-size     16
               padding       2
               height        (* (+ padding cell-size) (inc rows))]

           [antd/row {:gutter [1 1] :style {:padding-top "1rem"}}
            ;; labels
            [antd/col {:span 2 :style {"height" (str height "px")}}
             [:svg {:class "heatmap" :style {"width" "100%"}}
              (for [[i day] (map-indexed vector @labels)]
                [:text {:key       (str "label-" i) :x 0 :y (+ (* i (+ cell-size padding)) 10)
                        :font-size 10 :fill "#000" :text-anchor "start"} day])]]
            ;; heatmap
            [antd/col {:span 22 :style {"height" (str height "px")}}
             [:div {:id "heatmap" :style {"overflow" "auto" "height" "100%"}}
              [:svg {:width (str (* cell-size cols) "px") :class "heatmap"}
               (for [[index level] (map-indexed vector @data)]
                 (let [x (* (quot index rows) (+ cell-size padding))
                       y (* (mod index rows) (+ cell-size padding))]
                   [:rect {:key   index
                           :x     x :y y
                           :width cell-size :height cell-size
                           :fill  (nth colors level)}]))]]]])]))))

