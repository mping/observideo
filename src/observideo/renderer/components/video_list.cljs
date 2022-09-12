(ns observideo.renderer.components.video-list
  (:require [clojure.string :as s]
            [promesa.core :as p]
            [reagent.core :as r]
            [re-frame.core :as rf]
            [taoensso.timbre :as log]
            [observideo.common.utils :as utils]
            [observideo.renderer.ipcrenderer :as ipcrenderer]
            [observideo.renderer.components.video-edit :as video-edit]
            [observideo.renderer.components.antd :as antd]
            [observideo.renderer.components.player :as player]
            ["electron" :as electron :refer [dialog]]))

;(defonce dialog (.-dialog remote))

;;;;
;; actions

(defn- select-dir []
  (let [opts (clj->js {:properties ["openDirectory"]})
        dir  (.showOpenDialog dialog opts)]
    (-> (p/resolved dir)
      (p/then (fn [arg]
                (let [[dir] (aget arg "filePaths")]
                  (rf/dispatch [:ui/update-videos-folder {:folder dir}]))))
      (p/catch (fn [err] (log/warn err))))))

;;;;
;; UI


;;;;
;;main listing

(defn- render-filename [text record]
  (let [folder    @(rf/subscribe [:videos/folder])
        filename  (utils/relname folder text)
        clj-obj   (js->clj record :keywordize-keys true)
        missing?  (:missing? clj-obj)
        component (if missing? [:p {:title "The file is missing"}
                                [antd/warning-icon]
                                filename]

                      [:a {:href    "#"
                           :onClick #(rf/dispatch [:ui/select-video clj-obj])}
                       filename])]
    (r/as-element component)))

(defn- render-size [text record]
  (r/as-element [:span text]))

(defn- render-template [text record]
  (let [templates @(rf/subscribe [:templates/all])]
    (r/as-element [:span (get-in templates [text :name])])))

(defn- render-duration [text record]
  (r/as-element [:span (int text) "s"]))

(defn- render-info [val record]
  (let [info (js->clj val :keywordize-keys true)]
    (r/as-element [:span (:a info)])))

(defn- render-actions [_ record]
  (r/as-element [antd/button {:type    "primary" :size "small"
                              :onClick #(rf/dispatch [:ui/select-video (js->clj record :keywordize-keys true)])}
                 [antd/edit-icon]
                 " edit"]))

(defn- videos-table []
  (let [folder @(rf/subscribe [:videos/folder])
        videos @(rf/subscribe [:videos/all])
        videos (vals videos)]
    [antd/table {:dataSource videos
                 :rowKey     :filename
                 :size       "small"
                 :bordered   true
                 :pagination {:position "top"}
                 :title      #(r/as-element
                                [:span
                                 (str "current directory: " folder)
                                 (when folder
                                   [:a {:title "Reload"
                                        :onClick (fn [_] (rf/dispatch [:ui/update-videos-folder {:folder folder}]))}
                                    " "
                                    [antd/reload-icon]])])}
     [antd/column {:title "File" :dataIndex :filename :key :filename :render render-filename}]
     [antd/column {:title "Size" :dataIndex :size :key :size :render render-size}]
     [antd/column {:title "Template" :dataIndex :template-id :key :template-id :render render-template}]
     [antd/column {:title "Info" :dataIndex :info :key :info :render render-info}]
     [antd/column {:title "Duration" :dataIndex :duration :key :duration :render render-duration}]
     [antd/column {:title     "Actions"
                   :dataIndex :action
                   :key       :action
                   :render    render-actions}]]))

(defn root []
  (let [folder @(rf/subscribe [:videos/folder])]
    [:div
     [antd/button {:type "primary" :onClick #(select-dir)}
      [antd/upload-icon]
      " Open a directory"]
     [videos-table]]))
