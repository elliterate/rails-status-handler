# == Rails Status Handler
#
# This custom mongrel handler is designed to check if the
# current mongrel instance is busy handling a rails request.
# 
# It is accessible via the "/status" URI.
#
# === Responses
#
# <tt>200 OK</tt>:: the instance is available for requests
# <tt>503 Service Unavailable</tt>:: the instance is currently busy processing a request

class RailsStatusHandler < Mongrel::HttpHandler
  def process(request, response)
    busy = false

    # The server (listener) uses a "classifier" to handle its
    # request routing.
    classifier = listener.instance_variable_get(:@classifier)

    # The classifier has a routing map with instances of all the 
    # handlers.  These handler instances are used by mongrel to 
    # process the actual requests.
    classifier.handler_map.values.flatten.each do |handler|
      # If we find the rails handler...
      if handler.is_a?(Mongrel::Rails::RailsHandler)
        # ...and grab its mutex...
        guard = handler.instance_variable_get(:@guard)

        # ...we should be able to see if it's busy.
        busy = true if guard.locked?
      end
    end

    status = busy ? 503 : 200

    response.start(status) do |head, out|
      head["Content-Type"] = "text/plain"

      # We'll repeat the status code in the body to give uptime
      # tracking software something to look for to be sure this
      # request was successful.
      out.write "#{status} #{Mongrel::HTTP_STATUS_CODES[status]}"
    end
  end
end

uri "/status", :handler => RailsStatusHandler.new, :in_front => true
