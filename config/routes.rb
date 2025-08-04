# frozen_string_literal: true

Rails.application.routes.draw do
  resources :sensitive_logs, only: [:index, :show, :destroy] do
    collection do
      post :cleanup
    end
  end
  
  resources :detection_rules, only: [:index, :new, :create, :edit, :update, :destroy]
  
  resources :sensitive_operations, only: [] do
    member do
      post :override
    end
  end
end 