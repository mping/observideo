(ns observideo.renderer.events
  (:require
   [re-frame.core :as rf]
   ;[day8.re-frame.tracing :refer-macros [fn-traced]]
   [observideo.renderer.interceptors :as interceptors]))

(def ^{:private true} demo-id (str (random-uuid)))

(def demo-template {:id         demo-id
                    :name       "Demo"
                    :interval   15
                    :next-index 3                           ;;monotonic counter to ensure old indexes preserve their value
                    :attributes {"Peer"   {:index 0 :values ["Alone" "Adults" "Peers" "Adults and Peers" "N/A"]}
                                 "Gender" {:index 1 :values ["Same" "Opposite" "Both" "N/A"]}
                                 "Type"   {:index 2 :values ["Roleplay" "Rough and Tumble" "Exercise"]}}})

(def demo-video {:filename        "/home/mping/Download … deo_720x480_30mb.mp4"
                 :duration        183.318
                 :info            {:a "changeme"}
                 :md5sum          "changeme"
                 :size            31551484
                 :current-section {:time 0, :index 0}
                 :observations    [{"Peer" nil "Gender" "Same" "Type" "Exercise"}, {}]
                 :template-id     "7dd2479d-e829-4762-a0ac-de51a68461b5"})


(defn empty-db []
  {:ui/tab            :videos
   :ui/timestamp      (str (js/Date.))

   ;; videos list is a vec because they are in the filesystem
   :videos/folder     nil                                   ;;string
   :videos/all        nil                                   ;;map
   :videos/current    nil                                   ;;map

   ;; templates are keyed by :id because it facilitates CRUD operations
   :templates/all     {(:id demo-template) demo-template}   ;; {uuid -> map}
   :templates/current nil})                                 ;;map

;;;;
;; Core events

(rf/reg-event-db
  :db/initialize
  (fn [_ _] (empty-db)))

(rf/reg-event-db
  :db/load
  (fn [db server-db] (merge db server-db)))

;;;;
;; IPC events

(rf/reg-event-db
  :main/update-videos
  (fn [db [_ {:keys [folder videos]}]]
    (assoc db :videos/folder folder
              :videos/all (reduce (fn [m v] (assoc m (:filename v) v)) {} videos))))

;;;;
;; User events

(rf/reg-event-db
  :ui/ready
  [interceptors/ipc2main-interceptor]
  (fn [db _] db))

;;;;
;; videos

(rf/reg-event-db
  :ui/update-videos-folder
  [interceptors/ipc2main-interceptor]
  (fn [db [_ folder]]
    (assoc db :videos/folder folder)))

(rf/reg-event-db
  :ui/select-video
  ;; TODO assoc only video id
  (fn [db [_ video]] (assoc db :videos/current video)))

(rf/reg-event-db
  :ui/deselect-video
  (fn [db [_ _]] (assoc db :videos/current nil)))

(rf/reg-event-db
  :ui/change-active-tab
  (fn [db [_ tab]] (assoc db :ui/tab tab)))


;;;;
;; video editing

(defn- count-observations [duration step-interval]
  (+ (int (/ duration step-interval))
    (if (> (mod duration step-interval) 0) 1 0)))

(defn- make-empty-observations [template n]
  (->> (range)
    (take n)
    (map (fn [_]
           (let [attrs (:attributes template)]
             ;; create a mapping {"name" => nil}
             (reduce-kv (fn [m k _] (assoc m k nil)) {} attrs))))
    (vec)))

(rf/reg-event-db
  :ui/update-current-video-template
  (fn [db [_ id]]
    (let [current-video      (:videos/current db)
          template           (get-in db [:templates/all id])
          template-interval  (:interval template)
          total-observations (count-observations (:duration current-video) template-interval)
          new-observations   (make-empty-observations template total-observations)
          updated-video      (assoc current-video :template-id id :observations new-observations)
          fullpath           (:filename updated-video)]
      (-> db
        (assoc-in [:videos/current] updated-video)
        (assoc-in [:videos/all fullpath] updated-video)))))

(rf/reg-event-db
  :ui/update-current-video-section
  (fn [db [_ time index]]
    (let [current-video (:videos/current db)
          updated-video (assoc current-video :current-section {:time time :index index})
          fullpath      (:filename updated-video)]
      (-> db
        (assoc-in [:videos/current] updated-video)
        (assoc-in [:videos/all fullpath] updated-video)))))

(rf/reg-event-db
  :ui/update-current-video-current-section-observation
  (fn [db [_ observation]]
    (let [current-video     (:videos/current db)
          observation-index (get-in current-video [:current-section :index])
          updated-video     (assoc-in current-video [:observations observation-index] observation)
          fullpath          (:filename updated-video)]
      (-> db
        (assoc-in [:videos/current] updated-video)
        (assoc-in [:videos/all fullpath] updated-video)))))

;;;;
;; templates

(rf/reg-event-db
  :ui/add-template
  (fn [db [_ _]]
    (let [new-template (dissoc demo-template :id)
          id           (str (random-uuid))]
      (-> db
        (assoc-in [:templates/all id] (assoc new-template :id id))))))

(rf/reg-event-db
  :ui/edit-template
  (fn [db [_ template]]
    ;; make a copy
    (assoc db :templates/current (merge {} (get-in db [:templates/all (:id template)])))))

(rf/reg-event-db
  :ui/update-template
  (fn [db [_ {:keys [id] :as template}]]
    (-> db
      (assoc-in [:templates/all id] template))))

(rf/reg-event-db
  :ui/update-current-template
  (fn [db [_ template]]
    (-> db
      (assoc-in [:templates/current] template))))

(rf/reg-event-db
  :ui/delete-template
  (fn [db [_ template]]
    (let [id (:id template)]
      (-> db
        (dissoc :templates/all id)))))

(rf/reg-event-db
  :ui/deselect-template
  (fn [db [_ _]] (assoc db :templates/current nil)))
