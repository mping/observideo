(ns observideo.renderer.subs
  (:require [re-frame.core :as rf :refer [reg-sub subscribe]]))

;;;;
;; UI

(rf/reg-sub :ui/active-tab (fn [db _] (:ui/tab db)))
(rf/reg-sub :ui/timestamp (fn [db _] (:ui/timestamp db)))

;;;;
;; Main

(rf/reg-sub :videos/folder (fn [db _] (:videos/folder db)))
(rf/reg-sub :videos/all (fn [db _] (:videos/all db)))
(rf/reg-sub :videos/current (fn [db _] (:videos/current db)))

(rf/reg-sub :templates/all (fn [db _] (:templates/all db)))
(rf/reg-sub :templates/current (fn [db _] (:templates/current db)))