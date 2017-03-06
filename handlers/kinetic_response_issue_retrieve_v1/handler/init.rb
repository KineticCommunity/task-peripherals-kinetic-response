# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class KineticResponseIssueRetrieveV1

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

  end

  def execute
    auth_token = get_auth_token
    resource = RestClient::Resource.new(@info_values["api_server"] + "/api/v1/issues/" + @parameters['issue_guid'])

    issues = nil
    handler_error_message = nil
    begin
      result = resource.get({ accept: :json, content_type: :json, authorization: "Bearer #{auth_token}" })
      issues = result.body
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

    # Return the results
    return <<-RESULTS
    <results>
        <result name="issues">#{escape(issues)}</result>
        <result name="Handler Error Message">#{escape(handler_error_message)}</result>
    </results>
    RESULTS
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

  def get_auth_token
    resource = RestClient::Resource.new(@info_values["api_server"] + "/api/v1/sessions")

    data = {
             "user_login" => {
               "email" => @info_values["api_username"],
               "password" => @info_values["api_password"]
             }
           }

    result = resource.post(data.to_json, { accept: :json, content_type: :json })
    auth_token = JSON.parse(result)["auth_token"]
  end

end
