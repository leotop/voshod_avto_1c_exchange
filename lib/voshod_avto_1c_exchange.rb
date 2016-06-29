require 'logger'
require 'fileutils'
require 'nokogiri'
require 'zip'

module VoshodAvtoExchange

  extend self

  TAG       = '1С_EXCHANGE'.freeze
  FILE_LOCK = ::File.join(::Rails.root, 'tmp', 'voshod_avto_1c_exchange.lock').freeze

  def login(v = nil)

    @login = v unless v.blank?
    @login

  end # login

  def password(v = nil)

    @pass = v unless v.blank?
    @pass

  end # password

  alias :pass :password

  def status(key: nil)

    sq = ::SidekiqQuery.
      where({
        key: key || 0,
        tag: ::VoshodAvtoExchange::TAG
      }).
      first

    {

      message:    sq.try(:message)    || '',
      progress:   sq.try(:progress)   || 0,
      completed:  sq.try(:completed?) || false,
      status:     sq.try(:status)     || 'undefined'

    }.to_json

  end # status

  def run_async(file_path, key: nil)

    ::SidekiqQuery.create({

      jid:  ::ExchangeWorker.perform_async(file_path),
      tag:  ::VoshodAvtoExchange::TAG,
      name: "Выгрузка данных из 1С",
      key:  key || 0

    })
    self

  end # run_async

  def run

    begin
      f = ::File.new(FILE_LOCK, ::File::RDWR|::File::CREAT, 0400)
      return if f.flock(::File::LOCK_EX) === false
    rescue ::Errno::EACCES
      return
    end

    begin
      ::VoshodAvtoExchange::Manager.run
    rescue => ex
      log ex.inspect
    ensure
      ::FileUtils.rm(FILE_LOCK, force: true)
    end

    self

  end # run

  def import_dir(v = nil)

    @import_dir = v unless v.blank?
    @import_dir ||= ::File.join(::Rails.root, "tmp", "exchange_1c")

    ::FileUtils.mkdir_p(@import_dir) unless ::FileTest.directory?(@import_dir)

    @import_dir

  end # import_dir

  def log_dir(v = nil)

    @log_dir = v unless v.blank?
    @log_dir ||= ::File.join(::Rails.root, "log")

    ::FileUtils.mkdir_p(@log_dir) unless ::FileTest.directory?(@log_dir)

    @log_dir

  end # log_dir

  def log(msg = "", name = "")

    create_logger unless @logger
    @logger.log(::Logger::INFO, msg, name) if @logger
    msg

  end # log

  def close_logger

    return unless @logger
    @logger.close
    @logger = nil

  end # close_logger

  private

  def create_logger

    return if @logger

    log_file = ::File.open(
      ::File.join(::VoshodAvtoExchange::log_dir, "voshod_avto_exchange.log"),
      ::File::WRONLY | ::File::APPEND | ::File::CREAT
    )
    log_file.sync = true
    @logger = ::Logger.new(log_file, 'weekly')
    @logger

  end # create_logger

end # VoshodAvtoExchange

require 'voshod_avto_1c_exchange/version'

require 'voshod_avto_1c_exchange/util'

require 'voshod_avto_1c_exchange/template'
require 'voshod_avto_1c_exchange/export'

require 'voshod_avto_1c_exchange/line_count'
require 'voshod_avto_1c_exchange/parser'
require 'voshod_avto_1c_exchange/manager'

if defined?(::Rails)
  require 'voshod_avto_1c_exchange/engine'
  require 'voshod_avto_1c_exchange/railtie'
end
