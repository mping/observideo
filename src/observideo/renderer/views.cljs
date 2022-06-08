(ns observideo.renderer.views
  (:require [re-frame.core :as rf]
            [observideo.renderer.components.antd :as antd]
            [observideo.renderer.components.templates :as templates]
            [observideo.renderer.components.queries :as queries]
            [observideo.renderer.components.exports :as exports]
            [observideo.renderer.components.videos :as videos]))

(defn selected-tab [active]
  (case active
    :queries queries/ui
    :templates templates/ui
    :videos videos/ui
    :exports exports/ui
    ;;default
    [:h1 (str "Unknown: " active)]))

(defn root []
  (let [active  @(rf/subscribe [:ui/active-tab])]

    [antd/layout {:hasSider true}

     [antd/sider {:collapsible false :collapsed true :theme "light"}
      [:div.logo
       [antd/menu {:mode "inline" :theme "light" :defaultSelectedKeys [(name (or active :videos))]}
        [antd/menuitem {:key "videos" :onClick #(rf/dispatch [:ui/change-active-tab :videos])}
         [antd/videos-icon]
         [:span "Videos"]]
        [antd/menuitem {:key "templates" :onClick #(rf/dispatch [:ui/change-active-tab :templates])}
         [antd/templates-icon]
         [:span "Templates"]]
        [antd/menuitem {:key "queries" :onClick #(rf/dispatch [:ui/change-active-tab :queries])}
         [antd/queries-icon]
         [:span "Queries"]]
        [antd/menuitem {:key "exports" :onClick #(rf/dispatch [:ui/change-active-tab :exports])}
         [antd/download-icon]
         [:span "Export"]]]]]

     [antd/content {:style {:background "#fff" :padding "5px"}}
      [(selected-tab active)]]

     #_
     [antd/footer
      "footer"]]))

(defn ui
  []
  [root])
