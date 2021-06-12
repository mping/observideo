(ns observideo.renderer.components.exports
  (:require [clojure.string :as s]
            [promesa.core :as p]
            [reagent.core :as r]
            [re-frame.core :as rf]
            [taoensso.timbre :as log]
            [observideo.common.utils :as utils]
            [observideo.renderer.ipcrenderer :as ipcrenderer]
            [observideo.renderer.components.antd :as antd]))

(defn- start-export [opts]
  (rf/dispatch [:db/export opts]))

(defn ui []
  [:div
   [:h1 "Export data"]
   [:p "Download all your video observations as a csv file.
       A zip file with a csv per video will be created."]
   [:hr]
   [:div
    [antd/row {:gutter [8,8]}
     [antd/col {:span 12}
      [:div
       [antd/button {:type "primary" :onClick #(start-export {:by :index1})}
        [antd/download-icon]
        " Export to CSV (index starts at 1)"]
       [:p "Export the data as zip, with one CSV file per video. Index based."]
       [:p "For a template with the given data:"]
       [:table {:style {:width "100%"}}
        [:thead.ant-table-thead
         [:tr
          [:td [:b "Peer"]]
          [:td [:b "Gender"]]]]
        [:tbody.ant-table-tbody
         [:tr
          [:td "Alone" [:b " 1"]]
          [:td "Same" [:b " 1"]]]
         [:tr
          [:td "Adults" [:b " 2"]]
          [:td "Both" [:b " 2"]]]]]
       [:hr]
       [:p "Each csv file will have the data with the following format:"]
       [:pre"Peer, Gender
1,    1
2,    1
 ,    2
..."]]]

     [antd/col {:span 12} 
      [:div
       [antd/button {:type "primary" :onClick #(start-export {:by :name})}
        [antd/download-icon]
        " Export to CSV (name)"]
       [:p "Export the data as CSV, name based."]
       [:p "For a template with the given data:"]
       [:table {:style {:width "100%"}}
        [:thead.ant-table-thead
         [:tr
          [:td [:b "Peer"]]
          [:td [:b "Gender"]]]]
        [:tbody.ant-table-tbody
         [:tr
          [:td "Alone"]
          [:td "Same"]]
         [:tr
          [:td "Adults"]
          [:td "Both"]]]]
       [:hr]
       [:p "Each csv file will have the data with the following format:"]
       [:pre "Peer,  Gender
Alone,  Same
Adults, Both
      , Both
..."]]]]]])

