(ns observideo.main.ipcmain
  (:require
    [observideo.main.media :as media]
    [observideo.main.db :as db]
    [taoensso.timbre :as log]
    [observideo.common.serde :as serde]
    ["electron" :as electron :refer [BrowserWindow remote app ipcRender ipcMain]]
    ["electron-dl" :as electron-dl :refer [download]]
    [promesa.core :as p]))

;;;;
;; utils
;; https://github.com/brianium/tomaat/blob/master/src/tomaat/util.cljs
(def electron (js/require "electron"))
(def app (.-app electron))

(defn- browser-window-ctor []
  (or BrowserWindow (.-BrowserWindow remote)))

(defn- current-focused-window []
  (->> (browser-window-ctor)
    .getFocusedWindow))

(defn current-window-id []
  (->> (browser-window-ctor)
    .getFocusedWindow
    .-id))

(defn- web-contents
  "Get the webContents of a browser window identified by id"
  [id]
  (->> id
    (.fromId (browser-window-ctor))
    .-webContents))


;; see https://github.com/electron/electron/blob/v3.0.16/docs/api/ipc-main.md

;;;;
;; IPC

(defn send-message
  ([event data]
   (send-message (web-contents (current-window-id)) event data))
  ([webcontents event data]
   ;(log/debugf ">>[%s] %s" event data)
   (log/debugf ">>[%s]" event)
   (.send webcontents "event" (serde/serialize {:event (subs (str event) 1) :data data}))))

;; called when the renderer received an ipc message
(defmulti handle (fn [event _ _] event) :default :unknown)

;;;;
;; ipc/ui
(defmethod handle :ui/update-videos-folder [_ sender data]
  (if-let [folder (:folder data)]
    ;; TODO loading event?
    (-> (media/read-dir folder)
        (.then #(send-message sender :main/update-videos {:videos % :folder folder})))
    (log/warnf ":ui/update-videos-folder called with empty folder: %s", data)))


(defmethod handle :ui/ready [_ sender _]
  (send-message sender :main/reset-db @db/db))
    ;; the very first time it may be empty

(defmethod handle :db/update [event sender data]
  (db/overwrite data))

(defmethod handle :db/query [event sender data]
  (println "IMPLEMENT ME"))

;; download fn provided by electron-dl
(declare download)

(defmethod handle :db/export [event sender data]
  (let [export (db/export-to-csv data)]
    (-> export
        (p/then (fn [{:keys [file errors]}]
                  (send-message :main/export-errors errors)
                  (download (current-focused-window) file #js {:saveAs true :openFolderWhenDone true})))
      (p/then (fn [f]
               (log/infof "Export done" f))))))



(defmethod handle :query/export [event sender data]
  (let [url (db/export-result-to-csv data)]
    (-> url
      (p/then (fn [{:keys [file errors]}]
                (download (current-focused-window) file #js {:saveAs true :openFolderWhenDone true})))
      (p/then (fn [f]
                (log/infof "Export done" f))))))


;;;;
;; ipc/ui

(defmethod handle :unknown [event sender data]
  (log/warn "UNKNOWN EVENT %s" event))

;;;;
;; main handler
(defn handle-message [evt jsdata]
  (let [sender (.-sender evt)
        datum  (serde/deserialize jsdata)
        {:keys [event data]} datum]
    ;(log/debugf "<<[%s] %s" (keyword event) data)
    (log/debugf "<<[%s]" (keyword event))
    (handle (keyword event) sender data)))
