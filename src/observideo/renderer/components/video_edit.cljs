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
            [observideo.renderer.chromajs :as cjs]
            ["electron" :as electron]))

(defn- select-template [video id]
  (rf/dispatch [:ui/update-current-video-template (str id)]))

(defn- observation-table [video-time]
  (let [template     (rf/subscribe [:videos/current-template])
        video        (rf/subscribe [:videos/current])
        observation  (reaction
                       (get-in @video [:observations (int @video-time)]))
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
                                                        (dissoc @observation header) @video-time])
                                          (rf/dispatch [:ui/update-current-video-current-section-observation
                                                        (assoc @observation header attribute) @video-time])))}
                       attribute]]))]]]))]]]]]]))

;;;;
;; table
;;

(defn- annotations-slider [video video-time]
  [antd/row {:gutter [1 1] :style {:padding-top "1rem"}}
   [antd/col {:span 2}]
   [antd/col {:span 22}
    (let [update-scroll-left (fn [element-id percent]
                               (let [el (.getElementById js/document element-id)]
                                 (let [max-scroll (- (.-scrollWidth el) (.-clientWidth el))
                                       new-scroll (* (/ percent 100) max-scroll)]
                                   (set! (.-scrollLeft el) new-scroll))))]

      [antd/slider {:value    @video-time
                    :max      (int (:duration @video))
                    :onChange #(do
                                 (reset! video-time %)
                                 (update-scroll-left "heatmap-viewport" %))}])]])

(defn- annotations-map [video template jump-fn]
  (let [observations (reaction
                       (get-in @video [:observations]))
        labels       (reaction
                       (mapv first (:attributes @template)))
        nrows        (count @labels)
        cols         (int (:duration @video))

        ;; ui attrs
        colors       (cjs/scale nrows)
        ncolors      (count colors)
        index->obs   (fn [index]
                       (let [secs (int (quot index nrows))]
                         (get-in @observations [secs])))
        color-cell   (fn [index]
                       (let [obs     (index->obs index)
                             filled? (-> (filter identity (vals obs))
                                         (count))]
                         (when (pos-int? filled?)
                           (js/console.log filled? (get colors filled?)))
                         (if (>= filled? ncolors)
                           (last colors)
                           (get colors filled?))))
        handle-click (fn [index]
                       (let [secs      (int (quot index nrows))
                             obs-index (int (mod index nrows))
                             obs-key   (get @labels obs-index)
                             obs-val   (get-in @observations [secs obs-key])]
                         (jump-fn secs)
                         (js/console.log secs)))
        ;; layout attrs
        cell-size    16
        padding      2
        height       (* (+ padding cell-size) (inc nrows))]

    [antd/row {:gutter [1 1] :style {:padding-top "1rem"}}
     ;; labels
     [antd/col {:span 2 :style {"height" (str height "px")}}
      [:svg {:class "heatmap" :style {"width" "100%"}}
       (doall
         (for [[i day] (map-indexed vector @labels)]
           [:text {:key       (str "label-" i) :x 0 :y (+ (* i (+ cell-size padding)) 10)
                   :font-size 10 :fill "#000" :text-anchor "start"} day]))]]
     ;; heatmap
     [antd/col {:span 22 :style {"height" (str height "px")}}
      [:div {:id "heatmap-viewport" :style {"overflow" "auto" "height" "100%"}}
       [:svg {:width (str (* cell-size cols) "px") :class "heatmap"}
        (doall
          (for [index (range (* nrows cols))]
            (let [x (* (quot index nrows) (+ cell-size padding))
                  y (* (mod index nrows) (+ cell-size padding))]
              [:rect {:key     index
                      :x       x :y y
                      :width   cell-size :height cell-size
                      :fill    (color-cell index)
                      :onClick #(handle-click index)}])))]]]]))

(defn root []
  (let [templates     (vals @(rf/subscribe [:templates/all]))
        template      (rf/subscribe [:videos/current-template])
        video         (rf/subscribe [:videos/current])
        filename      (reaction (:filename @video))
        video-time    (r/atom 0)

        ;; these are "local component state"
        ;; some can be used to re-trigger a render (r/atom)
        ;; others are just vars (clojure.core/atom)
        !video-player (atom nil)]

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
                                                                                 (reset! video-time (int secs))))))
                                                  ;(rf/dispatch [:ui/update-current-video-section secs])))))
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
            [observation-table video-time]]]]

         [:div
          [annotations-slider video video-time]
          [annotations-map video template #(do (reset! video-time %)
                                               (.pause @!video-player)
                                               (.seek @!video-player %))]]]))))
