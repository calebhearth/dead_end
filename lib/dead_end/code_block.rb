# frozen_string_literal: true

module DeadEnd
  # Multiple lines form a singular CodeBlock
  #
  # Source code is made of multiple CodeBlocks.
  #
  # Example:
  #
  #   code_block.to_s # =>
  #     #   def foo
  #     #     puts "foo"
  #     #   end
  #
  #   code_block.valid? # => true
  #   code_block.in_valid? # => false
  #
  #
  class CodeBlock
    UNSET = Object.new.freeze
    attr_reader :lines

    def initialize(lines: [])
      @lines = Array(lines)
      @valid = UNSET
    end

    def visible_lines
      @lines.select(&:visible?).select(&:not_empty?)
    end

    def mark_invisible
      @lines.map(&:mark_invisible)
    end

    def is_end?
      to_s.strip == "end"
    end

    def hidden?
      @lines.all?(&:hidden?)
    end

    def starts_at
      @starts_at ||= @lines.first&.line_number
    end

    def ends_at
      @ends_at ||= @lines.last&.line_number
    end

    # This is used for frontier ordering, we are searching from
    # the largest indentation to the smallest. This allows us to
    # populate an array with multiple code blocks then call `sort!`
    # on it without having to specify the sorting criteria
    def <=>(other)
      out = current_indent <=> other.current_indent
      return out if out != 0

      # Stable sort
      starts_at <=> other.starts_at
    end

    def current_indent
      @current_indent ||= lines.select(&:not_empty?).map(&:indent).min || 0
    end

    def invalid?
      !valid?
    end

    def valid?
      if @valid == UNSET
        # Performance optimization
        #
        # If all the lines were previously hidden
        # and we expand to capture additional empty
        # lines then the result cannot be invalid
        #
        # That means there's no reason to re-check all
        # lines with ripper (which is expensive).
        # Benchmark in commit message
        if lines.all? {|l| l.hidden? || l.empty? }
          @valid = true
        else
          @valid = DeadEnd.valid?(lines.map(&:original).join)
        end
      else
        @valid
      end
    end

    def to_s
      @lines.join
    end
  end
end
