# frozen_string_literal: true

class Project < ApplicationRecord
  has_many :requests, dependent: :destroy

  validates :name, presence: true
  validates :repo_url, presence: true
end
