# frozen_string_literal: true

if SyntaxError.new.respond_to?(:detailed_message)
  SyntaxError.prepend Module.new {
    def detailed_message(highlight: nil, **)
      require "stringio" unless defined?(StringIO)

      message = super
      file = DeadEnd::PathnameFromMessage.new(message).call.name
      io = StringIO.new

      if file
        DeadEnd.call(
          io: io,
          source: file.read,
          filename: file
        )
        annotation = io.string

        annotation + message
      else
        message
      end
    end
  }
else
  # Monkey patch kernel to ensure that all `require` calls call the same
  # method
  module Kernel
    module_function

    alias_method :dead_end_original_require, :require
    alias_method :dead_end_original_require_relative, :require_relative
    alias_method :dead_end_original_load, :load

    def load(file, wrap = false)
      dead_end_original_load(file)
    rescue SyntaxError => e
      DeadEnd.handle_error(e)
    end

    def require(file)
      dead_end_original_require(file)
    rescue SyntaxError => e
      DeadEnd.handle_error(e)
    end

    def require_relative(file)
      if Pathname.new(file).absolute?
        dead_end_original_require file
      else
        relative_from = caller_locations(1..1).first
        relative_from_path = relative_from.absolute_path || relative_from.path
        dead_end_original_require File.expand_path("../#{file}", relative_from_path)
      end
    rescue SyntaxError => e
      DeadEnd.handle_error(e)
    end
  end
end
