(ns observideo.renderer.components.templates
  (:require [goog.object :as gobj]
            [observideo.renderer.components.antd :as antd]
            [re-frame.core :as rf]
            [reagent.core :as r]
            [clojure.string :as str]))

;;;;
;; form evt handlers

(defn- update-template-name [template newname]
  (let [new-template (assoc template :name newname)]
    (rf/dispatch [:ui/update-current-template new-template])))

(defn- update-template-interval [template intv]
  (let [new-template (assoc template :interval intv)]
    (rf/dispatch [:ui/update-current-template new-template])))

(defn- update-template-type [template ttype]
  (let [intv         (:interval template)
        new-template (assoc template :type (keyword ttype)
                                     :interval (or intv 1))]
    (rf/dispatch [:ui/update-current-template new-template])))

;; cols
(defn- add-template-col [e template]
  (.preventDefault e)
  (let [attrname     (str (gensym))
        attrs        (:attributes template)
        next-index   (:next-index template)
        new-template (update-in template [:attributes]
                                assoc
                                attrname {:index (count attrs) :values ["Some" "Values"]}
                                :next-index (inc next-index))]
    (rf/dispatch [:ui/update-current-template new-template])))

(defn- delete-template-col [e template name]
  (.preventDefault e)
  (let [new-template (update-in template [:attributes] dissoc name)]
    (rf/dispatch [:ui/update-current-template new-template])))

(defn- update-template-col [template name newname]
  (let [new-template (update-in template [:attributes] clojure.set/rename-keys {name newname})]
    (rf/dispatch [:ui/update-current-template new-template])))

;; attrs
(defn- add-template-attr [e template header]
  (.preventDefault e)
  (let [current-attrs (get-in template [:attributes header :values])
        new-attrs     (vec (conj current-attrs (str (gensym))))]
    (let [new-template (assoc-in template [:attributes header :values] new-attrs)]
      (rf/dispatch [:ui/update-current-template new-template]))))

(defn- delete-template-attr [e template name idx]
  (.preventDefault e)
  (let [attrs        (:attributes template)
        vals         (:values (get attrs name))
        spliced      (vec (concat (subvec vals 0 idx) (subvec vals (inc idx))))
        new-template (assoc-in template [:attributes name :values] spliced)]
    (rf/dispatch [:ui/update-current-template new-template])))

(defn- update-template-attr [template header index newattrname]
  (let [values       (get-in template [:attributes header :values])
        new-values   (assoc values index newattrname)
        new-template (assoc-in template [:attributes header :values] new-values)]
    (rf/dispatch [:ui/update-current-template new-template])))

;;;;
;; form

(defn- handle-submit [this values template]
  (rf/dispatch [:ui/update-template template])
  (rf/dispatch [:ui/deselect-template]))

(defn- cancel [& args]
  (rf/dispatch [:ui/deselect-template]))

;;;;
;; Main template form

(defn- template-form []
  (let [template     (rf/subscribe [:templates/current])
        this         (r/current-component)
        tmpl-name    (:name @template)
        intv         (or (:interval @template) 1)
        ttype        (or (:type @template) :interval)
        attributes   (:attributes @template)
        sorted-attrs (sort-by (fn [[_ v]] (:index v)) attributes)]
    [:div
     [antd/page-header {:title  tmpl-name :subTitle "Edit"
                        :onBack #(rf/dispatch [:ui/deselect-template])}]
     [antd/form {:labelCol   {:span 6}
                 :wrapperCol {:span 24}
                 :name       "basic"
                 :size       "small"
                 :ref        "form"
                 :onFinish   #(handle-submit this % @template)}
      ;; main name
      [antd/form-item {:label "Template Name" #_#_:rules [{:required true :message "Field is required"}]}
       [antd/input {:value    tmpl-name
                    :onChange #(update-template-name @template (-> % .-target .-value))}]]

      [antd/form-item {:label (str "Type : ")}
       [antd/select {:value ttype
                     :options [{:value :interval :label "Interval"}
                               {:value :freeform :label "Freeform"}]
                     :onChange #(update-template-type @template %)}]]

      [antd/form-item {:label (str "Interval (secs): " intv)}
       [antd/slider {:min            1
                     :max            60
                     :value          intv
                     :key            "slider"
                     :tooltipVisible false
                     :disabled       (= ttype :freeform)
                     :onChange       #(update-template-interval @template %)}]]


      ;; dynamic fields
      [:table {:style {:width "100%"}}
       [:thead nil
        ;; col header
        [:tr nil
         (concat (map-indexed (fn [i [header v]]
                                [:td {:key (:index v)}
                                 [antd/form-item {#_#_:rules [{:required true :message "Field is required"}]}
                                  [antd/input {:value      (name header)
                                               :onChange   #(update-template-col @template header (-> % .-target .-value))
                                               :size       "small"
                                               :addonAfter (r/as-element
                                                             [antd/button {:size    "small"
                                                                           :type    "link"
                                                                           :href    "#"
                                                                           :onClick #(delete-template-col % @template header)}
                                                              [antd/delete-icon]])}]]])
                              sorted-attrs)
                 [[:td {:key "add"}
                   ;; add a new column
                   [antd/button {:type "link" :onClick #(add-template-col % @template)}
                    [antd/plus-circle-icon]]]])]]

       [:tbody nil
        [:tr nil [:td {:colSpan 0}]]
        [:tr nil
         ;; attrs list per header
         (for [[header v] sorted-attrs
               :let [vals  (:values v)
                     pairs (sort-by last (zipmap vals (range)))]]
           [:td {:key    (str "attr" (:index v))
                 :valign "top"}
            [:table nil
             [:tbody nil
              ;; build an indexed [val, index]
              (for [pair pairs
                    :let [[val i] pair]]
                [:tr {:key (str "row-" i)}
                 [:td {:key (str "cell-" i)}
                  [antd/input {:value      val
                               :key        (str header "-input-attr-" i)
                               :size       "small"
                               :onChange   #(update-template-attr @template header i (-> % .-target .-value))
                               :addonAfter (r/as-element
                                             [antd/button {:size    "small"
                                                           :type    "link"
                                                           :href    "#"
                                                           :onClick #(delete-template-attr % @template header i)}
                                              [antd/minus-circle-icon]])}]]])
              [:tr nil
               [:td nil
                ;; add a new row
                [antd/button {:size "small" :type "link" :onClick #(add-template-attr % @template header)}
                 [antd/plus-icon]]]]]]])]]]

      ;; save button
      [:hr nil]

      [antd/button {:type "primary" :htmlType "submit"}
       [antd/save-icon] " save"]
      [antd/button {:size    "small"
                    :type    "link"
                    :href    "#"
                    :onClick #(cancel)}
       "Cancel"]]]))

;;;;
;; Template list cell renderers

(defn- render-name [text record]
  (r/as-element [:a {:href "#" :onClick #(rf/dispatch [:ui/edit-template (js->clj record :keywordize-keys true)])}
                 text]))

(defn- render-attributes [_ record]
  (let [clj-record (js->clj record :keywordize-keys true)]
    (str/join ", " (map name (keys (:attributes clj-record))))))

(defn- render-type [_ record]
  (let [clj-record (js->clj record :keywordize-keys true)]
    (or (:type clj-record) "<undefined>")))

(defn- render-video-count [freqs _ record]
  (let [clj-record  (js->clj record :keywordize-keys true)
        template-id (:id clj-record)]
    (get freqs template-id 0)))

(defn- render-actions [_ record]
  (r/as-element
    [:div
     [antd/button {:type    "primary" :size "small"
                   :onClick #(rf/dispatch [:ui/edit-template (js->clj record :keywordize-keys true)])}
      [antd/edit-icon] " edit"]
     [antd/button {:type    "danger" :size "small"
                   :onClick #(rf/dispatch [:ui/delete-template (js->clj record :keywordize-keys true)])}
      [antd/delete-icon] " delete"]]))

(defn- templates-table []
  (let [templates           (rf/subscribe [:templates/all])
        videos-per-template (rf/subscribe [:templates/video-count])]
    [:div
     [antd/table {:dataSource (vals @templates)
                  :size       "small"
                  :rowKey     "name"
                  :bordered   true
                  :pagination {:position "top"}
                  :title      (constantly "Templates")}
      [antd/column {:title "Name" :dataIndex :name :render render-name}]
      [antd/column {:title "# Videos" :render (partial render-video-count videos-per-template)}]
      [antd/column {:title "Type" :render render-type}]
      [antd/column {:title "Attributes" :render render-attributes}]
      [antd/column {:title "Actions" :render render-actions}]]

     [antd/button {:type    "primary" :size "small"
                   :onClick #(rf/dispatch [:ui/add-template nil])}
      [antd/plus-icon] " add template"]]))


(defn show-template-panel [current]
  (if (some? current)
    template-form
    templates-table))

(defn- breadcrumbs []
  (let [current (rf/subscribe [:templates/current])]
    [antd/breadcrumb
     [antd/breadcrumb-item
      [:a {:onClick #(rf/dispatch [:ui/deselect-template])} "templates"]]
     (when (:name @current)
       [antd/breadcrumb-item (:name @current)])]))

(defn ui []
  (let [current (rf/subscribe [:templates/current])]
    [:div
     [breadcrumbs]
     [(show-template-panel @current)]]))


