if (Rails.env.production? && SiteSetting.logging_provider == 'lograge') || ENV["ENABLE_LOGRAGE"]
  require 'lograge'

  Rails.application.configure do
    config.lograge.enabled = true

    logstash_formatter = ENV["LOGSTASH_FORMATTER"]

    config.lograge.custom_options = lambda do |event|
      exceptions = %w(controller action format id)

      params = event.payload[:params].except(*exceptions)
      params[:files].map!(&:headers) if params[:files]

      output = {
        params: params.to_query,
        database: RailsMultisite::ConnectionManagement.current_db,
        hostname: `hostname`,
      }

      if logstash_formatter
        output[:type] = :rails
      else
        output[:time] = event.time
      end

      output
    end

    if logstash_formatter
      config.lograge.formatter = Lograge::Formatters::Logstash.new

      require 'logstash-logger'

      config.lograge.logger = LogStashLogger.new(
        type: :multi_delegator,
        outputs: [
          {
            type: :file,
            path: "#{Rails.root}/logs/#{Rails.env}.log"
          },
          {
            type: :tcp,
            host: 'logstash-node-json',
            port: 5151,
            sync: true
          }
        ]
      )
    end
  end
end
