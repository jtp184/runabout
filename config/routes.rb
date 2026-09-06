Rails.application.routes.draw do
  root "dashboard#index"
  post "commands", to: "commands#create"
  post "corrections", to: "corrections#create"
  get "entities/:id", to: "details#entity", as: :entity
  get "people/:id", to: "details#person", as: :person
  get "article", to: "details#article", as: :article
  get "detail/close", to: "details#close", as: :close_detail
  get "photos/:kind/:id", to: "photos#show", as: :photo
  get "up" => "rails/health#show", as: :rails_health_check
end
