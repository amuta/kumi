# frozen_string_literal: true

module Kumi
  module Kernels
    module Ruby
      module AggregateCore
        module_function

        def kumi_sum(enum, skip_nulls: true, min_count: 0)
          total = 0
          count = 0
          enum.each do |x|
            next if skip_nulls && x.nil?

            total += x
            count += 1
          end
          return nil if count < min_count

          total
        end

        def kumi_min(enum, skip_nulls: true, min_count: 0)
          best = nil
          count = 0
          enum.each do |x|
            next if skip_nulls && x.nil?

            best = x if best.nil? || x < best
            count += 1
          end
          return nil if count < min_count

          best
        end

        def kumi_max(enum, skip_nulls: true, min_count: 0)
          best = nil
          count = 0
          enum.each do |x|
            next if skip_nulls && x.nil?

            best = x if best.nil? || x > best
            count += 1
          end
          return nil if count < min_count

          best
        end

        def kumi_mean(enum, skip_nulls: true, min_count: 0)
          total = 0.0
          count = 0
          enum.each do |x|
            next if skip_nulls && x.nil?

            total += x
            count += 1
          end
          return nil if count < [min_count, 1].max

          total / count
        end

        def kumi_any(enum, skip_nulls: true, min_count: 0)
          count = 0
          enum.each do |x|
            next if skip_nulls && x.nil?

            return true if x
            count += 1
          end
          return nil if count < min_count

          false
        end

        def kumi_all(enum, skip_nulls: true, min_count: 0)
          count = 0
          enum.each do |x|
            next if skip_nulls && x.nil?

            return false unless x
            count += 1
          end
          return nil if count < min_count

          true
        end

        def kumi_count(enum, skip_nulls: true, min_count: 0)
          count = 0
          enum.each do |x|
            next if skip_nulls && x.nil?

            count += 1
          end
          return nil if count < min_count

          count
        end
      end
    end
  end
end