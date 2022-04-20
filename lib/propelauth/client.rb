require "faraday"
require "uri"

module PropelAuth
  module Client
    class << self
      def fetch_user_metadata_by_user_id(user_id, include_orgs: false)
        fetch_user_metadata_by_query(user_id, { include_orgs: include_orgs })
      end

      def fetch_user_metadata_by_email(email, include_orgs: false)
        fetch_user_metadata_by_query("email", { email: email, include_orgs: include_orgs })
      end

      def fetch_user_metadata_by_username(username, include_orgs: false)
        fetch_user_metadata_by_query("username", { username: username, include_orgs: include_orgs })
      end

      def fetch_batch_user_metadata_by_user_ids(user_ids, include_orgs: false)
        fetch_batch_user_metadata("user_ids", user_ids, -> (x) { x["user_id"] }, include_orgs)
      end

      def fetch_batch_user_metadata_by_emails(emails, include_orgs: false)
        fetch_batch_user_metadata("emails", emails, -> (x) { x["email"] }, include_orgs)
      end

      def fetch_batch_user_metadata_by_usernames(usernames, include_orgs: false)
        fetch_batch_user_metadata("usernames", usernames, -> (x) { x["username"] }, include_orgs)
      end

      def fetch_org(org_id)
        response = connection.get("/api/backend/v1/org/#{org_id}", {}, { "Authorization" => "Bearer #{api_key}" })
        if response.status == 200
          response.body
        elsif response.status == 404
          nil
        elsif response.status == 401
          raise PropelAuth::InvalidApiKey.new
        elsif response.status == 426
          raise PropelAuth::B2BSupportDisabled.new
        else
          raise PropelAuth::UnexpectedError.new
        end
      end

      def fetch_orgs_by_query(page_size: 10, page_number: 0, order_by: OrgOrderBy::CREATED_AT_ASC)
        json_body = {
          page_size: page_size,
          page_number: page_number,
          order_by: order_by,
        }.to_json
        response = connection.post "/api/backend/v1/org/query", json_body, {
          "Authorization" => "Bearer #{api_key}",
          "Content-Type" => "application/json",
        }
        if response.status == 200
          response.body
        elsif response.status == 400
          raise PropelAuth::BadRequest.new response.body
        elsif response.status == 401
          raise PropelAuth::InvalidApiKey.new
        elsif response.status == 426
          raise PropelAuth::B2BSupportDisabled.new
        else
          raise PropelAuth::UnexpectedError.new
        end
      end

      def fetch_users_by_query(page_size: 10, page_number: 0, order_by: UserOrderBy::CREATED_AT_ASC, email_or_username: nil, include_orgs: false)
        params = {
          page_size: page_size,
          page_number: page_number,
          order_by: order_by,
          email_or_username: email_or_username,
          include_orgs: include_orgs,
        }
        response = connection.get "/api/backend/v1/user/query", params, { "Authorization" => "Bearer #{api_key}" }
        if response.status == 200
          response.body
        elsif response.status == 400
          raise PropelAuth::BadRequest.new response.body
        elsif response.status == 401
          raise PropelAuth::InvalidApiKey.new
        elsif response.status == 426
          raise PropelAuth::B2BSupportDisabled.new
        else
          raise PropelAuth::UnexpectedError.new
        end
      end

      def fetch_users_in_org(org_id, page_size: 10, page_number: 0, include_orgs: false)
        params = {
          page_size: page_size,
          page_number: page_number,
          include_orgs: include_orgs,
        }
        response = connection.get "/api/backend/v1/user/org/#{org_id}", params, { "Authorization" => "Bearer #{api_key}" }
        if response.status == 200
          response.body
        elsif response.status == 400
          raise PropelAuth::BadRequest.new response.body
        elsif response.status == 401
          raise PropelAuth::InvalidApiKey.new
        elsif response.status == 426
          raise PropelAuth::B2BSupportDisabled.new
        else
          raise PropelAuth::UnexpectedError.new
        end
      end

      def create_user(email, email_confirmed: false, send_email_to_confirm_email_address: false, password: nil,
                      username: nil, first_name: nil, last_name: nil)
        json_body = {
          email: email,
          email_confirmed: email_confirmed,
          send_email_to_confirm_email_address: send_email_to_confirm_email_address,
          password: password,
          username: username,
          first_name: first_name,
          last_name: last_name,
        }.to_json

        response = connection.post "/api/backend/v1/user/", json_body, {
          "Authorization" => "Bearer #{api_key}",
          "Content-Type" => "application/json",
        }
        if response.status >= 200 && response.status < 300
          response.body
        elsif response.status == 400
          raise PropelAuth::BadRequest.new response.body
        elsif response.status == 401
          raise PropelAuth::InvalidApiKey.new
        else
          raise PropelAuth::UnexpectedError.new
        end
      end

      private def connection
        @connection ||= Faraday.new do |conn|
          auth_url = PropelAuth.configuration.auth_url
          if auth_url.nil? || PropelAuth.configuration.api_key.nil?
              raise PropelAuth::PropelAuthNotConfigured.new
          end

          conn.url_prefix = auth_url
          conn.request :json
          conn.response :json, content_type: "application/json"
        end
      end

      private def api_key
        PropelAuth.configuration.api_key
      end

      private def fetch_user_metadata_by_query(path_param, query)
        response = connection.get("/api/backend/v1/user/#{path_param}", query, { "Authorization" => "Bearer #{api_key}" })
        if response.status == 200
          response.body
        elsif response.status == 404
          nil
        elsif response.status == 401
          raise PropelAuth::InvalidApiKey.new
        else
          raise PropelAuth::UnexpectedError.new
        end
      end

      private def fetch_batch_user_metadata(type, values, key_function, include_orgs)
        json_body = {}
        json_body[type] = values
        json_body = json_body.to_json
        response = connection.post "/api/backend/v1/user/#{type}" do |req|
          req.body = json_body
          req.headers[:authorization] = "Bearer #{api_key}"
          req.headers[:content_type] = "application/json"
          req.params[:include_orgs] = include_orgs
        end

        if response.status == 401
          raise PropelAuth::InvalidApiKey.new
        elsif response.status == 400
          raise PropelAuth::BadRequest.new response.body
        elsif response.status == 200
          user_by_key = {}

          response.body.each { |user|
            key = key_function.call(user)
            unless key.nil?
              user_by_key[key_function.call(user)] = user
            end
          }

          user_by_key
        else
          raise PropelAuth::UnexpectedError.new
        end
      end

    end
  end

  module OrgOrderBy
    CREATED_AT_ASC = "CREATED_AT_ASC"
    CREATED_AT_DESC = "CREATED_AT_DESC"
    NAME = "NAME"
  end

  module UserOrderBy
    CREATED_AT_ASC = "CREATED_AT_ASC"
    CREATED_AT_DESC = "CREATED_AT_DESC"
    LAST_ACTIVE_AT_ASC = "LAST_ACTIVE_AT_ASC"
    LAST_ACTIVE_AT_DESC = "LAST_ACTIVE_AT_DESC"
    EMAIL = "EMAIL"
    USERNAME = "USERNAME"
  end
end
