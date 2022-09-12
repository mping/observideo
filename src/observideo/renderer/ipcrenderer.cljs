(ns observideo.renderer.ipcrenderer
  (:require [cljs.reader]
            [re-frame.core :as rf]
            [goog.object :as gobj]
            [taoensso.timbre :as log]
            [observideo.common.serde :as serde]
            [observideo.renderer.components.antd :as antd]
            ["electron" :as electron]))

;;;;;;;;;;;;;;;;;;;;;;;;
;;; IPC Main <> Renderer

(def ipcRenderer (gobj/get electron "ipcRenderer"))

;;;;
;; renderer >> main

;; post messages from renderer to main
(defn send-message [event data]
  ;(log/debugf ">>[%s] %s" event data)
  (log/debugf ">>[%s]" event)
  (.send ipcRenderer "event" (serde/serialize {:event (subs (str event) 1) :data data})))

;; called when the renderer received an ipc message
(defmulti handle (fn [event _ _] event) :default :unknown)

(defmethod handle :main/update-videos [event sender data]
  (let [videos (:videos data)
        folder (:folder data)]
    (rf/dispatch [:main/update-videos {:videos videos :folder folder}])))

(defmethod handle :main/reset-db [event sender data]
  (rf/dispatch [:db/reset data]))

(defmethod handle :main/export-errors [event sender data]
  ;; TODO: notifications are ephemeral
  ;; but it would be nice to put them in the db
  ;; and pop them after consuming them in a given UI view
  (doseq [notif data]
    (js/console.log (clj->js (assoc notif :placement "topRight")))
    (antd/notify-warning (clj->js (assoc notif :placement "topRight" :duration 0)))))

(defmethod handle :unknown [event sender data]
  (log/warnf "UNKNOWN EVENT %s" data))

;; main handler
(defn handle-message [evt jsdata]
  (let [sender      (.-sender evt)
        datum (serde/deserialize jsdata)
        {:keys [event data]} datum]
    ;(log/debugf "<<[%s] %s" event data)
    (log/debugf "<<[%s]" event)
    (handle (keyword event) sender data)))
