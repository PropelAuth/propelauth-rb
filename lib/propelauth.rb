# frozen_string_literal: true

require_relative "propelauth/version"
require 'active_support/concern'
require 'jwt'

module PropelAuth
  autoload :Client, "propelauth/client"
  autoload :InvalidAuthUrl, "propelauth/error"
  autoload :InvalidApiKey, "propelauth/error"
  autoload :UnexpectedError, "propelauth/error"
  autoload :B2BSupportDisabled, "propelauth/error"
  autoload :PropelAuthNotConfigured, "propelauth/error"
  autoload :BadRequest, "propelauth/error"

  module AuthMethods
    extend ActiveSupport::Concern

    class UnauthorizedException < StandardError; end
    class ForbiddenException < StandardError; end

    def require_user
      begin
        @user = extract_and_validate_user_from_access_token
      rescue UnauthorizedException
        render status: 401
      end
    end

    def optional_user
      begin
        @user = extract_and_validate_user_from_access_token
      rescue UnauthorizedException
        @user = nil
      end
    end

    def require_org_member(required_org_id, minimum_required_role: nil)
      begin
        @org = require_org_member_inner(required_org_id, minimum_required_role: minimum_required_role)
      rescue UnauthorizedException
        render status: 401
      rescue ForbiddenException
        render status: 403
      end
    end

    private def extract_and_validate_user_from_access_token
      token = extract_token_from_authorization_header(request.headers['Authorization'])
      user = validate_access_token(token)
      if user.nil?
        raise UnauthorizedException
      else
        user
      end
    end

    private def require_org_member_inner(required_org_id, minimum_required_role: nil)
      @user = extract_and_validate_user_from_access_token

      if required_org_id.nil?
        logger.info "Required org is unspecified"
        raise ForbiddenException
      end

      org_id_to_org_member_info = @user["org_id_to_org_member_info"]
      if org_id_to_org_member_info.nil?
        logger.info "User is not a member of required org"
        raise ForbiddenException
      end

      org_member_info = org_id_to_org_member_info[required_org_id]
      if org_member_info.nil?
        logger.info "User is not a member of required org"
        raise ForbiddenException
      end

      if !minimum_required_role.nil?
        minimum_required_role = UserRole.to_user_role(minimum_required_role)
        user_role = UserRole.to_user_role(org_member_info["user_role"])
        if user_role < minimum_required_role
          logger.info "User's role in org doesn't meet minimum required role"
          raise ForbiddenException
        end
      end

      org_member_info
    end

    private def validate_access_token(token)
      rsa_public = PropelAuth.configuration.public_key
      iss = PropelAuth.configuration.auth_url

      if rsa_public.nil? || iss.nil?
        raise PropelAuth::PropelAuthNotConfigured.new
      end

      begin
        decoded_token = JWT.decode token, rsa_public, true, { iss: iss, verify_iss: true, verify_iat: true, algorithm: 'RS256' }
        decoded_token_body = decoded_token[0]
        HashWithIndifferentAccess.new({
          user_id: decoded_token_body["user_id"],
          org_id_to_org_member_info: decoded_token_body["org_id_to_org_member_info"],
        })
      rescue StandardError => e
        logger.info e
        nil
      end
    end

    private def extract_token_from_authorization_header(header)
      if header.nil?
        nil
      else
        split_header = header.split(" ", 2)
        if split_header.length != 2 || split_header[0].casecmp("bearer") != 0
          nil
        else
          return split_header[1]
        end
      end
    end
  end

  module UserRole
    Member = 0
    Admin = 1
    Owner = 2

    def UserRole.to_user_role(user_role)
      if user_role == Member
        Member
      elsif user_role == Admin
        Admin
      elsif user_role == Owner
        Owner
      elsif user_role == "Member"
        Member
      elsif user_role == "Admin"
        Admin
      elsif user_role == "Owner"
        Owner
      else
        raise("Invalid user role")
      end
    end
  end

  class Configuration
    attr_accessor :api_key
    attr_reader :auth_url, :public_key

    def auth_url=(auth_url)
      @auth_url = validate_auth_url(auth_url)
    end

    def public_key=(public_key_pem)
      @public_key = OpenSSL::PKey::RSA.new(public_key_pem)
    end

    private def validate_auth_url(auth_url)
      uri = URI(auth_url)
      if uri.scheme.nil? || uri.scheme.casecmp("https") != 0
        raise PropelAuth::InvalidAuthUrl.new
      end

      if uri.host.nil?
        raise PropelAuth::InvalidAuthUrl.new
      end

      "#{uri.scheme}://#{uri.host}"
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end

