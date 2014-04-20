module Services
  class Railtie < Rails::Railtie
    config.after_initialize do
      Services.configuration.log_dir = Rails.root.join('log')
    end
  end
end
