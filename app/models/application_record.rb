class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  unless Rails.env.test?
    connects_to database: { writing: :primary, reading: :primary_replica }
  end
end
