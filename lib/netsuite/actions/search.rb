# TODO: Tests
# TODO: DBC
module NetSuite
	module Actions
		class Search
      include Support::Requests

			def initialize(klass, options = { })
				@klass = klass

        @options = options
			end

      private

      def soap_record_type
        @klass.to_s.split('::').last
      end

      def request
        connection.request :search do
          soap.namespaces['xmlns:platformMsgs'] = "urn:messages_#{NetSuite::Configuration.api_version}.platform.webservices.netsuite.com"
          soap.namespaces['xmlns:platformCore'] = "urn:core_#{NetSuite::Configuration.api_version}.platform.webservices.netsuite.com"
          soap.namespaces['xmlns:listRel'] = "urn:relationships_#{NetSuite::Configuration.api_version}.lists.webservices.netsuite.com"
          soap.namespaces['xmlns:platformCommon'] = "urn:common_#{NetSuite::Configuration.api_version}.platform.webservices.netsuite.com"

          soap.header = auth_header
          
          soap.body = request_body
        end
      end

      def request_body
        buffer = ''

        xml = Builder::XmlMarkup.new(target: buffer)

        # TODO: Consistent use of namespace qualifying
        xml.searchRecord('xsi:type' => "listRel:#{soap_record_type}Search") do |search_record|
          search_record.basic('xsi:type' => "platformCommon:#{soap_record_type}SearchBasic") do |basic|
            @options.each do |field_name, field_value|
            	# TODO: Add ability to use other operators
            	# TODO: Add ability to use other field types
              basic.method_missing(field_name, {
                operator: 'contains',
                'xsi:type' => 'platformCore:SearchStringField'
              }) do |_field_name|
                _field_name.platformCore :searchValue, field_value
              end
            end
          end
        end

        buffer
      end

      def response_header
        @response_header ||= response_header_hash
      end

      def response_header_hash
        @response_header_hash = @response.header[:document_info]
      end

      def response_body
        @response_body ||= response_body_hash
      end

      def response_body_hash
        @response_body_hash = @response[:search_response][:search_result]
      end

      def success?
        @success ||= response_body_hash[:status][:@is_success] == 'true'
      end

      module Support
        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods
          def search(options = { })
            response = NetSuite::Actions::Search.call(self, options)
            
            response_hash = { }

            if response.success?
              response_list = []

              response.body[:record_list][:record].each do |record|
                entity = new(record)

                response_list << entity
              end

              search_id = response.header[:ns_id]
              page_index = response.body[:page_index]
              total_pages = response.body[:total_pages]

              response_hash[:search_id] = search_id
              response_hash[:page_index] = page_index
              response_hash[:total_pages] = total_pages
              response_hash[:entities] = response_list

              response_hash
            else
              raise ArgumentError
            end
          end
        end
      end
		end
	end
end