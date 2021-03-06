# encoding: utf-8
class ExchangeController < ::ApplicationController

  unloadable

  before_action       :auth
  skip_before_action  :verify_authenticity_token

  layout false

  # GET /exchange
  def get

    ::Rails.logger.tagged("[GET] /exchange [params]") {
      ::Rails.logger.info(" --> session_id: #{session_id}, operation_id: #{operation_id}")
      ::Rails.logger.info(params.inspect)
    }

    case mode

      when 'checkauth'
        answer(text: "success\nexchange_1c\n#{session_id}")

      when 'init'
        answer(text: "zip=yes\nfile_limit=0")

      when 'success'

        case type

          # GET /exchange?type=catalog&mode=success
          when 'catalog'
            answer(text: "failure\nType `#{type}` is not implement")

          # GET /exchange?type=sale&mode=success
          # Пользователи
          # Заказы
          when 'sale'

            ::VoshodAvtoExchange::Exports.users_and_orders_verify(operation_id)
            answer(text: "success")

          else
            answer(text: "failure\nType `#{type}` is not found")

        end # case

      when 'query'

        case type

          # GET /exchange?type=catalog&mode=query
          when 'catalog'
            answer(text: "failure\nType `#{type}` is not implement")

          # GET /exchange?type=sale&mode=query
          # Пользователи
          # Заказы
          when 'sale'
            answer(xml: ::VoshodAvtoExchange::Exports.users_and_orders(operation_id))

          else
            answer(text: "failure\nType `#{type}` is not found")

        end # case

      # Узнаем, пришел ли файл выгрузки
      when 'import'

        if ::VoshodAvtoExchange.exist_job?(key: operation_id)
          answer(text: "success")
        else
          answer(text: "failure\nFile `#{params[:filename]}` is not found")
        end

      # На все остальное отвечаем ошибкой
      else
        answer(text: "failure\nMode `#{mode}` is not found")

    end # case

    render(answer) and return

  end # get

  # POST /exchange
  def post

    ::Rails.logger.tagged("[POST] /exchange [params]") {
      ::Rails.logger.info("session_id: #{session_id}, operation_id: #{operation_id}")
      ::Rails.logger.info(params.inspect)
    }

    case mode

      when 'checkauth'
        answer(text: "success\nexchange_1c\n#{session_id}")

      when 'init'
        answer(text: "zip=no\nfile_limit=0")

      when 'success'
        answer(text: "success")

      when 'file'

        case type

          # POST /exchange?type=catalog&mode=file&filename=sdsd.xml
          when 'catalog'

            # Получение файла из 1С
            res = !save_file.nil?
            answer(text: res ? "success" : "failure\nFile is not found")

          # POST /exchange?type=sale&mode=file&filename=sdsd.xml
          when 'sale'

            # Получение файла из 1С
            res = !save_file.nil?
            answer(text: res ? "success" : "failure\nFile is not found")

          else
            answer(text: "failure\nType `#{type}` is not found")

        end # case

      # На все остальное отвечаем ошибкой
      else
        answer(text: "failure\nMode `#{mode}` is not found")

    end # case

    render(answer) and return

  end # post

  private

  def auth

    return true if ::VoshodAvtoExchange::login.nil?

    authenticate_or_request_with_http_basic do |login, password|
      (login == ::VoshodAvtoExchange::login && password == ::VoshodAvtoExchange::password)
    end

  end # auth

  def save_file

    return if request.raw_post.nil? || request.raw_post.blank?

    file_path = ::File.join(
      ::VoshodAvtoExchange.import_dir,
      "#{operation_id}-#{params[:filename]}"
    )

    ::File.open(file_path, 'wb') do |f|
      f.write read_file
    end

    # Создаем задачу по обработке файла
    ::VoshodAvtoExchange.run_async(file_path, key: operation_id)

    ::Rails.logger.info("/exchange/post [save_file: #{file_path}]")

    file_path

  end # save_file

  def session_id
    @session_id ||= ::SecureRandom.hex(20)
  end # session_id

  def operation_id
    cookies[:exchange_1c] || params[:exchange_1c] || 0
  end # operation_id

  def mode
    @mode ||= (params[:mode] || 'undefined')
  end # mode

  def type
    @type ||= (params[:type] || 'undefined')
  end # type

  def answer(text: nil, xml: nil)

    @answer = { text: text } if text
    @answer = { xml:  xml, encoding: 'utf-8' } if xml
    @answer || { text: 'failure\nОбработка параметров не задана' }

  end # answer

  def read_file

    unless params[:data].nil?
      ::Base64.decode64(params[:data].read)
    else
      request.raw_post.read
    end

  end # read_file

end # ExchangeController
