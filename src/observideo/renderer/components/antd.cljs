(ns observideo.renderer.components.antd
  (:require [reagent.core :as reagent]
            ["regenerator-runtime/runtime"]
            ["antd" :refer [Layout Menu Breadcrumb Icon Button PageHeader Table Breadcrumb
                            Row Col
                            Form Select Input Slider Icon Affix
                            notification]]
            ["@ant-design/icons" :refer [VideoCameraOutlined TagsOutlined BarChartOutlined
                                         UploadOutlined EditOutlined DeleteOutlined SaveOutlined DownloadOutlined
                                         PlusCircleOutlined MinusCircleOutlined MinusOutlined PlusOutlined
                                         WarningOutlined ReloadOutlined]]))


(comment
  (def icon (reagent/adapt-react-class Icon))
  (defn videos-icon [] [icon {:type "video-camera"}])
  (defn templates-icon [] [icon {:type "tags"}])
  (defn queries-icon [] [icon {:type "bar-chart"}])
  (defn upload-icon [] [icon {:type "upload"}])
  (defn edit-icon [] [icon {:type "edit"}])
  (defn delete-icon [] [icon {:type "delete"}])
  (defn save-icon [] [icon {:type "save"}])
  (defn plus-circle-icon [] [icon {:type "plus-circle"}])
  (defn minus-circle-icon [] [icon {:type "minus-circle"}])
  (defn plus-icon [] [icon {:type "plus"}])
  (defn minus-icon [] [icon {:type "minus"}]))

;;
(def videos-icon (.-render VideoCameraOutlined))
(def templates-icon (.-render TagsOutlined))
(def queries-icon (.-render BarChartOutlined))

(def upload-icon (.-render UploadOutlined))
(def download-icon (.-render DownloadOutlined))
(def reload-icon (.-render ReloadOutlined))
(def edit-icon (.-render EditOutlined))
(def delete-icon (.-render DeleteOutlined))
(def save-icon (.-render SaveOutlined))

(def plus-circle-icon (.-render PlusCircleOutlined))
(def minus-circle-icon (.-render MinusCircleOutlined))
(def minus-icon (.-render MinusOutlined))
(def plus-icon (.-render PlusOutlined))
(def warning-icon (.-render WarningOutlined))

;;;;
;;
(def layout (reagent/adapt-react-class Layout))
(def row (reagent/adapt-react-class Row))
(def col (reagent/adapt-react-class Col))
(def header (reagent/adapt-react-class (.-Header Layout)))
(def content (reagent/adapt-react-class (.-Content Layout)))
(def sider (reagent/adapt-react-class (.-Sider Layout)))
(def footer (reagent/adapt-react-class (.-Footer Layout)))
(def menu (reagent/adapt-react-class Menu))
(def submenu (reagent/adapt-react-class (.-SubMenu Menu)))
(def menuitem (reagent/adapt-react-class (.-Item Menu)))

(def page-header (reagent/adapt-react-class PageHeader))
(def affix (reagent/adapt-react-class Affix))

(def button (reagent/adapt-react-class Button))
(def table (reagent/adapt-react-class Table))
(def columngroup (reagent/adapt-react-class (.-ColumnGroup Table)))
(def column (reagent/adapt-react-class (.-Column Table)))

(def form (reagent/adapt-react-class Form))
(def form-item (reagent/adapt-react-class (aget Form "Item")))
(def input (reagent/adapt-react-class Input))
(def select (reagent/adapt-react-class Select))
(def option (reagent/adapt-react-class (aget Select "Option")))
(def input-group (.-Group Input))
(def slider (reagent/adapt-react-class Slider))

(def notify-success (aget notification "success"))
(def notify-info (aget notification "info"))
(def notify-warning (aget notification "warning"))
(def notify-error (aget notification "error"))

(comment
  ;; https://ant.design/components/notification/#API
  (notify-warning #js {:message "xxx" :description "YYY" :placement "topRight"}))

(def breadcrumb (reagent/adapt-react-class Breadcrumb))
(def breadcrumb-item (reagent/adapt-react-class (aget Breadcrumb "Item")))
(def breadcrumb-sep (reagent/adapt-react-class (aget Breadcrumb "Separator")))


