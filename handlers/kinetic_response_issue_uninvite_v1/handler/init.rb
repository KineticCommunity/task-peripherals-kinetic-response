# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticResponseIssueUninviteV1

  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") { |item|
      @info_values[item.attributes['name']] = item.text
    }
    @enable_debug_logging = @info_values['enable_debug_logging'].downcase == 'true'

    # Store parameters values in a Hash of parameter names to values.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text.to_s
    end

    raise "A valid api_server must be configured for the handler" if @info_values["api_server"].to_s.empty?
  end

  def execute
    api_username          = URI.encode(@info_values["api_username"].to_s)
    api_password          = @info_values["api_password"]
    api_server            = @info_values["api_server"]
    error_handling        = @parameters["error_handling"]
    api_route = "#{@info_values["api_server"]}/api/v1/issues/#{@parameters['issue_guid']}"

    resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })

    handler_error_message = nil
    begin

      # Check to see if the email is included in the invites list
      puts "Retrieving the list of users currently invited to the response" if @enable_debug_logging
      invited_resp = resource["/invites"].get
      invites = JSON.parse(invited_resp.body)

      invites.each do |invite|
        if invite["email"].downcase == @parameters["email"].downcase.strip
          puts "Attempting to delete '#{@parameters["email"]}' from the issue '#{@parameters['issue_guid']}'" if @enable_debug_logging
          resource["/invites/#{invite["guid"]}"].delete
          break
        end
      end

      # Check to see if the email is included in the participants list
      puts "Retrieving the list of users currently participating in the response" if @enable_debug_logging
      participant_resp = resource["/participants"].get
      participants = JSON.parse(participant_resp.body)

      participants.each do |user|
        if user["email"].downcase == @parameters["email"].downcase.strip
          puts "Attempting to delete '#{@parameters["email"]}' from the issue '#{@parameters['issue_guid']}'" if @enable_debug_logging
          resource["/participants/#{user["guid"]}"].delete
          break
        end
      end

    rescue RestClient::ResourceNotFound
      if error_handling == "Raise Error"
        raise
      else
        handler_error_message = "The Response issue '#{@parameters['issue_guid']}' cannot be found"
      end
    rescue RestClient::Exception => error
      begin
        error_message = JSON.parse(error.response)["reasons"]
      rescue Exception => e
        error_message = error.inspect
      end
      if error_handling == "Raise Error"
        raise error_message
      else
        handler_error_message = "#{error.http_code}: #{escape(error_message)}"
      end
    end

    results = <<-RESULTS
    <results>
      <result name="Handler Error Message">#{escape(handler_error_message)}</result>
    </results>
    RESULTS

    return results
  end

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}
end
