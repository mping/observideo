(ns observideo.renderer.components.video-edit
  (:require [clojure.string :as s]
            [reagent.core :as r]
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
  (let [template     @(rf/subscribe [:videos/current-template])
        observation  @(rf/subscribe [:videos/current-observation])
        video        @(rf/subscribe [:videos/current])
        section0?    (= 0 (get-in video [:current-section :index]))
        attributes   (:attributes template)
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
          (for [[header v] sorted-attrs
                :let [vals  (:values v)
                      pairs (sort-by last (zipmap vals (range)))
                      tdkey (str "attr" (:index v))]]
            [:td {:style {:padding 0} :key tdkey :valign "top"}
             [:table nil
              [:tbody nil
               ;; build an indexed [val, index]
               (for [pair pairs
                     :let [[attribute i] pair
                           attribute-on? (= attribute (get observation header))
                           rowkey        (str "row-" i)
                           tdkey         (str "cell-" i)]]

                 [:tr {:key rowkey}
                  [:td {:key     tdkey
                        :style   {:color      (when section0? "#eee")
                                  :background (cond
                                                section0? "#fff"
                                                attribute-on? "#1890ff")}
                        :onClick #(do
                                    (when-not section0?
                                      (if attribute-on?
                                        (rf/dispatch [:ui/update-current-video-current-section-observation
                                                      (dissoc observation header)])
                                        (rf/dispatch [:ui/update-current-video-current-section-observation
                                                      (assoc observation header attribute)]))))}
                   attribute]])]]])]]]]]]))

(defn root []
  (let [video          @(rf/subscribe [:videos/current])
        {:keys [duration filename]} video
        templates      (vals @(rf/subscribe [:templates/all]))

        ;; these are "local component state"
        ;; some can be used to re-trigger a render (r/atom)
        ;; others are just vars (clojure.core/atom)
        !video-player  (atom nil)
        !step-interval (atom 1)
        video-section  (r/atom 0)
        video-time     (r/atom 0)]

    ;; form-2 component
    (fn []
      ;; trigger re-render when some attr on the video changes
      (let [section           @(rf/subscribe [:videos/current-section])
            selected-template @(rf/subscribe [:videos/current-template])
            initial-interval  (get selected-template :interval 1)
            num-observations  (+ (int (/ duration initial-interval))
                                 (if (> (mod duration initial-interval) 0) 1 0))

            tstart (* (max 0 (dec @video-section)) @!step-interval)
            tend   (min duration (* @video-section @!step-interval))]

        (reset! !step-interval initial-interval)

        [:div
         [antd/row {:gutter [8, 8]}
          ;;;;
          ;; left col - video player
          [antd/col {:span 12}
           [antd/page-header {:title  (utils/fname filename)
                              :subTitle filename
                              :onBack #(rf/dispatch [:ui/deselect-video])}]
           [player/video-player {:playsInline true
                                 :src         (str "file://" (:filename video))
                                 :ref         (fn [^js/Player el]
                                                (when (some? el)
                                                  (.subscribeToStateChange el
                                                    (fn [jsobj]
                                                      (let [secs      (.-currentTime jsobj)
                                                            previndex @video-section
                                                            index     (if (= secs duration)
                                                                        ;; last index?
                                                                        (int (+ (int (/ secs @!step-interval))
                                                                               (if (= 0 (rem duration @!step-interval))
                                                                                 0
                                                                                 1)))
                                                                        (int (/ secs @!step-interval)))]
                                                        (reset! video-time secs)
                                                        (reset! video-section index)
                                                        (rf/dispatch [:ui/update-current-video-section secs index])
                                                        ;; auto-pause when the section changes
                                                        (when (not= previndex index)
                                                          (.pause el)))))
                                                  (reset! !video-player el)))}]]

          ;;;;
          ;; right col - template application
          [antd/col {:span 12}
           [antd/page-header {:title "Template"}]
           [:div
            [antd/select {:defaultValue (str (:id selected-template)) :onChange #(select-template video %)}
             (for [tmpl templates
                   :let [{:keys [id name]} tmpl]]
               [antd/option {:key id} name])]

            [antd/button {:type :primary
                          :onClick #(js/console.log %)
                          :disabled (= :interval (:type selected-template))}
             [antd/plus-circle-icon] "Add new section"]

            [:span (str " interval: " (gstring/format "%s - %s" tstart tend)
                     "s of " duration ", section: " @video-section)]]

           ;; TODO use a different slider if type is :freeform
           (if (= :type :interval)
             [antd/slider {:min            0
                           :max            num-observations
                           :value          @video-section
                           :key            "video-section-slider"
                           :tooltipVisible false
                           :dots           true
                           :onChange       #(do (reset! video-section %)
                                                (js/console.log "seeking section:" @video-section)
                                                (.seek @!video-player (* % @!step-interval) "seconds")
                                                (.pause @!video-player))}]
             ;; ELSE
             [antd/slider {:range false
                           :marks {0 "Start" duration "End"}
                           :max duration
                           :step nil
                           :tooltipVisible false
                           :dots           true
                           :onChange      #(do
                                             (js/console.log "xxx" %)
                                             (.seek @!video-player % "seconds")
                                             (.pause @!video-player))}])

           ;; for videos in portrait mode, observation-table may get out of viewport
           ;; affix sticks it on top
           [antd/affix {}
            [observation-table]]]]
         #_#_[:hr]
             [antd/row
              [:h1 "Here:" (:time section) "|" (:index section)]]]))))

