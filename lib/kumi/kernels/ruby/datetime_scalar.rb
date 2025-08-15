# frozen_string_literal: true

require "date"

module Kumi
  module Kernels
    module Ruby
      module DatetimeScalar
        module_function

        def dt_add_days(date, n)
          return nil if date.nil? || n.nil?
          # Accept Date, DateTime, Time
          if date.is_a?(Time)
            date + (Integer(n) * 86_400)
          else
            date + Integer(n)
          end
        end

        def dt_diff_days(d1, d2)
          return nil if d1.nil? || d2.nil?
          if d1.is_a?(Time) || d2.is_a?(Time)
            # Normalize to seconds, return integer day delta
            ((to_time(d1) - to_time(d2)) / 86_400.0).round
          else
            (d1 - d2).to_i
          end
        end

        def to_time(x)
          case x
          when Time then x
          when DateTime then Time.new(x.year, x.month, x.day, x.hour, x.minute, x.second, x.zone)
          when Date then Time.new(x.year, x.month, x.day)
          else
            raise ArgumentError, "unsupported date type: #{x.class}"
          end
        end
      end
    end
  end
end