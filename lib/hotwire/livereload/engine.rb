require "rails"
require "action_cable/engine"
require "listen"

module Hotwire
  module Livereload
    class Engine < ::Rails::Engine
      isolate_namespace Hotwire::Livereload
      config.hotwire_livereload = ActiveSupport::OrderedOptions.new
      config.hotwire_livereload.listen_paths ||= []
      config.autoload_once_paths = %W(
        #{root}/app/channels
        #{root}/app/helpers
      )

      initializer "hotwire_livereload.assets" do
        if Rails.application.config.respond_to?(:assets)
          Rails.application.config.assets.precompile += %w( hotwire-livereload.js )
        end
      end

      initializer "hotwire_livereload.helpers" do
        ActiveSupport.on_load(:action_controller_base) do
          helper Hotwire::Livereload::LivereloadTagsHelper
        end
      end

      initializer "hotwire_livereload.set_configs" do |app|
        options = app.config.hotwire_livereload
        options.listen_paths = options.listen_paths.map(&:to_s)

        default_paths = %w[
          app/views
          app/helpers
          app/javascript
          app/assets/stylesheets
          app/assets/javascripts
          app/assets/images
          app/components
          config/locales
        ].map { |p| Rails.root.join(p).to_s }
        options.listen_paths += default_paths.select { |p| Dir.exist?(p) }
      end

      config.after_initialize do |app|
        if Rails.env.development? && defined?(Rails::Server)
          listen_paths = app.config.hotwire_livereload.listen_paths.uniq
          @listener = Listen.to(*listen_paths) do |modified, added, removed|
            unless File.exists?(DISABLE_FILE)
              if (modified.any? || removed.any? || added.any?)
                content = { modified: modified, removed: removed, added: added }
                ActionCable.server.broadcast("hotwire-reload", content)
              end
            end
          end
          @listener.start
        end
      end

      at_exit do
        if Rails.env.development?
          @listener&.stop
        end
      end
    end
  end
end
