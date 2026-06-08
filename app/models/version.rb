# frozen_string_literal: true

class Version < ApplicationRecord
  include PaperTrail::VersionConcern
end
