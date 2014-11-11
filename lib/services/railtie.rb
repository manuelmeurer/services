module Services
  class Railtie < Rails::Railtie
    # Require the base finder here since it relies
    # on Rails.application to be present
    initializer 'services.load_base_finder' do
      require 'services/base_finder'
    end

    config.after_initialize do
      Services.configuration.log_dir = Rails.root.join('log')
    end
  end
end
