Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root 'home#index'
  resources :home do
    get 'callback', on: :collection
    get 'create_new_folder', on: :collection
    post 'upload_new_file', on: :collection
    get 'delete_existing_folder', on: :collection
    get 'download_file', on: :collection
    get 'folder_view', on: :collection
  end

end
