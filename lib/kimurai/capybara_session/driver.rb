module Capybara
  class Session
    attr_reader :driver_type, :driver_pid, :driver_port

    # as you can see, driver don't created at the same time with session
    # driver created later, at the first call of #driver method. For example
    # at the first #visit (because visit it's a wrapper for driver.visit)
    # And this is exact reason why driver_pid will is nil, until driver
    # will be created (def create_session_driver)
    def driver
      @driver ||= create_session_driver
    end

    def recreate_driver!
      @driver.quit
      logger.info "Session: current driver has been quitted"

      @driver = create_session_driver
    end

    private
    def create_session_driver
      unless Capybara.drivers.key?(mode)
        other_drivers = Capybara.drivers.keys.map(&:inspect)
        raise Capybara::DriverNotFoundError, "no driver called #{mode.inspect} was found, available drivers: #{other_drivers.join(', ')}"
      end
      driver = Capybara.drivers[mode].call(app)
      driver.session = self if driver.respond_to?(:session=)

      # added
      @driver_type = parse_driver_type(driver.class)
      # added
      @driver_pid, @driver_port = get_driver_pid_port(driver)
      logger.info "Session: a new session driver has been created (pid: #{@driver_pid}, port: #{@driver_port})"

      driver
    end

    def parse_driver_type(driver_class)
      case
      when driver_class.to_s.match?(/poltergeist/i)
        :poltergeist
      when driver_class.to_s.match?(/mechanize/i)
        :mechanize
      when driver_class.to_s.match?(/selenium/i)
        :selenium
      else
        :unknown
      end
    end

    def get_driver_pid_port(driver)
      case driver_type
      when :poltergeist
        [driver.browser.client.pid, driver.browser.client.server.port]
      when :selenium
        # webdriver_port = driver.browser.send(:bridge).http.instance_variable_get("@http").port
        webdriver_port = driver.browser.send(:bridge).instance_variable_get("@http")
          .instance_variable_get("@server_url").port
        webdriver_pid = `lsof -i tcp:#{webdriver_port} -t`&.strip&.to_i

        [webdriver_pid, webdriver_port]
      when :mechanize
        Kimurai::Logger.error "Not supported"
        [nil, nil]
      end
    end
  end
end