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
        connection.request(:search) do
          soap.namespaces['xmlns:platformMsgs'] = "urn:messages_#{NetSuite::Configuration.api_version}.platform.webservices.netsuite.com"
          soap.namespaces['xmlns:platformCore'] = "urn:core_#{NetSuite::Configuration.api_version}.platform.webservices.netsuite.com"
          soap.namespaces['xmlns:platformCommon'] = "urn:common_#{NetSuite::Configuration.api_version}.platform.webservices.netsuite.com"
          soap.namespaces['xmlns:listRel'] = "urn:relationships_#{NetSuite::Configuration.api_version}.lists.webservices.netsuite.com"
          soap.namespaces['xmlns:tranSales'] = "urn:sales_#{NetSuite::Configuration.api_version}.transactions.webservices.netsuite.com"

          soap.header = auth_header
          
          soap.body = request_body
        end
      end

      def request_body
        buffer = ''

        xml = Builder::XmlMarkup.new(target: buffer)

        # TODO: When searching invoices allow for multiple basic search criteria to be set
        # TODO: Make setting of criteria and columns easier
        xml.searchRecord('xsi:type' => @klass.custom_soap_advanced_search_record_type) do |search_record|
          search_record.criteria do |criteria|
            if @klass.respond_to?(:default_search_options)
              if @options[:criteria].present?
                @options[:criteria].merge!(@klass.default_search_options)
              else
                @options[:criteria] = @klass.default_search_options
              end
            else
              @options[:criteria] = { }
            end

            @options[:criteria].each do |criteria_type, _criteria|
              criteria.method_missing(criteria_type) do |_criteria_type|
                _criteria.each do |criteria_name, criteria_options|
                  criteria_hash = {
                    'xsi:type' => criteria_options[:type]
                  }

                  if criteria_options[:operator].present?
                    criteria_hash.merge!({
                      operator: criteria_options[:operator]
                    })
                  end

                  _criteria_type.method_missing(criteria_name, criteria_options) do |_criteria_name|
                    _criteria_name.platformCore(:searchValue, criteria_options[:value])
                  end
                end
              end
            end
          end

          search_record.columns do |columns|
            if @options[:columns].present?
              @options[:columns].each do |result_type, result_columns|
                columns.method_missing(result_type) do |_result_type|
                  result_columns.each do |result_column|
                    _result_type.method_missing(result_column)
                  end
                end
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

        # TODO: Rename page_index to page
        module ClassMethods
          def search(options = { })
            response = NetSuite::Actions::Search.call(self, options)
            
            response_hash = { }

            if response.success?
              response_list = []

              if response.body[:record_list]
                response.body[:record_list][:record].each do |record|
                  entity = new(record)

                  response_list << entity
                end
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