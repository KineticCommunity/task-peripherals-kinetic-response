# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

# Require the REXML ruby library.
require 'rexml/document'

class KineticRequestCeUsersRetrieveV1
  # Prepare for execution by building Hash objects for necessary values, and
  # validating the present state.  This method sets the following instance
  # variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @parameters - A Hash of parameter names to parameter values.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml
  #   handler template.
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    @formatter = REXML::Formatters::Pretty.new
    @formatter.compact = true

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") do |item|
      @info_values[item.attributes["name"]] = item.text.to_s.strip
    end

    # Retrieve all of the handler parameters and store them in a hash attribute
    # named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, "/handler/parameters/parameter").each do |item|
      # Associate the attribute name to the String value (stripping leading and
      # trailing whitespace)
      @parameters[item.attributes["name"]] = item.text.to_s.strip
    end
  end

  def execute
    begin
      space_slug = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]

      # API Route
      api_route = @info_values["api_server"] + "/" + space_slug + "/app/api/v1/users"


      puts "API ROUTE: #{api_route}"

      resource = RestClient::Resource.new(api_route,
                                          user: @info_values["api_username"],
                                          password: @info_values["api_password"])
      # Request to the API
      result = resource.get

    # If the credentials are invalid
    rescue RestClient::Unauthorized
      raise StandardError, "(Unauthorized): You are not authorized."
    rescue RestClient::ResourceNotFound => error
      raise StandardError, error.response
    end

    # Build the results to be returned by this handler
    results = ''
    # if the user record did not exist
    if result.nil?
      results = <<-RESULTS
      <results>
        <result name="count"></result>
        <result name="users"></result>
        <result name="XML"></result>
        <result name="idList"></result>
      </results>
      RESULTS
    else
      #puts "RESULT: #{result.inspect}"
      results = JSON.parse(result)['users']
      count = results.count
      usernameList = "<usernames>"

      results.each do |thisResult|
        usernameList << "<username>" + thisResult["username"] + "</username>"
      end

      usernameList << "</usernames>"
      xml = convert_json_to_xml(results.to_json)
      string = @formatter.write(xml, "")

      puts "RESULTS: #{results.inspect}"

      results = <<-RESULTS
      <results>
        <result name="count">#{escape(results.count)}</result>
        <result name="users">#{escape(results.to_json)}</result>
        <result name="XML">#{escape(string)}</result>
        <result name="usernameList">#{escape(usernameList)}</result>
      </results>
      RESULTS
    end

  # Return the results String
    return results
  end


  # This method converts a Ruby JSON Hash to a REXML::Element object.  The REXML::Element
  # that is returned is the root node of the XML structure and all of the resulting
  # XML data will be nested within that single element.
  def convert_json_to_xml(data, label=nil)
    if data.is_a?(Hash)
      element = REXML::Element.new("node")
      element.add_attribute("type", "Object")
      element.add_attribute("name", label) if label
      data.keys.each do |key|
        element.add_element(convert_json_to_xml(data[key], key))
      end
      element
    elsif data.is_a?(Array)
      element = REXML::Element.new("node")
      element.add_attribute("type", "Array")
      element.add_attribute("name", label) if label
      data.each do |child_data|
        element.add_element(convert_json_to_xml(child_data))
      end
      element
    else
      element = REXML::Element.new("node")
      element.add_attribute("type", data.class.name)
      element.add_attribute("name", label) if label
      element.add_text(data.to_s)
      element
    end
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

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_info_value(document, name)
    # Retrieve the XML node representing the desired info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
end
