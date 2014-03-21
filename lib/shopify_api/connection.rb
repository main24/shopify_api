module ShopifyAPI
  class Connection < ActiveResource::Connection
    attr_reader :response

    module ResponseCapture
      def handle_response(response)
        @response = super
      end
    end

    include ResponseCapture

    module RequestNotification
      def request(method, path, *arguments)
        super.tap do |response|
          notify_about_request(response, arguments)
        end
      rescue => e
        notify_about_request(e.response, arguments) if e.respond_to?(:response)
        raise
      end

      def notify_about_request(response, arguments)
        ActiveSupport::Notifications.instrument("request.active_resource_detailed") do |payload|
          payload[:response] = response
          payload[:data]     = arguments
        end
      end
    end

    include RequestNotification

    module RedoIfTemporaryError
      def request(*args)
        super
      rescue ActiveResource::ClientError, ActiveResource::ServerError => e
        if e.response.class.in?(Net::HTTPTooManyRequests, Net::HTTPInternalServerError)
          wait
          request *args
        else
          raise
        end
      end

      def wait
        sleep 0.5
      end
    end

    include RedoIfTemporaryError
  end
end
