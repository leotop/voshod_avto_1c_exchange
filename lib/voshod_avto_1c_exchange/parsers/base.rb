#
# Класс с базовым функционалом по разбору xml-файлов.
#
module VoshodAvtoExchange

  module Parsers

    class Base

      def initialize(*args)

        @str    = ""
        @level  = 0
        @tags   = {}
        @attrs  = {}

      end # initialize

      def start_element(name, attrs = [])

        @str          = ""
        @level        += 1
        @tags[@level] = name
        @attrs        = ::Hash[attrs]

      end # start_element

      def end_element(name)
        @level -= 1
      end # end_element

      def characters(str)
        @str << str unless str.blank?
      end # characters

      def end_document
      end # end_document

      private

      # Тег
      def tag(diff = 0)
        @tags[level + diff]
      end # tag

      # Параметры тега
      def attrs
        @attrs || {}
      end # attrs

      # Уровень вложенности
      def level
        @level || 0
      end # level

      # Содержимое тега
      def tag_value
        ::VoshodAvtoExchange::Util.xml_unescape(@str)
      end # tag_value

      alias :value :tag_value

      def tag_debug
        "<#{tag} #{attrs.inspect}>#{tag_value}</#{tag}>"
      end # tag_debug

      def log(msg)
        ::VoshodAvtoExchange.log(msg, self.class.name)
      end # log

    end # Base

  end # Parsers

end # VoshodAvtoExchange
