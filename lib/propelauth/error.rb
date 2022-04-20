module PropelAuth
  class InvalidAuthUrl < StandardError; end
  class InvalidApiKey < StandardError; end
  class PropelAuthNotConfigured < StandardError; end
  class B2BSupportDisabled < StandardError; end
  class UnexpectedError < StandardError; end

  class BadRequest < StandardError
    def initialize(errors_by_field)
      @errors_by_field = errors_by_field
      super("Bad request #{errors_by_field}")
    end
  end

end
