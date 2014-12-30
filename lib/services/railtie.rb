module Services
  class Railtie < Rails::Railtie
    # Require `Services::Query` here since it relies
    # on Rails.application to be present.
    initializer 'services.load_services_query' do
      require 'services/query'
    end
  end
end
